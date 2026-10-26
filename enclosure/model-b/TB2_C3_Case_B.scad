/* TB2 C3 flat dock, Model B: 4.5-mm exposed ESP32 header pins.
 * The pinheader spacer remains 2.5 mm. The printable shell matches Model A;
 * the shorter pin tail below the 1.6-mm shield is modeled separately.
 * Physical solderability and fit remain unverified.
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

include <../TB2_C3_Case.scad>;

esp_pin_exposed_h = 4.5;

assert(abs(header_spacer_h-2.5)<eps && abs(pcb_t-1.6)<eps
       && abs(esp_pin_tail_below_shield-0.4)<eps,
       "Model B requires a 2.5-mm spacer and leaves a 0.4-mm ESP pin tail");
