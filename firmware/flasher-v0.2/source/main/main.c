#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_vfs_dev.h"
#include "sdkconfig.h"
#include "esp_log.h"

#include "serprog.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////// Please update the following configuration according to your HardWare spec /////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

#define EEPROM_HOST SPI2_HOST
#define PIN_NUM_MISO 5
#define PIN_NUM_MOSI 7
#define PIN_NUM_CLK  6
#define PIN_NUM_CS   4

/* Safe initial clock for in-circuit reads; flashrom may request a lower one. */
#define DEFAULT_SPI_HZ 500000U
#define SERPROG_RETRY_DELAY_MS 10U
#define USB_SERIAL_BUFFER_SIZE 4096U

#ifdef CONFIG_ESP32_SERPROG_WIFI_ENABLED
    #include "wifi.h"

    #define USE_WIFI

    #define WIFI_SSID     CONFIG_ESP32_SERPROG_WIFI_SSID
    #define WIFI_PASSWORD CONFIG_ESP32_SERPROG_WIFI_PASSWORD
    #define WIFI_HOSTNAME CONFIG_ESP32_SERPROG_WIFI_HOSTNAME
    #define WIFI_TCP_PORT CONFIG_ESP32_SERPROG_WIFI_TCP_PORT

#elif defined CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG
    #include "driver/usb_serial_jtag.h"
    #include "driver/usb_serial_jtag_vfs.h"

    #define USE_SERIAL_JTAG

#elif defined CONFIG_ESP_CONSOLE_UART
    #include "driver/uart.h"
    #include "driver/uart_vfs.h"

    #define USE_HW_UART

    #define HW_UART_NUM CONFIG_ESP_CONSOLE_UART_NUM

    //use already allocated (default) pins
    #define HW_UART_PIN_TX  UART_PIN_NO_CHANGE
    #define HW_UART_PIN_RX  UART_PIN_NO_CHANGE
    #define HW_UART_PIN_CTS UART_PIN_NO_CHANGE
    #define HW_UART_PIN_RTS UART_PIN_NO_CHANGE

    #define HW_UART_BAUD_RATE 921600
    #define HW_UART_FLOW_CONTROL UART_HW_FLOWCTRL_DISABLE

    #define HW_UART_SERBUF_SIZE 4096

#elif defined CONFIG_ESP_CONSOLE_USB_CDC
    #define USE_USB_CDC

#else
    #error no serial option selected

#endif

#ifdef USE_WIFI
static const char TAG[] = "serprog";
#endif

#define BUS_SPI         (1 << 3)
#define S_SUPPORTED_BUS   BUS_SPI
#define S_CMD_MAP ( \
  (1 << S_CMD_NOP)       | \
  (1 << S_CMD_Q_IFACE)   | \
  (1 << S_CMD_Q_CMDMAP)  | \
  (1 << S_CMD_Q_PGMNAME) | \
  (1 << S_CMD_Q_SERBUF)  | \
  (1 << S_CMD_Q_BUSTYPE) | \
  (1 << S_CMD_SYNCNOP)   | \
  (1 << S_CMD_O_SPIOP)   | \
  (1 << S_CMD_S_BUSTYPE) | \
  (1 << S_CMD_S_SPI_FREQ) | \
  (1 << S_CMD_S_PIN_STATE) | \
  (1 << S_CMD_Q_WRNMAXLEN) | \
  (1 << S_CMD_Q_RDNMAXLEN) \
)

#ifdef USE_WIFI
    #define serprog_getchar()                         wifi_getchar()
    #define serprog_putchar(_character)               wifi_putchar(_character)
    #define serprog_read(_dst, _elementSize, _count)  wifi_read(_dst, _elementSize, _count)
    #define serprog_write(_src, _elementSize, _count) wifi_write(_src, _elementSize, _count)
    #define serprog_flush()                           wifi_flush()
#else
    #define serprog_getchar()                         getchar()
    #define serprog_putchar(_character)               putchar(_character)
    #define serprog_read(_dst, _elementSize, _count)  fread(_dst, _elementSize, _count, stdin)
    #define serprog_write(_src, _elementSize, _count) fwrite(_src, _elementSize, _count, stdout)
    #define serprog_flush()                           fflush(stdout)
#endif

