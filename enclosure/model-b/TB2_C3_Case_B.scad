/* TB2 C3 case, Model B Rev. 0.9: pins extend 4.5 mm BELOW THE SHIELD.
 * Keep the module on one 2.5-mm header spacer. Raise the shield seats,
 * USB opening and closed roof together to provide the lower pin cavity.
 * Physical fit remains unverified.
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

model_b_pin_projection = 4.5;
model_b_tip_clearance = 0.3;

include <../TB2_C3_Case.scad>;

esp_pin_tail_below_shield = model_b_pin_projection;
// Give the entire normal floor 0.3 mm clearance below the pin tips.
// Existing local solder wells provide additional room, not the required gap.
solder_clearance = model_b_pin_projection + model_b_tip_clearance;
pin_floor_clearance = model_b_tip_clearance;
// Four longer seats carry the shield on both sides at the new PCB height.
support_depth = 4;

assert(abs(esp_pin_tail_below_shield-4.5)<eps
       && solder_clearance>=esp_pin_tail_below_shield+pin_floor_clearance-eps,
       "Model B requires the full 4.5 mm below the shield plus tip clearance");
