# PCBWay ordering guide — Hardware Rev. 0.1

Download the files from [release v0.1.0](/Netfreak25/TB2-C3-Dev-Shield/releases/tag/v0.1.0). Keep the Fritzing design, Gerber, BOM and assembly drawings from the same release together. Hardware remains an **unverified build candidate**.

## 1. Bare PCBs for hand assembly

Upload **`Gerber.zip` only** and leave **Assembly Service disabled**. Do not upload the Fritzing file as a substitute for the prepared Gerber package. No stencil is needed.

| Field | Setting |
|---|---|
| Board type / Different designs | Single pieces / 1 |
| Size | 39 × 22.52 mm |
| Quantity | Number of individual shields required; for example, 50 |
| Layers / Material | 2 / FR-4 |
| TG | Standard option; TG 150–160 if included without surcharge |
| Thickness / Finished copper | 1.6 mm / 1 oz |
| Min track / spacing | 6/6 mil; actual minimum trace width 0.30 mm, checked copper spacing 0.3299 mm |
| Min hole size | 0.8 mm; actual drills are 0.80, 0.90 and 1.10 mm |
| Solder mask / Silkscreen | Green / White; retain both silkscreen layers |
| Surface finish | HASL lead free |
| UV printing / Edge connector | None / No |
| Via process | Standard; this design has no vias |
| Separate stencil | No |
| Assembly Service | Off for bare PCBs |

If the form displays `0.3 mm ↑` as the standard minimum-hole capability, that can remain selected: the actual hole diameters come from the supplied drill file. Changing the dropdown does not resize the holes.

The Gerber describes **one board**. Select the required number of individual boards, not that number of panels. No customer-designed panel is supplied.

Optional fabrication note:

```text
39 x 22.52 mm, 2-layer single PCB. Preserve the supplied top and bottom silkscreen, including both Netfreak QR codes. Keep any manufacturer identification clear of the QR codes, their white quiet zones and the board label. Use the supplied drill file and outline.
```

After delivery, follow the [soldering and first-use instructions](hardware.md#hand-assembly).

## 2. Optional factory assembly

Use the same Gerber, enable Assembly Service and supply the following additional files:

| Upload field | File |
|---|---|
| Gerber | [Gerber.zip](../manufacturing/pcbway/Gerber.zip) |
| Parts List / BOM | [BOM.csv](../manufacturing/pcbway/BOM.csv) |
| Assembly other files | [Assembly-documents.zip](../manufacturing/pcbway/Assembly-documents.zip) |
| Centroid | No SMT centroid is supplied: there are no SMD components |

`THT-positions.csv` is a physical placement reference inside the assembly archive, also [available separately](../manufacturing/pcbway/THT-positions.csv). Its coordinates are not generic SMT machine rotations. If a mandatory upload field blocks a THT-only quote, ask the supplier to process the assembly drawing and THT positions.

| Assembly field | Setting |
|---|---|
| Sourcing | Turnkey |
| Component side | Top; all component bodies above, THT solder joints underneath |
| Quantity | Required number of fully assembled individual shields |
| Unique parts | 6 |
| SMD / BGA-QFP parts | 0 / 0 |
| Through-hole parts | 7 per shield; 32 solder joints |
| Stencil | None |
| ESP32 / Firmware programming | No ESP32 procurement or installation; no firmware programming |
| JP1 | Two-pin header only; do not supply or fit a shunt |
| Delivery | Individual assembled shields, depanelled if necessary |

BOM quantities are **per shield**. The JL/JR row has quantity 2. The full assembly scope includes both resistors and the ACT LED. For a minimal build without ACT, change the assembly request and BOM together to omit **both R2 and D1**.

The supplier may require temporary assembly rails or a manufacturing panel for this small board. Confirm the panelization cost and delivery quantity in the quote. Leave panel layout to the supplier; do not replace the single-board Gerber with an improvised panel.

### Detailed information of assembly

The following text is below 600 characters:

```text
Assemble 7 top-side THT components per BOM and Assembly.pdf. ESP32 module and its male headers are not included. Fit JL/JR sockets in the INNER rows only; leave outer pads empty. J1: straight vertical 2x4, notch LEFT, pin 1 toward USB. D1: anode LEFT, cathode RIGHT. JP1: fit 1x2 header ONLY; do NOT supply or fit a shunt. No SMT parts or stencil. Resistor equivalents allowed per BOM; approve connector/socket/LED substitutions first. Deliver the requested quantity of separate assembled boards.
```

### Before approving the quote

- Confirm board quantity, all seven components and THT assembly are included.
- Exclude the ESP32, its male headers, the clip cable and the JP1 shunt from factory procurement.
- Check resistor body dimensions and 7.62 mm lead pitch against the BOM.
- Check J1 notch, pin 1, socket placement and LED polarity in the supplier's assembly preview.
- Keep stickers and manufacturer markings away from both QR codes and their quiet zones.

Board fabrication, components, assembly, shipping and taxes are separate quote items. No price estimate is a confirmed assembled-shield offer.

PCBWay references: [PCB order form](https://www.pcbway.com/orderonline.aspx), [assembly FAQ](https://www.pcbway.com/assembly-faq.html). Form labels and supplier requirements may change.
