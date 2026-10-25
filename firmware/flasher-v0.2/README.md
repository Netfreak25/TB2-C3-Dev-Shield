# ESP32-C3 serprog flasher v0.2

This package turns an ESP32-C3 SuperMini into a serial-to-SPI adapter for the TB2 C3 Dev Shield. It contains no target firmware or target-flash dump. The ESP32-C3 firmware is built, but the assembled Shield and target connection remain an **unverified build candidate** until electrical and full-read checks succeed.

## Provenance and changes

- Based on [`thisiseth/esp32-serprog` commit `0ca3c7e6d3099ed08b1aaaab80a4f3af64d97275`](https://github.com/thisiseth/esp32-serprog/tree/0ca3c7e6d3099ed08b1aaaab80a4f3af64d97275). This repository's v0.1 package adapted the SPI pins to the Shield. v0.2 retains that mapping and improves the serprog transport and error handling.
- SPI2 uses /CS = GPIO4, MISO = GPIO5, CLK = GPIO6, and MOSI = GPIO7. GPIO18/19 remain available for native USB Serial/JTAG. Wi-Fi is disabled in the included build configuration.
- The serprog programmer name is `tb2-c3-serprog` (NUL-padded to 16 bytes). The [read-only PowerShell runner](tools/first_dump.ps1) requires this name, so it cannot silently select a Pico or older C3 adapter.
- The first SPI session defaults to **500 kHz**. Target-facing SPI pins have their drivers and internal pulls disabled at boot. A serprog speed request or pin-enable command initializes SPI; a pin-disable command removes the SPI device and leaves GPIO4–7 high-impedance without internal pulls. flashrom sends pin-disable on normal shutdown. This may reduce backfeeding, but **opening JP1 is a confirmed reset only when the target flash's VCC is measured to fall**.
- The speed command replies with the driver's actual frequency only after successful SPI initialization; errors receive NAK. flashrom may continue after a speed-setting warning, so a read workflow must independently check its verbose actual-frequency report.
- USB reads are completed across short transfers; an EOF no longer enters the command parser. The advertised serial receive buffer is the configured 4096 bytes.
- Application logging is disabled on the binary USB serprog stream. ROM or bootloader startup messages can still precede protocol synchronization after an ESP32 reset.

The full source, [`COPYING`](source/COPYING), ESP-IDF configuration and compiled images are included. **Firmware: GPLv3. Hardware: CERN-OHL-P-2.0.** The hardware licence does not relicense the firmware.

## Build and images

Built with **ESP-IDF 6.0.3** for `esp32c3`, native USB Serial/JTAG, no secondary console, Wi-Fi disabled, 2 MB DIO flash at 80 MHz. `PROJECT_VER` is `0.2.0`; the image format's own header version is a separate field. The build settings are in [`source/sdkconfig`](source/sdkconfig).

| ESP32 flash offset | File |
|---:|---|
| `0x0` | [`images/bootloader/bootloader.bin`](images/bootloader/bootloader.bin) |
| `0x8000` | [`images/partition_table/partition-table.bin`](images/partition_table/partition-table.bin) |
| `0x10000` | [`images/main.bin`](images/main.bin) |

[`images/flasher_args.json`](images/flasher_args.json) records the flash arguments. [`SHA256SUMS.txt`](SHA256SUMS.txt) covers this README, every file in `images/` and `source/` except generated `source/build/`, and the PowerShell runner and its offline test in `tools/`. Before programming the **ESP32-C3 itself**, disconnect the Shield from the target chip and leave JP1 open. Replace `PORT` with the ESP32-C3's current serial port; it can change after reconnecting.

From the `images` directory, with Espressif esptool installed:

```text
esptool --chip esp32c3 -p PORT -b 460800 write-flash --flash-mode dio --flash-freq 80m --flash-size 2MB 0x0 bootloader/bootloader.bin 0x8000 partition_table/partition-table.bin 0x10000 main.bin
```

Alternatively, activate ESP-IDF 6.0.3 and run `idf.py build` from `source`. Flashing an ESP32-C3 or seeing its serial port does not verify the target connection.

## First read

Complete the [electrical and reset checks](../../docs/first-dump.md) before opening the serial port. From this directory, run the [read-only PowerShell runner](tools/first_dump.ps1) with the current port (replace `COM17` as needed):

```powershell
.\tools\first_dump.ps1 -Port COM17
```

It requests 500 kHz by default and checks the `tb2-c3-serprog` name and expected 16 MiB chip. In automatic mode, it waits for one new USB arrival of the selected COM device before chip detection, then waits 250 ms before starting flashrom. Adjust that delay with `-PostArrivalDelayMilliseconds 500` (range 0–1500 ms), or the 180-second reset timeout with `-ResetTimeoutSeconds 300`.

After detection, leave JP1 closed: the three reads run on continuous target power, and the runner checks that the selected COM device has not changed before each one. flashrom still opens the port and rechecks the chip on every call; unlike the Flipper browser workflow, separate flashrom calls do not share an open session. If cycling JP1 does not re-enumerate USB, add `-ManualReset` to retain the four measured power-cycle and single-key checkpoints. Follow the [electrical procedure](../../docs/first-dump.md) in either mode: USB reappearance does not prove that target VCC fell, and the post-arrival delay does not prove chip readiness. Ctrl+C aborts.

The runner compares read sizes, hashes and bytes. Dumps go to a private directory outside Git; `-ReferenceDump` optionally compares a known-good image of the same unchanged flash. It never writes or erases the target. The offline regression test uses a fake programmer and does not open a serial port:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\tests\first_dump.tests.ps1
```

Keep all target dumps and device-specific logs outside this public repository. A complete, verified read from the target chip is still pending.