/* USB Serial/JTAG can deliver a command in several short reads. */
static bool serprog_read_exact(void *destination, size_t length)
{
    uint8_t *cursor = destination;
    while (length > 0) {
        size_t received = serprog_read(cursor, 1, length);
        if (received == 0) {
#ifndef USE_WIFI
            clearerr(stdin);
#endif
            return false;
        }
        cursor += received;
        length -= received;
    }
    return true;
}

static bool serprog_getu24(uint32_t *result)
{
    uint8_t bytes[3];
    if (!serprog_read_exact(bytes, sizeof(bytes))) {
        return false;
    }
    *result = (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) |
              ((uint32_t)bytes[2] << 16);
    return true;
}

static bool serprog_getu32(uint32_t *result)
{
    uint8_t bytes[4];
    if (!serprog_read_exact(bytes, sizeof(bytes))) {
        return false;
    }
    *result = (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) |
              ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
    return true;
}

static inline void serprog_putu32(uint32_t d)
{
    char buf[4];
    memcpy(buf, &d, 4);
    serprog_putchar(buf[0]);
    serprog_putchar(buf[1]);
    serprog_putchar(buf[2]);
    serprog_putchar(buf[3]);
}

#define SPI_BUF_SIZE 16384U
#define SPI_OP_MAX_LEN (SPI_BUF_SIZE / 2U)

DMA_ATTR unsigned char write_buffer[SPI_BUF_SIZE];
DMA_ATTR unsigned char read_buffer[SPI_BUF_SIZE];

uint8_t syncnop[] = { S_NAK, S_ACK };

static spi_device_handle_t spi_device = NULL;
static bool spi_bus_initialized = false;
static uint32_t selected_spi_hz = DEFAULT_SPI_HZ;

/* A stopped bus must leave no output driver connected to the target flash. */
static esp_err_t serprog_spi_stop(void)
{
    if (spi_device != NULL)
    {
        esp_err_t ret = spi_bus_remove_device(spi_device);
        if (ret != ESP_OK) {
            return ret;
        }
        spi_device = NULL;
    }

    if (spi_bus_initialized) {
        esp_err_t ret = spi_bus_free(EEPROM_HOST);
        if (ret != ESP_OK) {
            return ret;
        }
        spi_bus_initialized = false;
    }
    return ESP_OK;
}

