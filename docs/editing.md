# Editing the Fritzing design

[TB2-C3-Dev-Shield-Assembly-Rev0.1.fzz](../hardware/TB2-C3-Dev-Shield-Assembly-Rev0.1.fzz) contains the PCB, schematic and embedded custom parts. The project was checked with **Fritzing 1.0.8**. Save changes under a new revision name.

## Prepared Gerber versus native export

**Use the supplied `Gerber.zip` for an unchanged Rev. 0.1 board.** A fresh native Fritzing export needs the same manufacturing preparation:

- Set the rectangular contour tool centreline to **39 × 22.52 mm**. Fritzing's rectangular board export is inset by half the outline stroke width; validate the rectangle before applying any correction.
- Extend the top solder-mask openings across all **16 paired module lands**. The prepared openings are 1.30 mm wide over the 1.10 mm copper bridges, allowing the outer direct-solder lands to remain exposed.
- Remove an unused legacy four-parameter rectangular aperture definition from the lower silkscreen only if it is present and unused. Do not remove used apertures or artwork.
- Keep copper and drill geometry unchanged by this export preparation.

The two name/QR markings are silkscreen-only parts. Rear artwork is mirrored in PCB coordinates so that it reads normally when viewed from the back. A decoder accepting a QR is not sufficient to establish its orientation: also inspect the geometry and rear preview. Both codes contain the literal text **`Netfreak`**.

## Design references

| File | Contents |
|---|---|
| [design.json](../hardware/design.json) | Board dimensions, pad coordinates and drills, component envelopes and datasheet references |
| [routing.json](../hardware/routing.json) | Route references and points; coordinates in millimetres |
| [netlist.json](../hardware/netlist.json) | Expected pad membership of each electrical net |
| [Schematic.svg](Schematic.svg) | Editable vector export of the circuit |
| [export-check.json](export-check.json) | Manufacturing checks bound to the released FZZ hash |

Coordinates use top view, USB edge above, origin at the upper-left PCB corner; X increases rightward and Y downward. `JL` and `JR` mean the left and right module rows in this view. Their logical pin names are not GPIO numbers. Pads ending in `D` are the corresponding outer duplicate contacts.

These JSON references and SVG exports describe this release; they do not update automatically when the FZZ changes. Regenerate or update all affected manufacturing and documentation files together.

## After editing

Check all nets, both contacts of each module pair, JP1 isolation, R1's target-side connection, the ACT branch, drill sizes, copper clearance, solder-mask openings and both QR codes. Repeat native DRC and inspect the exported copper independently. Validate actual module, cable, socket and soldering clearances before manufacture.

Gerber, BOM, THT positions, drawings and the FZZ must describe the same revision. Recompute release checksums after any change. The [validation record](validation.md) distinguishes file checks from pending physical acceptance.
