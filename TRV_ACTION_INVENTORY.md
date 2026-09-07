# Everdeep — TRV Action Inventory (2026-09-07)

Inspected the current project `Blender Master Rig.glb` using Godot 4.7.1 without modifying it. 41 TRV Actions; all are imported with LOOP_NONE, including apparent cycles/idles. Poses were sampled at 0%, 25%, 50%, 75%, and 99.99%. Pose/purpose descriptions below are approximate interpretations of skeletal samples and names, not a completed visual animation review.

Translation values are hips track peak-to-peak spans converted from source centimeters to meters. Axes are source X / source Y (horizontal) / source Z (vertical); these are spans, not net displacement. Root/hips travel must be compensated at runtime for CharacterBody-driven traversal. Significant means any span above 0.05m. No clips have been edited.

## Selection findings

- Closest grounded top-out: **TRV_SPRINT_TO_WALL_CLIMB**, 2.267s. Begins in running stride; ends deep crouched on an elevated top. Feet finish near 2.63m; hips rise about 2.09m. Horizontal hips span is only ~0.030m, unlike `_02` (~3.316m). Would need a deliberate grounded-entry blend and crouch-to-standing exit blend, plus runtime translation compensation and trajectory validation.
- **TRV_SPRINT_TO_WALL_CLIMB_02**, 1.833s: similar top-out pose with substantial forward travel.
- **TRV_WALL_CLIMB_UP / _02**, 2.033s: starts and ends in the same wall-climbing stance, rising ~1.264m. Not a standalone climb onto a platform.
- **TRV_FREE_HANG_CLIMB_LEDGE**, 3.900s: ends standing but begins hanging. Excluded under the request's no-hang constraint.
- No inspected action directly matches stationary grounded start → climb → standing finish. A recommended maximum remains provisional until the chosen sequence is agreed and visually validated; source travel alone is not a safe reach limit. The requested 2.0m minimum has not yet been applied.

## Complete inventory

