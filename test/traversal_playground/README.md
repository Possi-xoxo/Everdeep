# Traversal Playground

The playground is the project's main scene: press **F5**. Alternatively open `res://test/traversal_playground/traversal_playground.tscn` and press **F6**. The original Player V2 lab remains available.

- **1 / 2 / 3:** start Vertical / Speed / Mixed.
- **R:** fresh attempt at the current course start.
- **Home:** return to the hub.
- Falling below Y = -6 resets to the selected course start. Walking into a branch also selects it.
- Existing controls: WASD, Shift run/sprint, Space jump, Alt roll, E climb, CTRL toggle crouch. A visible climb prompt (up to 2.5m) is executable: pressing or holding E commits immediately and assists the approach. You do not need to walk closer. Holding E before the prompt also works; releasing it clears unconsumed intent, not an already accepted climb.

## Courses

`vertical_course.tscn`: staggered rising threshold route to 12.15m. Relative rises: .30, .35, .65, .75, 1.50, 1.70, 2.00, 2.40 and 2.50m. The 1.70m boundary has a .30m right-side approach-step bypass. The final +2.75m face is deliberately unsupported by current climbing. Leave that face unsolved; do not raise controller thresholds to finish it.

`speed_course.tscn`: approximately 100m of platforms, .0–1.8m gaps, changing spacing/elevation, .65m roll-height faces and one +2m climb. Several early jumps intentionally occur before sprint buildup can finish. Rises labelled ROLL test the roll-height allowance; geometry also permits jump alternatives rather than imposing artificial action gates.

`mixed_course.tscn`: compact route with .30m stepping, .65m roll, +1.5m jump, +2.4/+2m climbs, a right turn/drop, gap, left turn, immediate post-climb gap, .50m support beam and a final drop. This route requires deliberate direction changes; slow down to inspect transitions when needed.

## Editing / extending

All collision and mesh blocks are ordinary saved scene nodes, visible and editable without running the scene. Each course is a separate PackedScene, oriented along its local -Z. Inspect `Geometry` nodes and `rise_m` / `gap_m` metadata; update labels and mesh/collision sizes together when tuning. Heights in names/labels are relative rises, not absolute world Y.

Add future sections to a course, or instance another module under `Courses` with a `Start` Marker3D. Keep the first landing pad at local Y=0 around Z=-2 for automatic branch selection. Additional hotkeys can be added to the small scene-local script when needed. There is no scoring, timer, gameplay checkpoint framework or implementation of future mechanics.

Reset replaces the player instance instead of partially clearing live action state. This deliberately clears animation, sprint buildup, rolls, mantle ownership, ground support/coyote and visual IK caches. Fall recovery is a coarse development safety net; falling onto a lower platform does not automatically reset you.

## Checks

`res://test/test_sprint_jump_continuity_v2.gd` tests RUN-jump buildup reset, active-SPRINT preservation, cancellation and repeated jumps. Each RUN jump restarts buildup from zero; uninterrupted grounded running earns Sprint. Walking off an edge does not itself reset progress, and air time cannot earn it.
`res://test/test_traversal_playground_v2.gd` tests all starts and fall resets, reset during committed mantle, saved geometry dimensions, the tower's step/roll/jump/bypass and climb faces, the impossible face, and three consecutive speed-course gaps.

Human playtesting should focus on mixed-course flow, jump timing near the 1.70m boundary, repeated roll-to-jump transitions, and camera readability. The tests do not claim a full human-speed completion of every possible route.
