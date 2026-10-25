# First target-flash dump — C3 Shield

This read-only procedure applies to an assembled Shield, the [C3 serprog flasher v0.2](../firmware/flasher-v0.2/README.md), and a 16 MiB Winbond W25Q128.V flash. The Shield-to-target connection remains an **unverified build candidate** until its physical checks and reads succeed. Keep target dumps outside this public repository.

## 1. Inspect with power off

1. Disconnect the target's battery and USB. Disconnect the ESP32-C3 USB cable. Fit the module with its USB connector pointing toward the Shield's USB arrow; check J1's notch, pin 1 and the clip's actual pin-to-pin continuity.
2. Measure all eight paths from the module through J1 to the SOP8 contacts against the [pin table](hardware.md#j1-and-sop8-mapping). Check for unintended adjacent-pin, 3.3 V-to-GND and SPI-to-supply shorts.
3. Leave JP1 open. Verify that its input and output have no direct short and that R1 is the 10 kΩ /CS pull-up. Check that the target chip is a compatible 3.3 V part. Do not attach the clip if its pinout or orientation is uncertain.

## 2. Prove the supply and reset

1. With the target still disconnected, power the ESP32-C3 by USB. Check 3.3 V at JP1's input. With JP1 open, check the J1 VCC side; with JP1 closed, check approximately 3.3 V and correct polarity at J1 VCC, /WP and /HOLD. Stop if the voltage or polarity is wrong.
2. Reopen JP1 and connect the clip while transfers are stopped. Check the target-chip VCC and GND. Then close JP1 and measure approximately 3.3 V at the chip under load.
3. **A reset is proven only if chip VCC actually falls low enough when power is removed.** JP1 interrupts only the direct supply; SPI pins may backfeed the chip. If VCC does not fall, stop and resolve this before claiming a reset. Disconnect USB before changing the clip or wiring; reconnect and repeat the electrical checks afterward.

## 3. Detect and take three independent reads

Install `flashrom` and identify the current native USB serial port. From PowerShell, run the versioned [first-dump runner](../firmware/flasher-v0.2/tools/first_dump.ps1):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\firmware\flasher-v0.2\tools\first_dump.ps1 -Port COM17
```

Replace `COM17` with the port identified for this session; it must be present when automatic mode starts. Run the command from the repository root, or use an absolute path to the script. The runner creates a unique private folder under `%LOCALAPPDATA%\TB2-C3-Dumps` by default. It rejects an output folder inside a Git checkout. `-OutputRoot` selects a different private location, and `-FlashromPath` selects an installed `flashrom.exe` outside `PATH`. If you have a known-good Pico dump from the **same unchanged flash**, pass its private path as `-ReferenceDump` for an additional full comparison.

Before using automatic mode, check with the target disconnected that opening JP1 drops target VCC and closing it restores approximately 3.3 V at the chip. Before **chip detection and each of the three reads**, the runner then waits for a new Windows USB arrival of the selected `-Port`. Leave the ESP32-C3 USB cable plugged in, open JP1 and close it; the runner proceeds immediately when the same USB device reappears on the selected COM port. Do not unplug and reconnect the ESP32-C3 merely to satisfy this gate: a USB reconnection does **not** prove that the target flash was reset. The target battery and USB must stay disconnected.

The automatic wait expires after 180 seconds by default; `-ResetTimeoutSeconds 300` changes that limit. If JP1 does not cause USB re-enumeration, add `-ManualReset` to the command above to keep the former pause: after measuring the target power cycle, press any key once, without Enter. Ctrl+C aborts either mode. The Shield-to-target reset and the automatic trigger have not been physically verified together.

The runner requires the `tb2-c3-serprog` programmer identity, the `W25Q128.V` chip, and a confirmed **actual SPI clock no faster than 500 kHz** on every flashrom call. This extra check matters because [flashrom can warn and continue](https://github.com/flashrom/flashrom/blob/main/programmers/serprog.c) when a requested serprog clock change fails. It then requires three complete **16,777,216-byte** reads and compares their SHA-256 hashes and bytes. Logs and reads remain available in the private session folder if any check fails. No erase or write command is issued.

Matching reads establish repeatability of this connection, not independent correctness of the contents. If detection, voltage or reads fail, stop and inspect the physical connection. After checking wiring and power, `-SpiSpeed 250k` is an optional slower retry. Keep the original backup private. A future write or erase requires a separate procedure with its own reset pause, renewed chip detection and a verified backup.