| Exact Action | Seconds | Imported loop | Apparent purpose | Approximate start → end | Hips span X/Y/Z (m) | Significant |
|---|---:|---|---|---|---|---|
| TRV_BRACED_HANG_DROP_AND_LAND | 1.700 | Non-loop | Drop from hang | Braced hang → Standing/landing | 0.409 / 0.367 / 1.167 | Yes |
| TRV_BRACED_HANG_HOP_DOWN | 0.933 | Non-loop | Hanging hop | Braced hang → Braced hang | 0.044 / 0.060 / 1.076 | Yes |
| TRV_BRACED_HANG_HOP_LEFT | 1.533 | Non-loop | Hanging hop | Braced hang → Braced hang | 1.526 / 0.176 / 0.684 | Yes |
| TRV_BRACED_HANG_HOP_RIGHT | 1.700 | Non-loop | Hanging hop | Braced hang → Braced hang | 1.580 / 0.294 / 0.778 | Yes |
| TRV_BRACED_HANG_HOP_UP | 1.700 | Non-loop | Hanging hop | Braced hang → Braced hang | 0.040 / 0.358 / 1.073 | Yes |
| TRV_BRACED_HANG_IDLE | 2.367 | Non-loop | Hanging idle | Braced hang → Braced hang | 0.004 / 0.003 / 0.007 | No |
| TRV_BRACED_HANG_SHIMMY_LEFT | 1.200 | Non-loop | Lateral shimmy | Braced hang → Braced hang | 0.118 / 0.161 / 0.193 | Yes |
| TRV_BRACED_HANG_SHIMMY_RIGHT | 1.200 | Non-loop | Lateral shimmy | Braced hang → Braced hang | 0.125 / 0.157 / 0.195 | Yes |
| TRV_BRACED_HANG_TO_CROUCH | 1.167 | Non-loop | Top-out from braced hang | Braced hang → Crouched on raised top | 0.121 / 0.667 / 1.633 | Yes |
| TRV_BRACED_HANG_TO_FREE_HANG | 0.967 | Non-loop | Change hanging style | Braced hang → Free hang | 0.029 / 0.485 / 0.235 | Yes |
| TRV_CLIMB_ROPE_A | 2.633 | Non-loop | Rope climb | Rope-supported pose → Rope-supported pose | 0.454 / 0.087 / 0.667 | Yes |
| TRV_CLIMB_ROPE_B | 2.600 | Non-loop | Rope climb | Rope-supported pose → Rope-supported pose | 0.140 / 0.380 / 0.643 | Yes |
| TRV_CLIMB_ROPE_IDLE | 2.633 | Non-loop | Rope idle | Rope-supported pose → Rope-supported pose | 0.022 / 0.008 / 0.016 | No |
| TRV_DROP_TO_FREEHANG | 2.433 | Non-loop | Drop down to hanging | Standing above ledge → Free hang below | 0.609 / 0.856 / 2.138 | Yes |
| TRV_FREE_HANG_CLIMB_LEDGE | 3.900 | Non-loop | Climb out of free hang | Free hang → Standing on raised top | 0.276 / 0.926 / 2.139 | Yes |
| TRV_FREE_HANG_DROP_TO_IDLE | 1.367 | Non-loop | Drop from hang | Free hang → Standing/landing | 0.057 / 0.533 / 0.740 | Yes |
| TRV_FREE_HANG_HOP_LEFT | 2.133 | Non-loop | Hanging hop | Free hang → Free hang | 1.206 / 0.278 / 0.533 | Yes |
| TRV_FREE_HANG_HOP_RIGHT | 2.133 | Non-loop | Hanging hop | Free hang → Free hang | 1.204 / 0.279 / 0.534 | Yes |
| TRV_FREE_HANG_IDLE | 4.733 | Non-loop | Hanging idle | Free hang → Free hang | 0.017 / 0.046 / 0.006 | No |
| TRV_FREE_HANG_IDLE_B | 2.367 | Non-loop | Hanging idle | Free hang → Free hang | 0.004 / 0.035 / 0.002 | No |
| TRV_FREE_HANG_SHIMMY_LEFT | 1.400 | Non-loop | Lateral shimmy | Free hang → Free hang | 0.388 / 0.044 / 0.128 | Yes |
| TRV_FREE_HANG_SHIMMY_RIGHT | 1.433 | Non-loop | Lateral shimmy | Free hang → Free hang | 0.469 / 0.065 / 0.074 | Yes |
| TRV_FREE_HANG_TO_BRACED_HANG | 1.167 | Non-loop | Change hanging style | Free hang → Braced hang | 0.029 / 0.517 / 0.228 | Yes |
| TRV_IDLE_TO_BRACED_HANG | 1.300 | Non-loop | Grounded hang entry | Standing → Braced hang | 0.100 / 0.237 / 0.735 | Yes |
| TRV_IDLE_TO_BRACED_HANG_(2) | 1.300 | Non-loop | Grounded hang entry | Standing → Braced hang | 0.100 / 0.237 / 0.735 | Yes |
| TRV_JUMPING_TO_BRACED_HANG | 1.533 | Non-loop | Airborne hang catch | Airborne approach → Hang | 0.331 / 1.134 / 0.858 | Yes |
| TRV_JUMP_FROM_BRACED_HANG | 1.300 | Non-loop | Jump away from wall | Braced hang → Airborne departure | 0.086 / 1.875 / 1.079 | Yes |
| TRV_JUMP_TO_BRACED_HANG_B | 1.333 | Non-loop | Airborne hang catch | Airborne approach → Hang | 0.058 / 1.110 / 1.159 | Yes |
| TRV_JUMP_TO_FREE_HANG | 2.033 | Non-loop | Airborne hang catch | Airborne approach → Hang | 0.284 / 1.161 / 0.654 | Yes |
| TRV_JUMP_TO_FREE_HANG_(2) | 2.500 | Non-loop | Airborne hang catch | Airborne approach → Hang | 0.083 / 2.617 / 0.750 | Yes |
| TRV_RUN_AND_SWING_(FREE_HANG) | 2.467 | Non-loop | Run/jump/swing sequence | Running stride → Running stride after swing | 0.072 / 5.840 / 1.204 | Yes |
| TRV_RUN_AND_SWING_(FREE_HANG)_02 | 2.467 | Non-loop | Run/jump/swing sequence | Running stride → Running stride after swing | 0.072 / 5.840 / 1.204 | Yes |
| TRV_SPRINT_TO_WALL_CLIMB | 2.267 | Non-loop | Run-up wall climb | Grounded running stride → Deep crouch on raised top | 0.100 / 0.030 / 2.354 | Yes |
| TRV_SPRINT_TO_WALL_CLIMB_02 | 1.833 | Non-loop | Run-up wall climb | Grounded running stride → Deep crouch on raised top | 0.100 / 3.316 / 2.326 | Yes |
| TRV_STAND_TO_FREEHANG | 1.733 | Non-loop | Grounded hang entry | Standing → Free hang | 0.394 / 0.010 / 0.787 | Yes |
| TRV_STAND_TO_FREEHANG_02 | 1.733 | Non-loop | Grounded hang entry | Standing → Free hang | 0.394 / 0.588 / 0.782 | Yes |
| TRV_STAND_TO_FREE_HANG | 1.733 | Non-loop | Grounded hang entry | Standing → Free hang | 0.394 / 0.588 / 0.782 | Yes |
| TRV_WALL_CLIMB_DOWN | 2.033 | Non-loop | Descending wall cycle | Wall-climbing stance → Wall-climbing stance | 0.332 / 0.290 / 0.004 | Yes |
| TRV_WALL_CLIMB_DOWN_02 | 2.033 | Non-loop | Descending wall cycle | Wall-climbing stance → Wall-climbing stance | 0.332 / 0.282 / 1.302 | Yes |
| TRV_WALL_CLIMB_UP | 2.033 | Non-loop | Wall-climbing cycle; no top-out | Wall-climbing stance → Same stance, higher | 0.327 / 0.279 / 1.305 | Yes |
| TRV_WALL_CLIMB_UP_02 | 2.033 | Non-loop | Wall-climbing cycle; no top-out | Wall-climbing stance → Same stance, higher | 0.327 / 0.279 / 1.305 | Yes |

