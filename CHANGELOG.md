# Changelog

## Flasher v0.2 — 2026-10-25

- Adapt the proven read-only Pico/flashrom acceptance sequence for the ESP32-C3 Shield: explicit target-reset checkpoints, conservative SPI clock verification, expected programmer and chip identity, and three complete matching reads.
- Continue after each measured target power cycle with a single keypress, without typing a confirmation word or pressing Enter.
- Keep the Hardware Rev. 0.1 manufacturing package unchanged; physical target-flash validation remains pending.

## Flasher v0.1 — 2026-10-25

- Add the pinned GPLv3 ESP32-C3 serprog source and previously flashed images.
- Document the physical reset checkpoints and the first-dump procedure without erase or programming.

## v0.1.0 — 2026-10-10

- Publish Hardware Rev. 0.1 as an unverified build candidate.
- Include the editable Fritzing design, prepared Gerber and through-hole assembly files.
- Add top and bottom board marking with a `Netfreak` QR code.
- Document bare-PCB and factory-assembly ordering, pin mapping, hand soldering and pending physical checks.
