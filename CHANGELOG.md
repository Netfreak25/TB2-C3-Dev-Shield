# Changelog

## Flasher v0.2 — 2026-10-25

- Adapt the proven read-only Pico/flashrom acceptance sequence for the ESP32-C3 Shield: explicit target-reset checkpoints, conservative SPI clock verification, expected programmer and chip identity, and three complete matching reads.
- By default, wait for one new USB arrival before detection, then allow a configurable 250 ms settling interval. Keep target power on for all three reads and reject an unexpected COM-device change; flashrom still reopens and checks the chip for each read. `-ManualReset` retains all four single-key reset checkpoints, and the automatic wait has a configurable 180-second default timeout. USB re-enumeration is not proof of a target-flash reset.
- Keep the Hardware Rev. 0.1 manufacturing package unchanged; physical target-flash validation remains pending.

## Flasher v0.1 — 2026-10-25

- Add the pinned GPLv3 ESP32-C3 serprog source and previously flashed images.
- Document the physical reset checkpoints and the first-dump procedure without erase or programming.

## v0.1.0 — 2026-10-10

- Publish Hardware Rev. 0.1 as an unverified build candidate.
- Include the editable Fritzing design, prepared Gerber and through-hole assembly files.
- Add top and bottom board marking with a `Netfreak` QR code.
- Document bare-PCB and factory-assembly ordering, pin mapping, hand soldering and pending physical checks.
