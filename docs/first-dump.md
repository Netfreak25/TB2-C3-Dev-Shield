# First target-flash dump — C3 Shield

This is the **no erase or programming** acceptance sequence for an assembled Shield and a 16 MiB W25Q128 flash. During connection checks, TB2 Dungeon briefly sends WREN and WRDI to test the flash's volatile write-enable latch; it does not erase or program flash data. The firmware has been flashed to an ESP32-C3, but the Shield-to-target connection has not yet passed a physical test. Never save a Toniebox dump in this public repository.

## 1. Inspect with power off

1. Disconnect the target's battery and USB. Disconnect the ESP32-C3 USB cable. Fit the module with its USB connector pointing toward the Shield's USB arrow; check J1's notch, pin 1 and the clip's actual pin-to-pin continuity.
2. Measure all eight paths from the module through J1 to the SOP8 contacts against the [pin table](hardware.md#j1-and-sop8-mapping). Check for unintended adjacent-pin, 3.3 V-to-GND and SPI-to-supply shorts.
3. Leave JP1 open. Verify that its input and output have no direct short and that R1 is the 10 kΩ /CS pull-up. Check the target chip is a compatible 3.3 V part. Do not attach the clip if its pinout or orientation is uncertain.

## 2. Prove the supply and reset

1. With the target still disconnected, power the ESP32-C3 by USB. Check 3.3 V at JP1's input. With JP1 open, check the J1 VCC side; with JP1 closed, check approximately 3.3 V and correct polarity at J1 VCC, /WP and /HOLD. Stop if the voltage or polarity is wrong.
2. Reopen JP1 and connect the clip while transfers are stopped. Check the target-chip VCC and GND. Then close JP1 and measure approximately 3.3 V at the chip under load.
3. **A reset is proven only if chip VCC actually falls low enough when power is removed.** JP1 interrupts only the direct supply; SPI pins may backfeed the chip. If VCC does not fall, stop and resolve this before claiming a reset. Disconnect USB before changing the clip or wiring; reconnect and repeat the electrical checks afterward.

## 3. Detect, then create the first backup

1. Open TB2 Dungeon in Chrome or Edge over HTTPS or localhost. Select **ESP32-C3**, its serial port, **500 kHz SPI**, and **Read Only**. The displayed baud setting does not determine the speed of native USB Serial/JTAG.
2. **Pause before chip detection:** click **Connect** and select the ESP32-C3 serial port. When the reset dialog appears, power-cycle the target flash as in section 2. Confirm only after checking its supply; JEDEC detection follows immediately. If the browser build has no reset dialog, perform this pause and power check yourself before clicking Connect. Require `EF 40 18` (W25Q128), a stable identity and matching repeated 4 KiB reads. A visible serial port alone is insufficient.
3. **Pause again before the dump:** click **Create Backup**. When its reset dialog appears, power-cycle the flash and confirm it. If the serial connection was interrupted, cancel, reconnect and detect the chip again. The browser rechecks JEDEC and repeated reads, and compares the flash unique ID when available.
4. After confirmation, the backup continues automatically. It reads the complete **16,777,216 bytes twice**, hashes both passes and accepts a backup only if they match. Do not remove the clip or change power while a read is running. On success, click **Download Backup** and save it outside the Git checkout. Check its exact size and record its SHA-256 privately.
5. Compare this backup with a known-good dump of **the same unchanged flash**, if available. A match between two reads proves repeatability of this connection; it does not by itself prove that the target contents are correct.

If detection, voltage or repeated reads fail, stop, disconnect and inspect the physical connection. Try **250 kHz** only after checking the wiring and power. Do not write or erase during this first acceptance. A future flash operation needs its **own reset pause and confirmation** immediately before writing; the chip identity and device baseline must then be checked afresh.
