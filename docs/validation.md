# Validation — Hardware Rev. 0.1

**Unverified build candidate.** File checks were completed on 2026-10-10. They do not establish that an assembled shield has passed physical acceptance.

## File checks completed

| Check | Result |
|---|---|
| Native Fritzing 1.0.8 DRC | Passed; [result bound to the FZZ SHA-256](native-drc.json) |
| PCB / schematic / exported copper | Same 18 electrical nets |
| JP1 | Input and target supplies separate with jumper open; closed jumper joins only those supply nets |
| Pull-up and ACT | R1 = 10 kΩ after JP1; target supply → R2 = 1 kΩ → D1 anode; D1 cathode → /CS |
| Module contacts | All 16 inner/outer pad pairs connected; unused GPIOs and 5 V connect only to their own paired pad |
| Drills | 48 plated holes: 42 × 1.10 mm, 4 × 0.80 mm, 2 × 0.90 mm; no vias |
| Board outline | 39 × 22.52 mm |
| Minimum copper spacing | 0.3299 mm in the exported Gerber; design requirement at least 0.25 mm |
| Minimum copper-to-edge clearance | 0.35 mm; requirement at least 0.30 mm |
| Top solder lands | 16 extended mask openings for optional direct soldering |
| QR codes | `Netfreak` decoded from both actual Gerber layers and both rendered PCB previews |
| QR geometry | 0.28 mm modules; four-module quiet zone; 8.12 × 8.12 mm total; no overlap with exposed pads |
| Rear artwork | Readable from the rear; original top marking, copper and drill geometry retained |
| Assembly files | Six BOM rows, seven THT components, 32 solder joints; JP1 pins included, shunt and ESP32 excluded |
| Electrical regression checks | 17 passed, including deliberate shorts, a removed trace, an incorrectly connected pull-up and incorrect rear QR mirroring |

Detailed values are in [export-check.json](export-check.json). The manufacturing preparation extends the top mask openings and corrects the rectangle's outline centreline. Copper and drill bytes in the prepared package match the corresponding native export.

## Physical acceptance still required

- Check the actual SuperMini outline, row spacing, edge contacts and underside clearance.
- Check socket fit and both mounting options, soldering access, USB plug access and the actual clip-cable housing.
- Check continuity through the clip and unintended shorts.
- Measure target supply without a target and under load, including open-JP1 behaviour and potential SPI backfeeding.
- Scan the manufactured top and bottom QR codes.
- Check ACT if fitted; compare two complete 16 MiB reads at 500 kHz with each other and with a known-good dump of the same unchanged flash.

Write and erase operations are excluded from the initial acceptance procedure. Supplier review, successful DRC and a readable preview are not substitutes for these hardware checks.