static esp_err_t serprog_spi_disable_pins(void)
{
    gpio_config_t config = {
        .pin_bit_mask = (1ULL << PIN_NUM_MISO) | (1ULL << PIN_NUM_MOSI) |
                        (1ULL << PIN_NUM_CLK) | (1ULL << PIN_NUM_CS),
        .mode = GPIO_MODE_DISABLE,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    return gpio_config(&config);
}

/* Recreate the SPI device so the reported frequency is the driver's actual rate. */
static esp_err_t serprog_spi_start(uint32_t freq, uint32_t *actual_hz)
{
    esp_err_t ret = serprog_spi_stop();
    if (ret != ESP_OK) {
        return ret;
    }

    //initialize SPI host
    spi_bus_config_t buscfg =
    {
        .miso_io_num = PIN_NUM_MISO,
        .mosi_io_num = PIN_NUM_MOSI,
        .sclk_io_num = PIN_NUM_CLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = SPI_BUF_SIZE,
    };

    ret = spi_bus_initialize(EEPROM_HOST, &buscfg, SPI_DMA_CH_AUTO);
    if (ret != ESP_OK)
    {
        goto failure;
    }
    spi_bus_initialized = true;

    spi_device_interface_config_t devcfg =
    {
        .clock_speed_hz = freq,
        .mode = 0,
        .spics_io_num = PIN_NUM_CS,
        .queue_size = 2,
        .flags = 0,
        .input_delay_ns = 0
    };

    //Attach the EEPROM to the SPI bus
    ret = spi_bus_add_device(EEPROM_HOST, &devcfg, &spi_device);
    if (ret != ESP_OK)
    {
        goto failure;
    }

    int freq_khz;

    ret = spi_device_get_actual_freq(spi_device, &freq_khz);
    if (ret != ESP_OK || freq_khz <= 0)
    {
        if (ret == ESP_OK) {
            ret = ESP_FAIL;
        }
        goto failure;
    }

    selected_spi_hz = freq;
    *actual_hz = (uint32_t)freq_khz * 1000U;
    return ESP_OK;

failure:
    (void)serprog_spi_stop();
    (void)serprog_spi_disable_pins();
    return ret;
}

static void process(int command)
{
    switch(command)
    {
        case S_CMD_NOP:
            serprog_putchar(S_ACK);
            break;
        case S_CMD_Q_IFACE:
            serprog_putchar(S_ACK);
            serprog_putchar(0x01);
            serprog_putchar(0x00);
            break;
        case S_CMD_Q_CMDMAP:
            serprog_putchar(S_ACK);
            serprog_putu32(S_CMD_MAP);

            for(int i = 0; i < 32 - sizeof(uint32_t); ++i)
            {
                serprog_putchar(0);
            }
            break;
        case S_CMD_Q_PGMNAME:
            serprog_putchar(S_ACK);
            {
                static const char name[16] = "tb2-c3-serprog";
                serprog_write(name, 1, sizeof(name));
            }
            break;
        case S_CMD_Q_SERBUF:
            serprog_putchar(S_ACK);

#if defined HW_UART_SERBUF_SIZE && (HW_UART_FLOW_CONTROL == UART_HW_FLOWCTRL_DISABLE)
            serprog_putchar(HW_UART_SERBUF_SIZE & 0xFF);
            serprog_putchar((HW_UART_SERBUF_SIZE >> 8) & 0xFF);
#elif defined USE_SERIAL_JTAG
            /* Advertise the real RX ring capacity, not fictitious flow control. */
            serprog_putchar(USB_SERIAL_BUFFER_SIZE & 0xFF);
            serprog_putchar((USB_SERIAL_BUFFER_SIZE >> 8) & 0xFF);
#else
            //serprog protocol:
            // If the programmer has a guaranteed working flow control,
		    // it should return a big bogus value - eg 0xFFFF
            serprog_putchar(0xFF);
            serprog_putchar(0xFF);
#endif

            break;
        case S_CMD_Q_RDNMAXLEN:
        case S_CMD_Q_WRNMAXLEN:
            serprog_putchar(S_ACK);
            serprog_putchar(SPI_OP_MAX_LEN & 0xFF);
            serprog_putchar((SPI_OP_MAX_LEN >> 8) & 0xFF);
            serprog_putchar((SPI_OP_MAX_LEN >> 16) & 0xFF);
            break;
        case S_CMD_Q_BUSTYPE:
            serprog_putchar(S_ACK);
            serprog_putchar(S_SUPPORTED_BUS);
            break;
        case S_CMD_SYNCNOP:
            serprog_write(syncnop, 1, 2);
            break;
        case S_CMD_S_BUSTYPE:
            {
                int bustype = serprog_getchar();
                if (bustype == EOF) {
                    serprog_putchar(S_NAK);
                    break;
                }
                if((bustype | S_SUPPORTED_BUS) == S_SUPPORTED_BUS)
                {
                    serprog_putchar(S_ACK);
                } else
                {
                    serprog_putchar(S_NAK);
                }
            }
            break;
        case S_CMD_O_SPIOP:
            {
                uint32_t wlen;
                uint32_t rlen;
                if (!serprog_getu24(&wlen) || !serprog_getu24(&rlen)) {
                    serprog_putchar(S_NAK);
                    break;
                }

                if (spi_device == NULL || wlen > SPI_BUF_SIZE ||
                    rlen > SPI_BUF_SIZE - wlen)
                {
                    serprog_putchar(S_NAK);
                    break;
                }

                if (!serprog_read_exact(write_buffer, wlen))
                {
                    serprog_putchar(S_NAK);
                    break;
                }

                memset(write_buffer + wlen, 0, SPI_BUF_SIZE - wlen);

                esp_err_t err;

                err = spi_device_acquire_bus(spi_device, portMAX_DELAY);
                if (err != ESP_OK)
                {
                    serprog_putchar(S_NAK);
                    break;
                }

                spi_transaction_t trans =
                {
                    .flags = 0,
                    .length = (wlen + rlen) * 8,
                    .tx_buffer = write_buffer,
                    .rxlength = (wlen + rlen) * 8,
                    .rx_buffer = read_buffer
                };

                err = spi_device_polling_transmit(spi_device, &trans);
                if (err != ESP_OK)
                {
                    spi_device_release_bus(spi_device);
                    serprog_putchar(S_NAK);
                    break;
                }

                spi_device_release_bus(spi_device);

                serprog_putchar(S_ACK);

                if (rlen > 0)
                {
                    serprog_write(read_buffer + wlen, 1, rlen);
                }
            }
            break;
        case S_CMD_S_SPI_FREQ:
            {
                uint32_t freq;
                uint32_t actual_hz;
                if (!serprog_getu32(&freq) || freq == 0 ||
                    serprog_spi_start(freq, &actual_hz) != ESP_OK) {
                    serprog_putchar(S_NAK);
                } else {
                    serprog_putchar(S_ACK);
                    serprog_putu32(actual_hz);
                }
            }
            break;
        case S_CMD_S_PIN_STATE:
            {
                int enabled = serprog_getchar();
                if (enabled == EOF) {
                    serprog_putchar(S_NAK);
                } else if (enabled == 0) {
                    esp_err_t stop_result = serprog_spi_stop();
                    esp_err_t pins_result = serprog_spi_disable_pins();
                    selected_spi_hz = DEFAULT_SPI_HZ;
                    serprog_putchar(stop_result == ESP_OK && pins_result == ESP_OK ?
                                    S_ACK : S_NAK);
                } else if (spi_device != NULL) {
                    serprog_putchar(S_ACK);
                } else {
                    uint32_t actual_hz;
                    serprog_putchar(serprog_spi_start(selected_spi_hz, &actual_hz) == ESP_OK ?
                                    S_ACK : S_NAK);
                }
            }
            break;
        default:
            serprog_putchar(S_NAK);
    }

    serprog_flush();
}

void app_main(void)
{
    esp_err_t ret;

#ifdef USE_WIFI
    ESP_LOGI(TAG, "initializing serprog-wifi");
    ret = wifi_init(WIFI_SSID, WIFI_PASSWORD, WIFI_HOSTNAME, WIFI_TCP_PORT);
    ESP_ERROR_CHECK(ret);

#else
    esp_log_level_set("*", ESP_LOG_NONE);
    fflush(stdout);

    //configure UART for blocking mode

    //disable input buffering
    setvbuf(stdin, NULL, _IONBF, 0);

    #ifdef USE_SERIAL_JTAG
    //configure builtin serial/jtag
    usb_serial_jtag_driver_config_t usb_serial_jtag_config = {
        .tx_buffer_size = USB_SERIAL_BUFFER_SIZE,
        .rx_buffer_size = USB_SERIAL_BUFFER_SIZE,
    };

    ret = usb_serial_jtag_driver_install(&usb_serial_jtag_config);
    ESP_ERROR_CHECK(ret);

    usb_serial_jtag_vfs_set_rx_line_endings(ESP_LINE_ENDINGS_LF);
    usb_serial_jtag_vfs_set_tx_line_endings(ESP_LINE_ENDINGS_LF);

    usb_serial_jtag_vfs_use_driver();

    #elif defined USE_HW_UART
    //configure HW uart
    uart_config_t uart_config =
    {
        .baud_rate = HW_UART_BAUD_RATE,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = HW_UART_FLOW_CONTROL
    };

    ret = uart_param_config(HW_UART_NUM, &uart_config);
    ESP_ERROR_CHECK(ret);

    ret = uart_set_pin(HW_UART_NUM, HW_UART_PIN_TX, HW_UART_PIN_RX, HW_UART_PIN_RTS, HW_UART_PIN_CTS);
    ESP_ERROR_CHECK(ret);

    ret = uart_driver_install(HW_UART_NUM, HW_UART_SERBUF_SIZE, 0, 0, NULL, ESP_INTR_FLAG_IRAM);
    ESP_ERROR_CHECK(ret);

    uart_vfs_dev_port_set_rx_line_endings (HW_UART_NUM, ESP_LINE_ENDINGS_LF);
    uart_vfs_dev_port_set_tx_line_endings (HW_UART_NUM, ESP_LINE_ENDINGS_LF);

    uart_vfs_dev_use_driver(HW_UART_NUM);

    #elif USE_USB_CDC
        #error not implemented
    #endif
#endif

    /* Keep target-facing pins high-impedance until the host selects a speed
       or explicitly enables them. The first SPI session defaults to 500 kHz. */
    if (serprog_spi_disable_pins() != ESP_OK) {
        return;
    }

    for (;;)
    {
        int command = serprog_getchar();
        if (command == EOF) {
#ifndef USE_WIFI
            clearerr(stdin);
#endif
            vTaskDelay(pdMS_TO_TICKS(SERPROG_RETRY_DELAY_MS));
            continue;
        }
        process(command);
    }
}