## Measured start/end foot positions

Positions below are in imported rig world coordinates (meters); they are not assumed contact heights. These help distinguish hanging/cycle clips from true grounded top-outs.

| Action | Start: left / right | End: left / right |
|---|---|---|
| TRV_BRACED_HANG_DROP_AND_LAND | (0.091795, 1.315472, 0.260577) / (-0.157685, 1.402785, 0.270714) | (0.397761, 0.087696, -0.107219) / (0.27459, 0.087342, -0.646924) |
| TRV_BRACED_HANG_HOP_DOWN | (0.091794, 1.508503, 0.280973) / (-0.157685, 1.595815, 0.291111) | (0.091794, 0.637407, 0.280974) / (-0.157686, 0.724718, 0.291111) |
| TRV_BRACED_HANG_HOP_LEFT | (0.091794, 0.772181, 0.280974) / (-0.157685, 0.859494, 0.291111) | (1.565609, 0.772185, 0.280971) / (1.31613, 0.859493, 0.291118) |
| TRV_BRACED_HANG_HOP_RIGHT | (0.091794, 0.625284, 0.280974) / (-0.157685, 0.712596, 0.291111) | (-1.219554, 0.625288, 0.280974) / (-1.469023, 0.712616, 0.291119) |
| TRV_BRACED_HANG_HOP_UP | (0.091779, 0.559513, 0.28098) / (-0.157685, 0.646817, 0.291111) | (0.091792, 1.330371, 0.280975) / (-0.157696, 1.417675, 0.291105) |
| TRV_BRACED_HANG_IDLE | (0.091794, 0.772181, 0.280974) / (-0.157685, 0.859494, 0.291111) | (0.091782, 0.772184, 0.280974) / (-0.157681, 0.859465, 0.291104) |
| TRV_BRACED_HANG_SHIMMY_LEFT | (0.150751, 1.223691, 0.254371) / (-0.090541, 1.311003, 0.318567) | (0.150802, 1.223677, 0.254378) / (-0.090494, 1.311, 0.318559) |
| TRV_BRACED_HANG_SHIMMY_RIGHT | (0.091795, 1.223691, 0.280974) / (-0.157686, 1.311003, 0.291112) | (0.091748, 1.223685, 0.280965) / (-0.157732, 1.310995, 0.291122) |
| TRV_BRACED_HANG_TO_CROUCH | (0.087864, 0.287281, 0.280847) / (-0.161732, 0.374593, 0.287552) | (0.102762, 1.821719, 0.447837) / (-0.175326, 1.835155, 0.507351) |
| TRV_BRACED_HANG_TO_FREE_HANG | (0.091795, 1.082535, 0.280974) / (-0.157685, 1.169847, 0.291112) | (0.051862, 0.444365, 0.455882) / (-0.057683, 0.410929, 0.352633) |
| TRV_CLIMB_ROPE_A | (0.032951, 0.308458, 0.04834) / (-0.248146, 0.272651, -0.012432) | (0.242004, 0.887032, 0.036869) / (0.068466, 0.851216, 0.266312) |
| TRV_CLIMB_ROPE_B | (0.20997, 0.489114, -0.039999) / (-0.16015, 0.529405, -0.209501) | (0.210103, 1.018665, -0.039729) / (-0.160084, 1.058944, -0.209565) |
| TRV_CLIMB_ROPE_IDLE | (0.121816, 0.448418, 0.072826) / (-0.103517, 0.405736, 0.121034) | (0.12182, 0.448548, 0.072674) / (-0.103434, 0.405744, 0.120734) |
| TRV_DROP_TO_FREEHANG | (0.078879, 2.559256, 0.269777) / (-0.044289, 2.558896, -0.269917) | (0.250706, 0.444368, 0.493893) / (0.360259, 0.410935, 0.597147) |
| TRV_FREE_HANG_CLIMB_LEDGE | (0.061831, 0.4191, -0.020331) / (-0.047722, 0.385659, -0.123588) | (0.238752, 2.552988, 0.912859) / (0.115585, 2.552623, 0.373164) |
| TRV_FREE_HANG_DROP_TO_IDLE | (0.061831, 0.620137, -0.018879) / (-0.047722, 0.586705, -0.122134) | (0.078642, 0.087332, -0.183698) / (-0.04431, 0.0873, -0.723523) |
| TRV_FREE_HANG_HOP_LEFT | (0.061831, 0.444367, -0.018879) / (-0.047722, 0.410935, -0.122134) | (0.954389, 0.444339, -0.019086) / (0.844836, 0.410982, -0.1223) |
| TRV_FREE_HANG_HOP_RIGHT | (0.061831, 0.444368, -0.018879) / (-0.047722, 0.410934, -0.122134) | (-0.830705, 0.444445, -0.019056) / (-0.940289, 0.410923, -0.122348) |
| TRV_FREE_HANG_IDLE | (0.100145, 0.275069, 0.013192) / (-0.116984, 0.282098, 0.0244) | (0.100876, 0.275191, 0.014009) / (-0.117533, 0.282227, 0.025461) |
| TRV_FREE_HANG_IDLE_B | (0.061834, 0.444367, -0.018882) / (-0.047722, 0.410935, -0.122138) | (0.061775, 0.444369, -0.018836) / (-0.047619, 0.410933, -0.122166) |
| TRV_FREE_HANG_SHIMMY_LEFT | (0.061282, 0.444367, -0.020592) / (-0.051102, 0.410935, -0.120759) | (0.434876, 0.436565, -0.033433) / (0.292246, 0.440795, -0.103596) |
| TRV_FREE_HANG_SHIMMY_RIGHT | (0.061972, 0.444368, -0.018412) / (-0.046799, 0.410935, -0.12249) | (-0.349474, 0.444394, -0.01841) / (-0.458315, 0.411035, -0.122443) |
| TRV_FREE_HANG_TO_BRACED_HANG | (0.061831, 0.444367, -0.018879) / (-0.047722, 0.410934, -0.122134) | (0.101744, 1.08254, -0.193785) / (-0.147728, 1.169845, -0.183647) |
| TRV_IDLE_TO_BRACED_HANG | (0.078885, 0.087696, 0.264983) / (-0.044287, 0.087342, -0.274721) | (0.091804, 1.004478, 0.470362) / (-0.157683, 1.091791, 0.480505) |
| TRV_IDLE_TO_BRACED_HANG_(2) | (0.078885, 0.087696, 0.264983) / (-0.044287, 0.087342, -0.274721) | (0.091804, 1.004478, 0.470362) / (-0.157683, 1.091791, 0.480505) |
| TRV_JUMPING_TO_BRACED_HANG | (0.06173, 1.282218, 0.262909) / (-0.074448, 1.269963, 0.108007) | (0.181155, 0.551606, 1.150479) / (-0.068325, 0.638917, 1.160617) |
| TRV_JUMP_FROM_BRACED_HANG | (0.091794, 0.772182, 0.280974) / (-0.157686, 0.859493, 0.291111) | (-0.07421, 0.594482, -2.055162) / (0.021798, 0.608916, -1.875245) |
| TRV_JUMP_TO_BRACED_HANG_B | (0.06173, 1.656175, 0.26291) / (-0.074448, 1.643919, 0.108007) | (0.076972, 0.612628, 1.315727) / (-0.17251, 0.699941, 1.325865) |
| TRV_JUMP_TO_FREE_HANG | (0.06173, 1.328845, 0.26291) / (-0.074448, 1.316591, 0.108007) | (0.125279, 0.527865, 1.066657) / (0.015717, 0.494389, 0.963318) |
| TRV_JUMP_TO_FREE_HANG_(2) | (0.078884, 0.087789, 0.269744) / (-0.044282, 0.087429, -0.26995) | (0.068098, 0.173253, 2.168344) / (-0.052038, 0.140607, 2.072619) |
| TRV_RUN_AND_SWING_(FREE_HANG) | (0.021557, 0.36022, -0.17376) / (-0.060003, 0.108231, -0.150065) | (0.021704, 0.36037, 5.664595) / (-0.060005, 0.108151, 5.690018) |
| TRV_RUN_AND_SWING_(FREE_HANG)_02 | (0.021557, 0.36022, -0.17376) / (-0.060003, 0.108231, -0.150065) | (0.021704, 0.36037, 5.664595) / (-0.060005, 0.108151, 5.690018) |
| TRV_SPRINT_TO_WALL_CLIMB | (0.108807, 0.446812, -0.100508) / (0.034455, 0.110101, -0.276134) | (0.243624, 2.626255, -0.094342) / (-0.034515, 2.639695, -0.034868) |
| TRV_SPRINT_TO_WALL_CLIMB_02 | (0.108807, 0.446789, -0.098686) / (0.034454, 0.110077, -0.274312) | (0.243618, 2.583747, 3.196264) / (-0.034509, 2.597187, 3.255723) |
| TRV_STAND_TO_FREEHANG | (0.078885, 0.085376, 0.44938) / (-0.044287, 0.085022, -0.090325) | (-0.18261, 0.447091, 0.158369) / (-0.292149, 0.413679, 0.055131) |
| TRV_STAND_TO_FREEHANG_02 | (0.078885, 0.087696, 0.269744) / (-0.044287, 0.087342, -0.269961) | (-0.18261, 0.444333, 0.371851) / (-0.292149, 0.410921, 0.268612) |
| TRV_STAND_TO_FREE_HANG | (0.078885, 0.087696, 0.269744) / (-0.044287, 0.087342, -0.269961) | (-0.18261, 0.444333, 0.371851) / (-0.292149, 0.410921, 0.268612) |
| TRV_WALL_CLIMB_DOWN | (0.250271, 0.754352, 0.228838) / (0.002105, 0.162777, 0.201172) | (0.25025, 0.754125, 0.245188) / (0.002097, 0.162592, 0.217473) |
| TRV_WALL_CLIMB_DOWN_02 | (0.250271, 1.984867, 0.244733) / (0.002104, 1.393293, 0.217067) | (0.25025, 0.721024, 0.24476) / (0.002097, 0.12949, 0.217045) |
| TRV_WALL_CLIMB_UP | (0.23569, 0.720997, 0.152522) / (-0.012544, 0.130003, 0.124692) | (0.235684, 1.984857, 0.152541) / (-0.012542, 1.393878, 0.124694) |
| TRV_WALL_CLIMB_UP_02 | (0.23569, 0.720997, 0.152522) / (-0.012544, 0.130002, 0.124692) | (0.235684, 1.984857, 0.152541) / (-0.012543, 1.393878, 0.124694) |
