# ESP32-C3 serprog flasher v0.1

This package programs the **ESP32-C3 SuperMini**, which then acts as a WebSerial-to-SPI adapter for the TB2 C3 Dev Shield. It does not contain a Toniebox firmware image or a flash dump. The shield and target-flash connection remain an **unverified build candidate**.

## Provenance and configuration

- Based on [`thisiseth/esp32-serprog` commit `0ca3c7e6d3099ed08b1aaaab80a4f3af64d97275`](https://github.com/thisiseth/esp32-serprog/tree/0ca3c7e6d3099ed08b1aaaab80a4f3af64d97275).
- The only upstream source change is the SPI pin block in [`source/main/main.c`](source/main/main.c): SPI2, MISO GPIO5, MOSI GPIO7, CLK GPIO6, /CS GPIO4.
- Built with ESP-IDF 6.0.3 for `esp32c3`, native USB Serial/JTAG, no secondary console, Wi-Fi disabled, 2 MB DIO flash at 80 MHz. The complete build configuration is in [`source/sdkconfig`](source/sdkconfig).
- `v0.1` identifies this Shield-specific package. The upstream application's internal image version remains `1`.

The original source and its [`COPYING`](source/COPYING) file are included. **Firmware: GPLv3. Hardware: CERN-OHL-P-2.0.** The hardware licence does not relicense this firmware.

## Images

| ESP32 flash offset | File |
|---:|---|
| `0x0` | [`images/bootloader/bootloader.bin`](images/bootloader/bootloader.bin) |
| `0x8000` | [`images/partition_table/partition-table.bin`](images/partition_table/partition-table.bin) |
| `0x10000` | [`images/main.bin`](images/main.bin) |

[`images/flasher_args.json`](images/flasher_args.json) records the build's flash arguments. Check the files against [`SHA256SUMS.txt`](SHA256SUMS.txt) before flashing. Keep the target chip disconnected while programming the ESP32-C3. Replace `PORT` with the actual ESP32-C3 serial port; it may change after reconnecting.

From the `images` directory, with Espressif esptool installed:

```text
esptool --chip esp32c3 -p PORT -b 460800 write-flash --flash-mode dio --flash-freq 80m --flash-size 2MB 0x0 bootloader/bootloader.bin 0x8000 partition_table/partition-table.bin 0x10000 main.bin
```

Alternatively, with ESP-IDF 6.0.3 installed, run `idf.py build` and `idf.py -p PORT flash` from `source`. A fresh build may have different bytes because of build timestamps; the hashes identify the distributed images. [Espressif's ESP32-C3 flashing guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32c3/get-started/start-project.html) describes the toolchain and port selection.

The previous local flash operation wrote all three images to the ESP32-C3 and verified their hashes. Seeing a serial port or connecting to WebSerial confirms only the adapter side. Follow the [first-dump procedure](../../docs/first-dump.md) to test the target connection. Keep dumps, device IDs and diagnostic logs outside this public repository.
