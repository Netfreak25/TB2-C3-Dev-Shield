# v0.1.0 — Hardware Rev. 0.1

First public prerelease of the **TB2 C3 Dev Shield**, a 39 × 22.52 mm through-hole SPI adapter for the ESP32-C3 SuperMini and an SOP8 clip cable.

- Straight 2×4 shrouded header, target-power jumper pins and 10 kΩ /CS pull-up.
- Optional red ACT indicator with 1 kΩ series resistor.
- Inner socket rows and paired outer lands for an alternative compatible direct-soldered module.
- Board name, USB arrow and `Netfreak` QR on both sides.
- Fritzing design, PCBWay Gerber, BOM, THT positions, assembly documents and SHA-256 checksums.
- English ordering, wiring, soldering, editing and validation documentation.

**Unverified build candidate:** electrical file checks and native DRC passed; mechanical fit, supply/load behaviour and real flash readback remain untested.

For bare boards, upload `Gerber.zip` and disable Assembly Service. The same Gerber supports the documented optional factory assembly. Factory assembly includes the JP1 two-pin header but no shunt; the ESP32 and clip cable are separate. See the [ordering guide](pcbway-ordering.md).

Download all release attachments into one directory and check them against `SHA256SUMS.txt`. In a repository checkout, the manifest is in `manufacturing/pcbway/`; its filenames refer to the flat release download, with the FZZ under `hardware/` and `Assembly.pdf` under `docs/` in the repository.
