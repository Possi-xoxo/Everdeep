# Top-down camera full-animation glide

Replaced the fixed top-down camera hold with a smoothstep glide over the full source animation clock (including .90x playback). Capture the displayed starting world origin and final hang follow origin once at animation start; interpolate between those fixed points from 0 to 100% clip progress. No capsule/IK chasing and no second smoothing filter that delays arrival. Camera reaches its finish as the animation ends, with existing small residual/abort reunion retained. Orbit, SpringArm collision and other traversal cameras are unchanged. Debug mode is TOP_DOWN_HANG_GLIDE. Updated the focused camera test to assert the eased path and near-final arrival rather than a stationary hold.

# Top-down entry camera hold / stable-idle reunion

Camera-only refinement in player_camera_v2.gd; traversal/motion/animation/IK tuning is untouched. Top-down hold begins only when HangTopEntry is actually the AnimationTree playback node, its helper is active and traversal is ACTIVE. Acceptance/prompt/prealignment alone does not engage it. Snapshot the last displayed camera-rig world origin (before inherited CharacterBody movement), and hold that anchor unchanged through descent, hand contact and settle. Do not descend toward the anchor at frame 9 or 16.

Reunion starts when HangPhase.IDLE is authoritative, body is within .02 m of alignment and the shared rig offset is within .005 m of its established value. Aborting/source loss also releases the hold. Reuses existing mantle camera ownership, targets, SpringArm, orbit input and exponential return-speed tuning (mantle_camera_return_speed=6). For this entry only, reunion decays a relative follow offset at exp(-6*delta), equivalent to existing easing for a stationary target but able to finish during falling/movement after an abort. About .5 seconds removes 95% of the offset; normal follow resumes below .002 m. No changes to normal climb/pull-up trajectories or camera branches.

Debug modes TOP_DOWN_HANG_HOLD and TOP_DOWN_HANG_REJOIN use the existing camera anchor/target display. SpringArm collision and yaw/pitch controls remain active. Added test_hang_top_camera_v2.gd, extending repeated/angled entry and abort fixtures to assert fixed world position, hold after frame16, real animation ownership, stable-idle reunion, orbit availability and unchanged collision shape. Play-test the character descending within stationary framing and the gentle downward camera reunion after settling.

# Hang playback speed tuning

Top-down entry now plays at .90x; vertical Hop Up/Down at 1.10x. Both are exposed on BracedHang. AnimationTree uses stretched timelines, and movement/contact clocks convert playback time back to source time, preserving paths, distances and source-frame events. Entry still arrives at source frame 9 (~.333 seconds at .90x), and its .30-second blend is unchanged. Lateral hop/shimmy speeds, private clip data and GLB remain untouched.

# Linear visual descent / frame-9 arrival

Approved model/capsule separation: the visible rig's traversal origin follows a straight, constant-progress line from the interaction position to the existing hang anchor over source frames 0–9. The capsule retains its swept, lip-clearing path, compressed to arrive at the same anchor at frame 9. A world-space difference is converted into the turning rig parent's local space each tick; it is zero from frame 9 onward. The baseline remains bound through the early zero-IK phase, preventing offset accumulation. Abort clears the visual displacement through the existing reconstructed baseline.

Arrival/twist timing is now 9 frames; entry blend remains .30 seconds. The private source clip is not trimmed or retimed, and its authored joint motion continues normally. Hand approach remains frames 12–16 and foot bracing 16–30: arrival is not an instruction to force the source hands into contact before they reach. Existing anchor, hang offset, tail, idle blend, GLB and other traversal actions remain unchanged. Visible limbs still perform their authored motion around the linear traversal origin; this is not a freeze of individual bone trajectories. As approved, the model can visually cross the lip while the capsule takes the safe route.

Entry tests cover linear samples, frame-9 capsule/model reunion and facing, frame-16 hand contact, repeated entry and abort cleanup. Backup: workspace work/top_entry_before_linear_frame9. Earlier sections below retain the history of superseded entry timings.

# Compact top-down entry opening

Follow-up: top-entry blend is now .30 seconds. The requested approximately 45-degree descent needs clarification: the existing capsule must clear the solid lip before most of the 1.75 m descent, and the fixed near-wall anchor prevents a straight 45-degree path. Movement curve has not yet been changed in this follow-up; twist and frame-16 onward remain intact.

Validation: top-entry and permanent course suites pass, including new no-rise/no-return-path and exact entry-blend duration checks. Rendered opening/contact frames reviewed: opening pose is strongly blended and frame 16 retains its established contact pose.

Replaced only the top-down entry's opening movement/turn with a compact, monotonic turn-and-drop. Capsule moves outward just to its existing wall-clearance anchor over frames 0–6, then descends over 6–16, with smooth easing and no upward takeoff arc or overshoot. Full preflight and live collision sweeps remain. Facing uses one eased twist completed at frame 16 instead of the sampled source yaw excursion.

The transition INTO HangTopEntry now crossfades from the preceding pose for contact_frame/30 seconds (.5333 s at frame 16), with the destination clip advancing normally. At frame 16 it is fully blended. The private clip itself, frame-16 onward playback, hand/foot contact timing, final anchor, exit blend, source GLB and other actions are unchanged. Earlier authored-profile notes below describe the superseded opening path. Backups of the two implementation scripts are in the Codex workspace under work/top_entry_before_compact.

# Deliberate top-down Braced Hang entry

Added grounded top-edge **E → TRV_JUMPING_TO_BRACED_HANG → HangIdle**. This is a contextual, collision-swept traversal, not a normal jump followed by automatic acquisition. Existing catch eligibility, catch trim, navigation, lateral distances, IK baseline, gait restoration, locomotion and source GLB are preserved. No commit/push performed.

## Clip inspection and retargeting

Visually inspected full source frames 0, 8, 16, 20 and 46, and rendered the new runtime entry at 0/4/8/12/16/24/40/45. The full imported clip is about 1.533 seconds (46 frames at 30 fps), with a pronounced turn, hand approach around 12–18 and a later body settle. Frame **16** is the contact target; it is not the finished hanging pose. Source starts in a jump pose, so the existing .12 s state blend supplies the grounded-to-authored-pose transition.

Original hip translation (import-local centimeters): frame 0 approximately (-.66,-.30,-167.49); frame 4 (-5.72,24.33,-174.49); frame 16 (-20.62,107.49,-140.07); frame 20 (-23.94,112.58,-135.54); frame 46 (8.92,87.55,-91.90). Local -Z is up. Thus the source has ~7 cm initial rise, ~1.13 m maximum forward travel, a side excursion and a substantial late pelvis drop. This is not a straight start/end lerp.

`HangTopEntry_Full` is a private runtime duplicate created **before** the ordinary Catch copy is trimmed to .2 seconds. No new FBX import and no GLB edits. Source hip X/Y translation is removed from this private copy; its vertical performance is normalized to the existing hang baseline. Controller travel uses sampled hip-forward acceleration, phase-warped to clear the capsule by frame 8, followed by the sampled 4–16 descent profile retimed across frames 8–16. Full path is preflighted with 96 swept capsule segments; execution rechecks each actual step. This deliberate safety phase warp prevents diagonal descent through the platform lip. After frame 16 the gameplay anchor holds while the full source settle plays; no extra settle pause is appended.

Pelvis world-yaw is sampled, unwrapped and removed from the private rotation track; controller yaw applies that turn once from actual launch orientation toward the detected wall. Remaining authored joint rotations are retained. The turn is normalized to frame 16 and wall-facing orientation held thereafter (the source's late yaw excursion must not turn the gameplay body back away from the wall).

## Query, controls and tuning

`TraversalController/BracedHang` exposes a persistent **Top-Down Hang Entry** Inspector group: prompt distance **.70 m**, lateral tolerance **.15 m**, facing half-angle **50 degrees**, contact frame **16**, hand blend start **12**, and hand positional correction cap **.45 m**. The new `TopDownEntry` child reads these at scene load (restart after changing source timing). Stand upright, face outward toward a nearby edge and press E. No new input action. Holding E does not repeatedly trigger this action. No pre-alignment is needed: the actual grounded position is the launch and is included in the validated path, so alignment distance/time are zero.

Requires a locally level supported launch, wall immediately below the lip, the existing shared bilateral hand/brace predicate, a clear standing capsule anchor, and the full clear transition path. Rejects crouched/busy/airborne states, distant edges, missing brace, narrow hand span, blocked anchor and blocked path. Height is taken from geometry, not a fixed world ledge height: tested at 2.5/3/3.5/4/5.3 m; a lower ledge is allowed only if the full hanging capsule clears surrounding ground. Maximum supported launch-top variation is .12 m by the local support rays; steep/sloped launch tops are intentionally not claimed.

Normal movement, jump, dodge, sprint, crouch and hang navigation cannot take over while TOP_ENTRY owns traversal. On completion this becomes the ordinary HangPhase.IDLE with W/S/A/D, hops, safe release, jump-off and interactions unchanged. Existing entry gait/run-time/crouch bookkeeping is reused. Source movement/deletion or a new blocker aborts to normal physics via shared restore; no teleport rollback, persistent IK or stranded camera.

## Contact and camera

Authored hands remain free before frame 12, blend toward existing below-lip grip targets during 12–16, and reach full influence at 16. Existing reach limits remain in effect; the larger .45 m correction cap is scoped only to this entry. Feet blend into wall contact during frames 16–30. The family's -.23 m rig offset and chest correction are reused, not changed. Frame-16 test errors are below .005 m; final hand contact remains subject to the existing arm-reach limit (roughly 3 cm residual in the tested tail/idle pose), rather than stretching arms or changing established idle tuning.

Camera reuses climb's world-anchor easing/follow/return response. It interpolates from launch framing to the validated hanging anchor by the contact phase, independent of per-tick capsule or IK corrections; normal follow rejoins on completion/abort. No camera distance/framing redesign.

## Playground and debugging

Permanent `hang_top_entry_course.tscn/.gd` is instanced in the Hang course, east of Navigation at local (165,0,-23). Stations: Basic, Wide, Narrow, Angled, Range, NoBrace, Blocked anchor, PathBlocked and gentle Curve. Ordinary collision ramps provide top access; .35/.70 m visual markers show prompt range. Existing `hang_vertical_course` now has a top-access ramp and E-entry label in both Vertical and Mixed, allowing top entry → S hop down → lateral movement.

Traversal debug shows grounded/candidate/prompt status, range/facing, rejection, anchor/normal, source frame, hand influence and state. Debug geometry includes lip, wall, launch, full checked path (red on rejection), anchor, facing arrow, both grips and magenta contact marker. Enable traversal/hang debug as usual.

## Files and verification

Added `player_hang_top_entry_v2.gd`; wired `player_braced_hang_v2.gd`, `player_traversal_v2.gd`, `player_context_interaction_v2.gd`, `player_animation_v2.gd`, `player_mantle_hand_ik_v2.gd`, `player_camera_v2.gd`, `player_hang_debug_v2.gd`. Added the permanent course and tests `test_hang_top_entry_v2.gd` / `test_hang_top_entry_course_v2.gd`; updated `hang_course.tscn` and `hang_vertical_course.gd`.

New tests cover repeated/angled starts, full-vs-trimmed private clips, frame-16 position/facing/hands, retained tail facing, incompatible input lockout, range, source loss, camera/visual/IK cleanup, existing E selection, all course fixtures, shimmy after entry and vertical hop-down after entry. Selected regressions passed: hang acquisition, lateral tuning, navigation (vertical chain plus laterals/jump-off), navigation course and hang camera. The older broad `test_braced_hang_v2` still reports strict idle/hoist hand-contact assertions (about .022/.032 m idle errors and .097 m maximum hoist error); it is **not** reported as passing. No unrelated IK retuning was done to satisfy that older suite. Engine emits its root-certificate warning; editor import also reports permission to save global editor settings, not a V2 parse error.

Play-test the grounded takeoff/turn pacing, the frame-16 catch, the final source settle to idle, both angle directions and the marked range boundary. Rendered stills and deterministic tests do not replace human-speed visual approval.

# Right Hop original curve restored

Disabled `braced_hang_right_hop_mirror_left_curve`. Right Hop again uses its original authored movement profile, including its settling motion. Animation, 3 m distance, playback and blends remain unchanged. The optional experiment and backup remain available but inactive.

# Reversible mirrored Left Hop movement on Right Hop

Right Hop now uses a deep copy of Left Hop's complete normalized movement profile: travel/settling, vertical rise and wall-normal retreat. Lateral profiles are unsigned along-path distance; the existing right-side route supplies the mirror direction (negating profile X would incorrectly move left). Mapping uses normalized progress over Right Hop's original timeline, not Left Hop's shorter duration. Right animation rotations/poses, full clip length, 1.1x playback, 3 m endpoint, .12 s exit blend, IK and source GLB are unchanged. Curved-path and overshoot validation read the same replaced profile, so collision checks match actual movement.

Original right samples remain preserved in `original_right_profile`. Disable `braced_hang_right_hop_mirror_left_curve` on BracedHang and restart play to restore them. Pre-change copies of the three affected controller scripts, tuning test and DEV_NOTES are saved at `C:/Users/Blake/Documents/Codex/2026-08-31/files-pasted-by-the-user-you/backups/before_mirrored_right_hop_20260908_001202`. This is an experimental movement-only adjustment, not a mirrored pose or a source asset change.

# Braced Hang navigation: safe release, jump, interactions and curves

Actual lateral-after-vertical failure was geometry validation, not stale source ownership: the vertical shelves' brace is recessed .08 m, while the old lateral validator required a coplanar wall within .02 m and used an .08 m ray. At the bottom the wall is flush so shimmy worked; above, `NO_CONTINUOUS_BRACE` rejected both actions. Separately, the 3.6 m shelf span could not fit a 3 m hop plus hand width/overshoot from its center. Lateral bracing now explicitly allows .12 m recessed support, matching vertical/contact validation, without relaxing top-height or body clearance. Vertical test walls/shelves are now 18 m wide, with wider station spacing/access floors. Tests execute both shimmies and hops after all three upward tiers.

`player_hang_navigation_v2.gd` centralizes stable-hang navigation, safe ground, interaction and jump-off; `player_hang_curve_v2.gd` handles local edge samples. Transfer completion invalidates the navigation context. Idle refresh stores current source/edge/normal context ID, derives tangent from the current normal and recomputes four lateral previews (including authored overshoot/arc clearance), upper/lower and pull-up, safe ground and interaction. Input revalidates before action. Lateral sampling now updates local edge/top/wall/normal/anchor/facing; vertical arrival still replaces its validated context atomically. Acquisition is untouched.

W: upper → hop up; otherwise valid pull-up → TO_CROUCH; otherwise no-op. S: lower → hop down; otherwise supported nearby ground → release; otherwise no-op. `braced_hang_safe_release_distance=1.75 m` is measured below the body/feet anchor, roughly one standing capsule height and deliberately below an ordinary jump-height-scale drop. Query checks walkable normal, existing five-point support footprint across release drift and full capsule clearance. It does not accept an isolated ray hit. Jump is prioritized over W/S and lateral input; interaction does not steal active movement input. Lateral held-repeat behavior is retained; W/S still require fresh input.

Jump uses existing `TRV_JUMP_FROM_BRACED_HANG`, full 1.3 s private runtime clip. Source inspection: net hip delta (-.005917,-1.875461,.108717) m in rig axes; wrists remain near ledge through frame 12, with release developing by frame 15. Controller follows the original ~.46 m rise/~.18 m outward preparation to frame 12 (.4 s), using collision checks; then launches at 4.5 m/s outward + 9 m/s up, plus up to ±1.5 m/s tangent bias from A/D. Existing ordinary jump is 8 m/s; no global jump/movement tuning changed. Hands fade at .30–.40 s, feet .25–.40 s on the actual clip clock. Physics owns ballistic movement thereafter; air steering is temporarily 15% of existing air control while the departure clip remains visible, and authored wall-relative facing is retained. Normal airborne behavior fully resumes at clip completion/landing/new catch. Same-ledge separation suppression is reused with zero global cooldown; other ledges remain catchable. Dynamic sources and blocked preparation abort safely.

Hanging E interaction reuses `context_interactable`, `can_interact`, interaction point and `begin_interaction`; only generic, non-ground-required targets are eligible, not traversal/climb targets. Radius .75 m from a hand, forward/side and per-hand line-of-sight checks. Closest eligible hand blends toward target over .25 s, gameplay fires once at .30 s, hand returns .40–.70 s; the other hand remains in ordinary ledge IK. Existing arm-length/correction limits remain, plus pre-reach .98 arm-length check. If reach is unsafe, modest gameplay interaction can still occur without an extreme pose. Body stays attached and navigation locks briefly during interaction. No new interaction framework or authored interaction animation.

Curved lateral traversal: sample every .025 m, resample local edge/face, validate hand span and recessed bracing, capsule sweeps and full authored rise/retreat/overshoot. Maximum normal change 3 degrees per sample, and 35 degrees total per action. Local-normal interpolation updates wall-facing rotation smoothly; a 90-degree corner, missing edge or unsupported brace rejects movement. Straight paths retain exact endpoints to avoid floating-point accumulation. Lateral distances remain .7 m / 3 m and playback 1.1x, full untrimmed hop clips with matching .12 s idle exits. No explicit corner, Free Hang, diagonal transfer or moving-wall feature.

Permanent `hang_navigation_course.tscn/.gd` on the east side of Braced Hang adds low/high safe-release, wall-above/blocked W, jump-off landing platform and future-range ledge, generic left/right/blocked/out-of-range buttons, a 10 m radius arc (2-degree facets), and an unsupported sharp box edge. Vertical modules widened and repositioned in Braced Hang/Vertical/Mixed; speed course unchanged. Debug adds all lateral availability/reasons/curvature, safe ground distance, context ID/tangent/normal, selected interaction/hand, launch vector, ground ray, interaction range, curved samples/tangents/normals and rejected markers. Disabled by default.

New tests `test_hang_navigation_v2.gd` and `test_hang_navigation_course_v2.gd`: both lateral actions/directions after every transfer in a three-up/three-down chain, unsafe high S, safe low S, blocked W, jump clip/impulse/bias/local suppression/airborne return, both-hand interaction once/attachment/other-hand contact/arm length/blocked/out-of-range, curved shimmy/hop/orientation and sharp rejection. Both pass. Eight regression tests pass: lateral tuning, vertical traversal, vertical course, acquisition input-repress, gait exit, hang camera, hang exits, climb camera entry. The old void-drop expectation in `test_hang_exits_v2.gd` and no-floor vertical fallback assertion were updated to the requested safe no-op. Active scene loads headlessly. Visual timing/contact and course layout still require in-game review; headless tests are not a visual signoff. Source GLB hash remains B3CC9744D338A87E6F7594E78ABAEB0F4F572F175684B1A2C2E7B8A5310DD8B9. No commit/push requested for this implementation.

# Vertical Braced Hang traversal

Added `player_hang_vertical_v2.gd` as an isolated static/compatible-wall helper. Active clips are the already-imported `TRV_BRACED_HANG_HOP_UP` (1.700 s) and `TRV_BRACED_HANG_HOP_DOWN` (.933 s). No FBX/GLB imports or source edits. Measured authored hip net vertical travel is +.77086 m up and -.871096 m down (rig -Z maps to world up). A 121-point trajectory retains authored acceleration, vertical overshoot and secondary-axis motion, removes secondary endpoint drift, and scales to the validated destination. Runtime hip translations are flattened once so the controller owns translation without double motion. Vertical playback is 1x; lateral 1.1x and 3 m hop/.7 m shimmy tuning remain unchanged.

W/S resolution is centralized in `vertical.resolve`: W checks upper target first, otherwise existing validated pull-up, otherwise remains hanging. S checks lower first, otherwise existing release. Input is a fresh `move_forward`/`move_backward` edge; busy input is ignored and holding cannot chain. Top validation was extracted without changing its physical checks. Previews refresh every .2 s in idle and synchronously on input. Committed targets are latched; no continuous target-selection jitter during flight.

Inspector defaults: up 1.4 m, down 1.6 m, separation .45 m, lateral tolerance .30 m, wall-normal tolerance .20 m, angle tolerance 10 degrees, capsule margin .005 m. Short downward ray segments enumerate ledges within the volume; validate top/face, bilateral .56 m hand span, bracing at .35/.8/1.15/1.5 m below lip, wall relationship, static source, body anchor and intervening wall continuity. Select nearest sensible safe candidate, modestly penalizing lateral offset. No unrelated-wall gap/corner/free-hang/moving-platform feature. Static pieces may differ only when the compatible intervening wall band is supported by the source/destination bodies.

The full sampled capsule corridor is checked before commitment, and each real movement increment is swept again. Source transforms must remain stable; source loss, new collision or timeout uses existing traversal cleanup. Arrival writes the validated anchor/ledge/source atomically, preserving gait ownership and returning to HangIdle without cumulative drift. Existing pull-up camera is untouched.

Hand and foot IK use a departure/reach/arrival envelope: fade old contact from 5–25%, release during the middle, reacquire target from 72–95%. Target selection switches while influence is zero. Target hands derive from actual destination edge; feet use the corresponding wall/source. No hand rotation change, no arm stretching, no frame-specific rigid hop locks. Shared -.23 m visual baseline and .08 m chest correction remain. The contact helper gained only an optional source override for destination-foot validation; existing callers retain their original behavior. Contact timing is a first-pass envelope and still needs visual tuning against play-testing.

Permanent `hang_vertical_course.tscn/.gd` added to Vertical and the west side of Braced Hang, with a compact chain in Mixed. Seven stations: basic priority/safety and top/bottom fallback, varied spacing/small shelf offsets, 1.5 m up-out-of-range, 1.7 m down-out-of-range, blocked upper, blocked lower, seven-ledge chain. Rear access ramp/deck allows starting above rejection cases. Speed course unchanged. Debug shows upper/lower volumes, candidates/rejections, selected edges/anchors, sampled paths, range deltas, top validity and W/S resolution. The basic same-plane shelves generally obstruct pull-up while an upper shelf exists; explicit resolver ordering remains upper-first even if level geometry permits both.

Tests: `test_hang_vertical_v2.gd` exercises actual three-up/three-down traversal, exact endpoints/no drift, range and blocked rejection, state lockout, shared baseline, arm lengths and release fallback. `test_hang_vertical_course_v2.gd` validates seven permanent fixtures, range asymmetry, blocked upper/lower, actual pull-up fallback, lower-target priority and debug mesh/text. Preview measured about 6.6 ms in the headless seven-station fixture (not a real-time rendering benchmark). Existing lateral tuning, acquisition input-repress, gait exit, hang exit, hang camera and climb camera-entry tests pass. Headless active scene loads. No visual play-test signoff; inspect source contact phases, near-range arcs, ramp access and debug readability. Some older idle/hoist visual tests retain obsolete pre-baseline expectations and were not used as full-suite signoff.

Future extensions should reuse the immutable target record and centralized resolver, not modify acquisition or bypass corridor checks. Dynamic ledges, diagonal/gap/corner transfers and Free Hang remain excluded.

# Right hop full-length restoration

Reverted the recent right-hop trim/splice experiments and their movement-path remapping. Right hop again uses its full source duration and captured path, including authored settling/slide. Its HangIdle blend is .12 s, matching Left Hop. Both hops remain 3 m at 1.1x playback. Chest correction and all other tuning remain unchanged. Notes below describe superseded experiments.

# Right hop ends at frame 35

Supersedes the splice below: right hop now ends at source frame 35 and blends to HangIdle over .30 s. The shortened movement profile is normalized to the preserved 3 m distance, with residual vertical/wall-normal displacement eased out to prevent an endpoint snap. Left hop and source GLB are unchanged.

# Longer right-hop splice blend

The right-hop replacement bridge now lasts the removed ten source frames (1/3 second, approximately .303 seconds at 1.1x playback), restoring the original total duration. The unwanted source motion between frames 35 and 45 remains replaced by the smooth endpoint blend. Pose and movement path use the same longer bridge; both hop distances remain 3 m.

# Right hop settling splice and 3 m travel

Both hops now travel 3 m. Right hop alone replaces source frames 35..45 (30 fps convention) with a smooth .11 s runtime-source bridge, equivalent to .10 s at 1.1x playback. Quaternion poses and the original captured movement profile share the same splice mapping. Pre-cut motion, final endpoint, idle blends, chest correction and left-hop timing are preserved. Only private runtime animation data changes; source GLB remains untouched. No fixed hand locks.

# Hop lock rollback and 2.5 m travel

Removed frame-triggered world-space hop grips and their enlarged correction-cap override. Restored the previous hop hand contact envelope. Both hop directions now travel 2.5 m. The 8 cm chest-only correction, 1.1x playback, shimmy distance and exit blends remain unchanged. The frame-lock notes below describe the superseded implementation.

# Doubled chest correction and frame-triggered hop grips

Chest-only wall offset increased from .04 to .08 m, retaining the same shared family blend and leaving pelvis/legs untouched. Hop distance remains 3 m and playback 1.1x. Hop hands capture validated world-space ledge targets at source frame 35 left / 30 right (source clock accounts for custom playback timeline). Targets stay fixed through the remainder of the action, instead of following the moving anchor/wrist. New actions clear captured grips; ordinary idle IK resumes at completion. No wrist rotation change.

Locked hop hands use the existing .45 m climb correction cap instead of the .16 m idle cleanup cap; anatomical reach limits remain enforced. Tests verify no early capture, capture within a source frame, invariant world targets, unchanged action timing/endpoints and unchanged arm lengths. IMPORTANT: this verifies target locking, not perfect solved-hand locking. Left hop maximum target error is ~4.3 cm; right remains reach-limited at up to ~27.4 cm during settling. Preserving the current 3 m path and preventing arm stretching prevents an exact right-hand lock with this setup. Further visual compensation would be a separate adjustment; do not claim the right-hop slide is fully resolved.

# Lateral checker walls and further chest reach

The two long shimmy/hop playground walls now use a world-space checker shader with 25 cm squares, including tops and ends, to expose sliding. Collision and the orange obstruction remain unchanged. Increased only braced_hang_chest_wall_offset from .02 to .04 m; pelvis, knee/foot chains, rig position, distances and playback remain unchanged.

Settled diagnostic confirms unchanged foot positions and ~2 cm wall clearance. Hand target error improved from roughly 6.6/7.4 cm to 5.1/6.0 cm in 3D; still reach-limited, not fully resolved. Headless playground load checked; visual check of checker contrast and upper-body contact still required. No commit/push.

# Braced Hang upper-body reach and 3 m hops

Added braced_hang_chest_wall_offset=.02 m. The existing hand preparation SkeletonModifier3D translates Spine2/chest and its descendants 2 cm toward the wall before solving the arms. It uses the shared visual blend, preserving family continuity and pull-up fade-out. No chest rotation, wrist rotation, limb-length or IK-limit changes. The scoped skeleton modifier resets the input pose each pass; no persistent bone overrides. Pelvis/leg chains are outside the chest subtree and stay in place. The -23 cm rig baseline remains vertical-only.

Both side hops now use the shared 3 m target. Shimmy .7 m, playback 1.1x and shimmy-idle .3 s blend are unchanged. Updated endpoint regression. Settled diagnostic shows hands shifted 2 cm toward the wall before IK, unchanged rig/body and identical foot positions/clearance compared with the pre-change pose. Contact remains reach-limited (roughly 6.6/7.4 cm 3D error); this is not a complete hand-contact fix. Manual visual review required, particularly shoulders/chest deformation and knee clearance.

# Revert Braced Hang visual wall shift

Reverted the 3 cm toward-wall visual shift at user request because of knee-clearance concerns. Removed its export and parent-space shift calculation; restored vertical-only rig positioning. The -23 cm vertical baseline and all movement/IK tuning remain unchanged. No alternative hand-contact adjustment implemented in this revert.

# Braced Hang visual wall shift

Added braced_hang_visual_wall_offset=.03 m: shared rig baseline moves 3 cm toward the validated wall, converted from world wall normal to rig-parent local space. Uses the same family blend as the -23 cm vertical offset, including pull-up fade and exit restoration; reconstructs from saved rig_base without accumulation. Gameplay transforms, hand orientation, IK targets/limits and movement tuning are unchanged.

Settled diagnostic confirms rig offset (0,-.23,-.03) on the fixture, unchanged body/anchor, and ~2 cm toe wall clearance on both feet. Actual hand corrections are ~3.0/4.6 cm, but remaining reach-limited contact error is still ~5.8/6.7 cm in 3D; this is an incremental improvement, not verified perfect wall contact. Visual play-test required.

# Hop range and shimmy-idle blend

Both lateral hops now travel 2.5 m (shared override remains enabled); expanded the inspector range to 3 m. Only HangShimmyLeft/Right -> HangIdle crossfades increased from .12 to .30 seconds. Hop blends, .7 m shimmy distance, 1.1x lateral playback, authored profiles and collision validation remain unchanged. Updated the tuning test for endpoints and per-transition blend values.

# Lateral distance and playback tuning

Requested tuning: shimmy left/right now .70 m, hop left/right 2.00 m. Authored-hop-distance mode is disabled so both hops honor the shared 2 m override. All four lateral AnimationNodeAnimation timelines run at 1.10x via a custom stretched timeline; the controller uses the same shortened duration to sample the authored motion profiles. Nominal durations are 1.091 s shimmies, 1.394 s left hop, 1.545 s right hop. Other animation states and source resources are unchanged. Existing -23 cm shared visual baseline remains intact.

Added test_hang_lateral_tuning_v2 to verify per-state 1.10x timelines, synchronized body motion, measured completion time, exact .7/2 m endpoints and no left/right pair drift. Previous visual/contact caveats remain; this tuning does not claim to resolve them.

# Shared Braced Hang baseline — additional 13 cm lowering

User-requested visual-only tuning: braced_hang_visual_vertical_offset changed from -.10 to -.23 m, with its inspector range expanded. All existing family ownership and entry/exit/pull-up blending remain unchanged. No gameplay anchors, capsule, paths, camera or IK targets/limits changed.

Settled diagnostic: actual hand displacement is now about 4.4 cm left / 5.9 cm right, but this alone is not proof of better contact. Raw wrists sit about 4.4–4.7 cm below the lip; reach-limited solved wrists sit about 5.8–6.4 cm below it instead of meeting the -1 cm target. Feet retain ~2 cm wall clearance. Existing -10 cm baseline/contact assertions are intentionally not relaxed to certify this visual tuning; play-test required, particularly early pull-up and final wrist contact.

# Shared Braced Hang visual baseline

Consolidated the existing -5 cm rig offset into a shared -10 cm baseline (braced_hang_visual_vertical_offset). Applied only to VisualRoot/MasterRig using the cached normal position, not CharacterBody, capsule, gameplay anchors or individual bones. Catch/settle blends in over .20 s; idle, shimmy and hop retain it continuously. Pull-up retains full offset through 35%, eases to zero across 35–85% using smoothstep, and is back at normal visual alignment before the gameplay handoff. Release/interruption restores the cached baseline using the existing .12 s visual blend-out. Visual weighting is now separate from the existing hand/foot contact weight, so entering pull-up no longer removes the baseline immediately. No accumulation on repeated entry.

Retuned the shared below-lip hand target from -7.5 cm to -1 cm and reduced the correction cap from 22 cm to 16 cm. Early pull-up now shares that below-lip target, returning to its existing target as hand support releases. Idle measured corrections dropped from 22 cm on both arms to 13.44 cm left / 14.12 cm right (~39%/36% reduction). Remaining correction includes ~10 cm of wall-normal mismatch, so this is not yet a few-centimeter-only correction. Reach constraints can leave ~1–2 cm idle target error and ~3.2 cm early pull-up error; no reach limits were relaxed. The hoist test explicitly records the new 3.5 cm contact tolerance rather than claiming the prior ~2.4 mm match remains intact.

Existing clip normalization, authored lateral trajectories, and sprint-tail compensation solve separate motion/retargeting problems and remain unchanged. No new per-clip pose patch was added. Foot IK still samples the post-offset pose and changes only wall-normal contact: measured idle toe clearance remains ~2 cm and correction amounts remain ~4.0/2.7 cm. No foot IK parameter changes. Debug now shows shared visual/contact weights, saved rig base, final rig position and actual limb correction magnitudes.

Tests updated for exact -10 cm nonaccumulating baseline, catch/pull-up blend continuity, early pull-up ownership, zero offset before handoff, post-exit restoration, reduced bounded hand correction and unchanged wall-foot behavior. Idle visual, lateral, camera and gait-exit tests pass; hoist checks include the explicitly documented reach-limited tolerance. Manual review should focus on early pull-up hand contact and whether the remaining horizontal reach warrants a later separate adjustment. No camera, acquisition, locomotion, gameplay path or source GLB changes. Not committed/pushed.

# Braced hops — individual authored distances

Reviewed the supplied TRV_BRACED_HANG_HOP_LEFT/RIGHT.FBX files in an isolated inspection project (not imported into Everdeep). Their moving mixamo_com takes end at 1.473806 m left and 1.311351 m right, matching the imported GLB clips. The FBXs also contain a static Take 001; that is not the active gameplay animation. FBX moving durations are 1.5/1.6667 s versus GLB 1.5333/1.7 s (one extra frame); existing GLB playback timing is preserved.

braced_hang_hop_use_authored_distance now defaults true. Left and right hops use their own measured distance, eliminating the shared 1.4 m scale factor. Existing braced_hang_hop_distance remains an optional override only when authored-distance mode is disabled. Debug markers/text reflect the actual per-side distances. The sampled trajectory, vertical arc, overshoot, root compensation and collision checks are retained. Shimmy, IK, camera and other traversal actions are unchanged.

Tests assert exact raw authored distances, profile matching, final endpoints and correct nonzero displacement after a left/right pair (left travels about 16.25 cm farther than right; that difference is authored, not drift).

# Braced Hang lateral authored-motion refinement

Confirmed runtime assignments are TRV_BRACED_HANG_SHIMMY_LEFT, TRV_BRACED_HANG_SHIMMY_RIGHT, TRV_BRACED_HANG_HOP_LEFT and TRV_BRACED_HANG_HOP_RIGHT. No Free Hang clip is assigned. Replaced the generic smoothstep travel windows with profiles sampled from unmodified private animation copies (241 samples per clip). Playback durations/speeds are unchanged.

Measurements in meters: shimmy raw hip net travel is effectively zero in both directions. These are in-place cycles, so dividing by raw hip distance would be invalid. Supporting-wrist backward displacement reconstructs the missing travel, with support changing from trailing to leading hand at 35% (visible reach arrival in source pose samples). Add the authored hip lateral sway to that displacement before normalization. Derived travel is 0.54162 m left / 0.55355 m right; configured common shimmy distance is now 0.55 m (was .35). This is an inferred contact-based trajectory, not a claim of baked root travel.

Hop authored net lateral travel is 1.47381 m left / 1.31135 m right; configured common distance remains 1.40 m, near their mean. Curves retain real source overshoot and reverse settling rather than clamping lateral progress to 1. Authored relative vertical peaks are .62749 m left / .77734 m right; both are now controller motion, not the previous 20 cm visual bob cap. Shimmy rise (.19065/.19212 m) is likewise sampled. Endpoint vertical drift is removed by subtracting the linear start/end difference; outward wall-normal motion is retained while inward motion is omitted for safety.

CharacterBody follows the sampled lateral curve scaled to the configured distance, plus the vertical/retreat offsets. The stable ledge geometry anchor moves laterally only; transient body rise does not move the ledge/IK plane. Private runtime hip-position tracks are flat in all axes at the idle reference, so this movement occurs once, not through both skeleton and body. Limb rotation/IK settings remain untouched. Final profile sample is exactly (1,0,0), and completion converges to that endpoint without accumulated drift.

Collision validation retains the existing continuous ledge query and additionally checks the full scaled arc, including lateral overshoot, using dense capsule sweeps before commitment. Each runtime move still checks current geometry and sweeps to the expected body position. An overhead obstacle intersecting only the arc rejects the action. Debug adds normalized lateral sample, vertical/retreat meters, expected/actual body position and error, final anchor, and an orange sampled-path line.

Tests: lateral regression now compares every sampled hop lateral/vertical value against the raw imported clip, verifies flat runtime hip tracks, measures reconstructed shimmy distance, checks frame-by-frame body positions, exact endpoints, repeated movement, input lockout, gap/end/blocker rejection and overhead arc clearance. Pass; minimum toe clearance in the fixture is positive for all four actions (~1.0–1.5 cm). Existing camera, gait exit, hoist, acquisition, release and standard climb camera regression suites are rerun. Manual side-view review is still needed for artistic synchronization, especially the shimmy stance-switch inference and the right hop's larger vertical arc. No camera, acquisition, idle IK, pull-up, release or source GLB changes; no commit/push.

# Braced Hang lateral shimmy and hop

Added four runtime AnimationTree states: HangShimmyLeft/Right and HangHopLeft/Right, using the existing imported TRV_BRACED_HANG_SHIMMY_LEFT/RIGHT and TRV_BRACED_HANG_HOP_LEFT/RIGHT clips. No FBX imports or source GLB edits. HangPhase.LATERAL owns a committed action; A/D chooses direction, Shift chooses hop at initiation. Later modifier/direction changes cannot interrupt or restart it. W/S are rejected until idle returns. Holding a lateral direction can initiate the next action after completion without a new buffering framework. Grounded Shift is untouched.

Authored measurements: shimmy clips are 1.20 s and have effectively zero net hip displacement (in-place); hops are 1.533 s left / 1.700 s right with about 1.474 m / 1.311 m authored lateral displacement. Initial controller travel is 0.35 m shimmy (~0.29 m/s average) and 1.40 m hop (~0.91/0.82 m/s average). Distances are exported independently; durations retain native clip timing. Smoothstep travel windows are 8–92% shimmy and 12–82% hop, read from the authoritative animation clock. Anchors use a saved start plus absolute displacement, not accumulated increments.

player_hang_lateral_v2 is a separate query/action helper; automatic acquisition was not modified. The query samples every 2.5 cm, checks three hand-support offsets, bracing at four heights, same collider and normals (dot >= .995), and <=2 cm plane deviation. Standing capsule sweeps/overlaps cover body/head and an additional 30 cm outward envelope for visual hop retreat. Target and intermediate support must remain continuous; gaps, corners, different sources, ledge ends, protrusions and blocked targets reject without an animation. Each movement increment is revalidated. A new blocker cancels lateral motion at the last safe anchor and restores idle; existing source/contact-loss handling still releases safely. Future corner/gap/transfer features can build on the query but are deliberately unsupported now.

Runtime animation copies cancel lateral root travel. Hip vertical motion is normalized to existing hang idle and bounded to 20 cm. Hops retain up to 30 cm authored outward hip retreat: removing this caused right-hop toe penetration, while retaining it keeps authored foot clearance without increasing existing IK caps. Shimmy uses alternating lead/trailing hand release windows (5–55% / 45–95%); hop releases across 8–25% and reacquires across 70–94%. Targets follow authored lateral wrist placement within the validated span, projected to the existing lip/wall offsets. Existing capped wall-aware feet and wrist orientation remain unchanged. Idle hand correction cap limitation remains as documented below.

Added hang_lateral_course.tscn to the active hang course at local (37,0,-23): two 18 m walls, labeled shimmy/hop ends and an orange lateral obstruction, on a floor adjoining the original course. Existing debug shows tangent, requested target validity/reason, distance, bracing/clearance, animation/IK phase, and cyan shimmy/magenta hop target markers. Normal hang camera remains active; no new cinematic mode.

Tests: test_hang_lateral_v2 covers four clips, exact distances, repeat holds, modifier/direction/W/S lockout, no drift, end rejection, obstruction before/during movement, internal same-collider gap rejection, hand release/contact, arm lengths, toe penetration and subsequent pull-up. Existing hang camera, gait exit, hoist, input-repress acquisition, release and standard climb-camera tests pass. Active playground headless smoke test passes. Manual play-testing is still needed for action feel and alternating hand contact, especially the longer right-hop clip. No commit/push performed for this implementation.

# Braced Hang pull-up camera

Camera-only refinement: player_camera_v2 reuses the existing mantle anchor, exponential follow and reunion branch for a running TO_CROUCH in traversal ACTIVE. This phase is committed only after request_up validates the destination; idle hang, blocked attempts and S/release do not acquire the hold. A captured validated landing anchor plus animation progress drives smoothstep framing from the starting anchor toward the top, independent of instantaneous capsule or IK corrections. Uses existing mantle follow response 5/s and top offset .4 m. Mouse orbit, pitch limits, SpringArm collision, distance controls and existing lock-camera precedence remain unchanged.

Reunion starts when ACTIVE ends after the supported top-out/state handoff, or whenever the pull-up is interrupted. Existing exponential return response is 6/s (about .5 seconds to close 95% of a stationary gap, not a fixed-duration blend). Normal follow resumes within 2 mm. Camera ownership is separate from gameplay ownership and also cleans up on failure. Optional camera debug text reports HANG, HANG_PULLUP_HOLD, REJOIN, NORMAL or CLIMB plus anchor and target. No gameplay, animation, IK or trajectory edits.

Added test_hang_camera_v2 for repeat completion, idle, blocked destination, release, interruption, body-correction isolation, orbit and reunion cleanup; standard climb camera and gait-exit regressions are also run.

# Braced Hang pull-up — exact sprint-tail path mapping

Replaced the independent braced hoist and toe-clearance bake with the existing TRV_SPRINT_TO_WALL_CLIMB_02 reference path. Braced frame 10 maps to sprint frame 27; braced frame 35 maps to sprint frame 55. Between these points the clock is mapped linearly. The shared sprint reference path is placed relative to the same ledge/landing, using its 2.54 m reference height, 40 cm cubic control height, forward bias and completion point, not a separately approximated hang curve. The opening hang section connects to the shared path at frame 10.

Transferred the prepared sprint hip-position track over the same mapped interval into the private braced runtime clip, including mapped key times and an explicit frame-10 key. Frames 5–10 blend into this translation. This also matches the vertical root compensation; changing the capsule alone would again leave the rendered source lift unchanged. Removed the toe-derived forward/down correction. Braced joint rotations and source GLB remain untouched. Sampled corresponding joint poses differ by roughly 3–10 degrees on average before converging at the end, so this matches trajectory/root translation, not every limb pose. Total braced clip duration, idle hand settings, landing setback, acquisition and exit/gait restoration are retained.

Validation: test_hang_hoist_arc_v2 now asserts exact mapped body paths and runtime hip translations, dense capsule clearance and rendered late-foot proximity at four heights. Pass. Hang gait exit, playground and exits pass. Historical tests asserting the superseded independent arc's <5 cm capsule overshoot were replaced with direct sprint-path equivalence; visible foot-height checks remain. Existing idle hand-cap caveat remains unchanged.

# Braced Hang pull-up — remove rendered late float

Screenshot follow-up: the capsule-only trajectory refinement preserved authored vertical motion through root compensation, so it did not solve the visible float. Runtime measurement showed the lower toe about 35 cm above the ledge at 76% progress, with both feet still outside the wall plane.

Added a private runtime hip-translation bake after supporting-hand alignment. It samples the actual toe poses plus the controller trajectory, eases in across 60–78% during hand release, brings the lower toe toward 4 cm above the lip and the leading toe toward 4 cm inside it, and fades out across 90–100%. Corrections are bounded to 40 cm vertically and 45 cm forward. No bone rotations, imported source clips, idle pose/hand tuning, acquisition, capsule path, landing setback, clip duration, or exit behavior changed.

Validation: expanded test_hang_hoist_arc_v2 checks rendered toe clearance and leading-foot proximity across 78–90% at four ledge heights, in addition to existing capsule sweeps, early hand support, arm lengths and supported completion. Pass. Hang gait exit, playground and exits also pass. Existing idle hand-target cap limitation below is unchanged. Visual approval remains a play-test task.

# Braced Hang pull-up — coordinated late hoist

Replaced the separated lift-then-forward trajectory with a cubic hoist modeled on the sprint climb's path construction. Preserves the supporting first 45% of the clip, then blends lift and forward travel together through 98%. Uses an 8 cm control-point clearance (not the sprint clip's 40 cm setting); measured capsule-base overshoot is 4.45 cm instead of 10.6 cm. Final 15 cm landing setback, clip duration, gait restoration, exit blending, acquisition, idle hand targets and rotation remain unchanged.

Runtime root compensation and early supporting-hand compensation now reference the same path. Source GLB and authored vertical pose trajectory remain untouched; reduced capsule overshoot is not a claim of equivalent rendered mesh height reduction. The visible change principally brings forward travel into the lift rather than delaying it to 65% of the clip.

Validation: new test_hang_hoist_arc_v2 passes dense capsule sweeps, unchanged early support, endpoints, arm lengths, supporting toe clearance and supported completion at four ledge heights. Maximum early hand error is 2.8 mm. Hang gait exit, playground, exits, standard mantle hand-height and climb-penetration tests pass. Visual play-test still required to judge feel. Existing idle exact-target test limitation described below remains unchanged.

# Braced Hang idle — 7.5 cm below-lip hand targets

Following positive screenshot feedback, lowered only braced_hang_hand_vertical_offset another 2.5 cm, from -.050 m to -.075 m. Updated the solved-wrist test expectation. Rotation handling, outward clearance, body offset, foot IK and pull-up targets remain unchanged.

Validation caveat: both hands now hit the unchanged .22 m correction cap, so the exact-target/no-limiting assertions fail across the tested heights. Measured settled wrists reach about 6.0–6.3 cm below the lip rather than the requested 7.5 cm. Foot clearance and other pose checks still pass. The requested targets are retained for visual review; no safety limit was relaxed.

# Braced Hang idle — larger hand-target comparison

Lowered only braced_hang_hand_vertical_offset from -.025 m to -.050 m, an additional 2.5 cm requested for a visible comparison. Updated the solved-wrist contact-height test. Body offset, rotation handling, outward clearance, feet and pull-up targets remain unchanged. Restart play-testing to load the new script default.

# Braced Hang idle — further 5 mm hand-target lowering

Lowered only braced_hang_hand_vertical_offset from -.020 m to -.025 m following screenshot feedback. Idle wrists now target 2.5 cm below the lip. Updated the contact-height regression expectation. Rotation, outward clearance, body visual offset, feet and pull-up targets remain unchanged.

# Braced Hang idle — hand targets just below the lip

Changed only braced_hang_hand_vertical_offset from +.005 m to -.02 m and allowed negative Inspector values. Idle wrists now target the wall face 2 cm below the lip, retaining the existing .03 m outward clearance. Hand/finger animation and rotation handling, -.05 m rig offset, foot IK, acquisition and pull-up targets/blending are unchanged. Updated the idle-pose test's vertical contact expectation.

The idle-pose suite passes again, including its no-reach-limiting assertion at all four tested heights; this resolves the previous -.05 m rig-offset reach-limit caveat without relaxing safety limits.

# Braced Hang idle — additional 2 cm visual lowering

Per the screenshot follow-up, changed only braced_hang_visual_vertical_offset from -.03 m to -.05 m total. Updated its regression expectation. Hand targets, foot IK tuning, blend timing, gameplay body/capsule, hang anchor and acquisition remain unchanged. Existing hand IK still independently targets the ledge, so this is a body-pose adjustment, not a hand-target adjustment.

Validation caveat: the idle-pose suite now flags the existing hand reach limiter at all four tested ledge heights. Other assertions pass, including foot clearance, body/anchor invariance and restoration. A measured right wrist falls about 7 mm short of its target because the safety limiter prevents stretching; the left wrist reaches its target. Kept the requested -.05 m adjustment without weakening reach limits or changing hand targets. Visual review is needed before treating this tuning as fully validated.

# Braced Hang idle — render-only offset and lightweight contact polish

Focused on TRV_BRACED_HANG_IDLE. Acquisition, motor and standard mantle scripts are byte-for-byte unchanged in this pass (SHA-256 checked). Gameplay body/capsule, hang anchor/settle timing, W/S, .15 m top-out setback and gait/.30 s exit behavior remain authoritative and unchanged. No source animation/GLB edits.

The referenced screenshot was not attached to this request. Before-change numerical pose inspection showed existing corrected wrist targets at ledge +.03 m and toe samples about .047–.064 m off the wall. The old hang foot layer corrected penetration only, so these visibly separated feet received zero IK weight. Raw wrists sit about .184–.187 m above the ledge before the existing hand solver; this existing retarget requirement should not be confused with the final 3 cm target clearance.

## Visual offset / ownership

braced_hang_visual_vertical_offset starts at -.03 m, the conservative end of the requested range. It is applied ONLY to the rendered VisualRoot/MasterRig instance position. VisualRoot itself remains available to its existing locomotion/compression writers. No gameplay transform or collider moves. The exact rig base position is captured when the visual layer enters and every offset is reconstructed from that base, never accumulated. It restores the exact base and stops writing outside the visual blend.

Catch/settle uses the existing .20 s settle clock with smooth easing. Idle holds the correction. On pull-up, release or interruption it eases to zero over braced_hang_visual_blend_out (.12 s). The idle hand/foot target mix yields to the existing HangUp contacts over that same short interval; after it reaches zero, the old hoist/top contact behavior is unchanged. Release retains its existing hand fade and normal airborne foot fade rather than retaining wall targets after detach.

## Hands

Reuses the existing single hand-solver pass; no extra competing IK layer. Idle targets use the already validated ledge/top and preserve the existing grip spacing with at most .005 m of authored lateral movement. Idle vertical target clearance is .005 m; outward wrist clearance remains .03 m to avoid forcing the arms to overreach. Initial narrower wall clearance and unrestricted authored lateral drift hit the reach limit, so those were not retained. Full idle contact weight defaults to 1.0, but position correction is bounded at .22 m (down from the shared .45 m cap), existing chain reach protection is retained, and orientation influence is reduced to .10 to preserve wrist character. Poles continue to follow the authored elbow bend.

Normal mantle and HangUp's fully restored grip targets, correction cap, timing and wrist treatment are unchanged. Measured settled wrists reached ledge +.005 m without reach limitation; raw-to-solved correction remains about .18–.19 m, primarily the retargeting the existing solver already performed, not a new aggressive pose correction.

## Feet

Uses each animated ankle/toe sample AFTER the render offset. One short local ray confirms the known bracing wall under each closest foot sample; actual hit depth is used, including slight local surface relief. Only wall-normal depth changes. Authored foot height, lateral spacing, knee bend/pole and ankle orientation are preserved; no fixed world-space foot markers and no forced flat sole.

braced_hang_foot_wall_clearance=.02 m and braced_hang_max_foot_correction=.12 m. Normal measured corrections are about .027–.044 m. Missing wall, excessive correction or a target beyond .995 of chain reach fades back toward the authored pose and reports a debug reason instead of stretching. Existing foot-solver position-space easing and response are reused. After settling, toe clearance measured approximately .020 m, with unchanged leg lengths. The test also confirms .020 m clearance against a 3 cm local wall protrusion.

Tuning is grouped under BracedHang / Idle Visual Polish: visual vertical offset, hand vertical/wall offsets, hand weight/max correction, foot clearance/max correction and visual blend-out duration.

## Debug / tests / changed files

Ctrl+F3 now shows an idle-pose panel while hanging: render offset, blend, gameplay anchor, VisualRoot and rig world positions, per-hand weight/error/reach limit and per-foot actual solver weight/fallback reason. Geometry shows anchor, root/rig offset, raw animated hands/feet, corrected targets, foot ray/contact, and a known-wall rectangle. Yellow=animated, green=hand target, cyan=foot target, red=invalid/limited foot, gray=wall. Acquisition diagnostics remain available when not hanging.

Added player_hang_idle_pose_v2.gd and test_hang_idle_pose_v2.gd. Updated player_braced_hang_v2.gd (visual tuning/contact delegation only), player_animation_v2.gd (visual layer update), player_mantle_hand_ik_v2.gd (hang-idle-only target mix), player_hang_debug_v2.gd and player_debug_v2.gd.

Nine headless suites passed: idle pose, braced hang, release/retry exits, gait exit, hang playground, mantle hand heights, climb penetration, release/repress acquisition and acquisition limits. Pose tests cover 1.85/2.25/2.75/3.25 m ledges, varied wall depth/local relief, unchanged body/anchor/capsule, bounded limbs, distant-wall fallback, smooth nonaccumulating offset, exact base restoration and release/pull-up ownership cleanup. Existing supporting-hand error during pull-up remains approximately .0121 m.

Visual QA is still required; no screenshot-based sign-off is claimed. Inspect fingers/palms rather than wrist bones alone, toe mesh clearance, natural knees, and the first .12 s of pull-up/release. No commit/push or new traversal mechanics in this pass.

# Braced Hang — release/repress reliability and recent-motion sweep

## Diagnosis before changes

Used the existing Hang Detection query/HUD output on a physically valid 2.25 m ledge. With input released, .11 m/s toward the ledge passed, but .09/.05 m/s reported NO_APPROACH with every height/reach/brace/body/head check passing. The old .1 m/s magnitude switch discarded genuine slow velocity and substituted the empty input vector. A deterministic repress through step_motor also reported NO_APPROACH on its first tick: acquisition ran before animation_state received that tick's W input. Querying immediately after the motor update passed. Thus W was not an unconditional requirement, but became a de facto gate at low velocity, compounded by one-frame-stale intent. The 1.7 m height gate was not the failing condition in these reproductions.

A release/retry regression trace additionally exposed tangential wall sliding: collision zeroed the inward velocity component but retained sideways velocity above .1 m/s. Input assist now accounts for confirmed contact with the SAME candidate wall rather than requiring all horizontal motion to stop.

## Focused changes

player_v2.gd passes current camera-/lock-relative input to hang acquisition at its existing input boundary. This observes input only: it does not change animation state, motor acceleration, braking, jump, coyote, gait or camera behavior. Animation-state intent remains a fallback for direct tooling/test queries.

Actual horizontal momentum is retained down to the configurable approach_speed_tolerance (.005 m/s numerical tolerance, not a run-speed requirement). The existing .05 normalized approach dot remains a generous direction test; debug also reports actual signed velocity toward the candidate in m/s. Bounded previous-frame displacement can establish approach after wall collision zeroes velocity. Input can assist near-zero motion, or tangential sliding in confirmed same-wall contact when there is no away component. Genuine away motion overrides intent and immediately clears that candidate's remembered approach. Facing remains the unchanged +/-100-degree supporting limit; the search is still velocity-led with intent/facing supporting rays.

candidate_grace_time defaults to .15 seconds. A nearby, physically checked approaching candidate can prime this grace just before entering the vertical band. Grace is source- and edge-specific (within .25 m of that same edge), cannot refresh itself, and never bypasses current horizontal reach, vertical/swept reach, height eligibility, width, hands, bracing, capsule clearance or regrab suppression. Landing, busy traversal, reset/teleport and away movement discard history appropriately. No remote catch or cached-transform commitment was introduced.

recent_sweep_distance defaults to .45 m, independently limiting the previous-physics-position to current-position sweep; the existing .45 m predictive cap remains. Both trajectories sample at <=.15 m spacing. Teleport-sized discontinuities discard previous motion instead of sweeping through the world. All alignment still validates from the current actual capsule, and the .40 m horizontal correction bound is unchanged. Rising/falling use identical physical rules.

Height category and current reach remain separate: category height is ledge top minus the launch/lower-current-feet reference, and must be > the physics-derived approximately 1.7 m jump threshold. Actual catch reach uses current hand height (feet + 1.75 m), its +/- .40 m envelope, and bounded recent/predictive segments. There is no maximum obstacle-height gate at 1.7 m. Explicit tests now include 1.75, 2.0, 2.25 and 2.5 m supported ledges. No jump tuning changed.

## Debug / playground / verification

Ctrl+F3 now additionally shows ledge world top, category height, hand height, signed vertical delta, horizontal distance, velocity/input/to-ledge vectors, signed approach speed and dot, direction source, wall contact, grace use/time, swept intersection/necessity and grouped reach/direction/physical flags with the exact final reason. A lime arrow points toward the candidate; red-orange lines show recent movement alongside the existing prediction/reach geometry. Existing .20 second snapshot persistence is retained.

The Hang course's existing BASIC 2.25 m fixture is now labeled INPUT RELEASE / REPRESS with A–F instructions: continuous W, release/coast, release/repress, diagonal, rising and falling. No unrelated playground geometry changes.

Added test_hang_input_repress_v2.gd: 18 real-motor A–F attempts (three repetitions each), slow released momentum, same-tick repress, wall-slide intent, grace expiry, away precedence, head-obstruction preservation, historical falling sweep/settle and teleport-history rejection. Updated existing acquisition tests for grace and the explicit height examples; teleported hang fixtures clear history. Regression runs cover braced-hang contact/settle, W/S release/retry, gait exit, playground, sprint-jump continuity, ground support/coyote, E/held climb and climb camera.

Changed player_hang_acquisition_v2.gd, player_braced_hang_v2.gd (new knobs/input argument only), player_v2.gd (input observation), player_hang_debug_v2.gd, hang_course.tscn and the three hang test scripts. Preserved the previous .15 m near-edge top-out, W/S controls, gait restoration, .30 s exit blend, animation clips, hand/foot IK and standard mantle. No new traversal feature or commit/push. Automated tests do not replace visual play-testing: repeat A–F with Ctrl+F3 and inspect maximum swept corrections and input-source labels.

# Braced Hang pull-up — near-edge finishing position

Reduced BracedHang.landing_setback from .45 m to .15 m, matching the standard climb's current near-edge default. request_up clamps that request to GroundSupport.minimum_landing_setback(), then retains the existing actual support-footprint and complete capsule-path checks before commitment. Unsupported or obstructed top-outs are still rejected rather than forced. The final controller position is 30 cm closer to the climbed lip; current movement input can still carry the player forward during the normal exit blend.

Only landing placement changed. Source GLB, clip timing, vertical hand correction, foot bracing, W/S controls, acquisition, saved gait and .30s exit blend are unchanged. Updated test_hang_gait_exit_v2.gd to verify the .15 m target, support-safe placement and no-input finish remaining near the lip. Headless gait-exit and braced-hang contact tests pass, including unchanged supporting-hand/foot errors. Visual pose feel still needs in-game confirmation.

# Automatic Braced Hang acquisition refinement

Scope: acquisition and diagnostics only. The existing hang catch/settle, idle, hand/foot bracing, W pull-up / S release, release suppression, supported top-out, previous-gait restoration and mantle-style .30s exit blend are preserved. No Free Hang, shimmy, hops, lower-target selection, hang jump or interactions were added. Standard E climb/mantle, animation clips/root correction, movement tuning, camera and IK solvers are unchanged.

## Height reference and normal jump

There was no authoritative direct-jump height setting. The acquisition helper derives the jump-up threshold from the motor's jump_velocity² / (2 * rise_gravity), rounded UP to the next decimetre. Current 8.0 / 19.6 settings give a 1.633 m ballistic apex and a 1.7 m eligibility threshold. This does not modify jump physics. Eligibility is strictly above that threshold; airborne 1.7–2.5 m catches intentionally coexist with standard grounded E-to-climb.

Ground support now records its last confirmed supported height without changing support/coyote decisions. Acquisition uses the lower of that launch/support height and current feet height: rising catches retain the takeoff reference, while descending below a high launch platform can still catch a lower ledge. An airborne spawn without recorded support uses current feet. This reference and candidate relative height are shown in debug. Teleported automated fixtures explicitly supply their launch height.

## Direction and continuous reach

Previously the nine-ray fan was centered on visual facing, followed by another hard +/-80-degree facing gate. Only the instantaneous hand band was queried and the first valid ray won. Fast vertical movement could pass the small band between evaluations.

The fan now follows actual horizontal velocity. Below .1 m/s, current movement intent is the fallback (useful after collision removes forward velocity); input cannot override real away velocity. A small positive velocity/intent dot toward the candidate edge is required. Visual facing is only a loose +/-100-degree support check. Camera orientation is not a separate gate.

Rising and falling use the same query and validity checks. The hand band is sampled along one physics interval of predicted velocity, capped at .45 m, with samples no more than .15 m apart. This is a short predictive sweep, not a historical sweep or teleport. It can arrest upward or downward movement when the band enters reach. All candidates still require a clear sweep from the ACTUAL current capsule to their anchor, plus the existing per-frame settle collision checks. Horizontal correction is bounded independently from prediction.

All discovered candidates are evaluated; nearest valid wins instead of first-ray ordering. Diagnostics retain nearest rejected candidate when no valid candidate exists. A .15 m diagnostic search margin exposes nearby out-of-range edges without extending accepted reach. Wall, top, two-hand width/reach, bracing, body/head clearance and same-ledge suppression remain mandatory; thin unsupported lips remain rejected Free Hang candidates, not a new traversal mode.

Tuning defaults on BracedHang:

- max_grab_distance: .85 m horizontal wall reach.
- horizontal_reach_allowance: .40 m maximum current-to-anchor horizontal correction.
- vertical_reach_allowance / vertical_reach_below: .40 / .40 m above/below hand reference.
- approach_direction_dot: .05 minimum positive approach.
- braced_hang_forward_cone_degrees: 160 degrees total, now velocity/intent-centered.
- facing_acceptance_half_angle: 100 degrees.
- predictive_distance: .45 m cap on velocity * physics delta; 0 disables prediction.
- debug_persistence: .20 seconds.
- Unchanged: .50 m wall stand-off, 1.75 m hand-reference offset, .20 s catch settle, release and exit settings.

## Opt-in debug

Ctrl+F3 toggles hang detection debug and enables the player HUD when turned on. Plain F3 still toggles the normal HUD. The existing traversal_debug setting also enables these diagnostics. Default is off; normal HUD is not expanded.

Yellow rings/verticals show horizontal reach and above/below hand band; orange segments show prediction. Blue arrow = horizontal velocity, magenta = movement intent, cyan cone = velocity-led search, white boundaries = loose facing acceptance. Every considered candidate has an edge marker/normal; candidates with a usable top also show edge tangent, proposed anchor/body line, two hands and bracing test region. Green = accepted/preferred, cyan = valid not selected, red = rejected. Grounded candidates remain rejected. The last snapshot persists briefly after a miss/catch; its rejection details are retained with an explicit last-candidate label.

HUD reports airborne/rising/falling, candidate existence, reference and threshold, height/distance, approach dot/facing angle, and individual height, facing, approach, vertical/horizontal reach, regrab, width, hand reach, brace, body and full/head sweep flags. Reasons include BELOW_JUMP_HEIGHT, BEHIND, MOVING_AWAY, NO_APPROACH, VERTICAL_REACH, HORIZONTAL_REACH, REGRAB_COOLDOWN, HAND_WIDTH, HAND_REACH, NO_BRACING_WALL, BODY_BLOCKED, HEAD_BLOCKED, INVALID_WALL, NO_USABLE_TOP, NO_LEDGE, STATE_NOT_AIRBORNE and STATE_BUSY. Missing top/geometry does not fabricate pass flags for untested checks.

## Playground and verification

The active traversal playground's Hang course (4) now includes a baked, editable AcquisitionLanes wing beyond its far end. Fifteen labeled stations cover straight/left/right rising and falling, imperfect facing, fast fall/upward approach, 1.85 m and 2.4 m overlap ledges, away/behind rejection, no brace, blocked headroom and a 1.65 m below-threshold negative. Falling lanes include elevated launch platforms with simple ramp collision; approach markers support diagonal trials. Original hang fixtures and other branches remain. Floors meet at their boundaries rather than overlap.

Changed: player_braced_hang_v2.gd, player_ground_support_v2.gd (read-only support-height bookkeeping), player_debug_v2.gd, hang_course.tscn and the old test fixture's explicit launch reference/facing expectations. Added player_hang_acquisition_v2.gd, player_hang_debug_v2.gd, hang_acquisition_lanes.tscn and test_hang_acquisition_v2.gd.

Headless verification: focused acquisition tests exercise diagonal rising/falling commitment and settle, mismatched facing, fast positive/negative sweeps that fail with prediction disabled, threshold boundaries, actual floor clearance at 1.85–2.4 m, behind/away/no-input/regrab/no-brace/headroom rejection, input fallback, Ctrl+F3, mesh generation/persistence and new fixture loading. An indicative repeated-query measurement was approximately .19 ms per query in the simple fixture (not a full-game performance guarantee). Existing braced-hang contact/exit tests, gait exit, hang playground, hang release/retry, climb camera entry, mantle hands-height, sprint jump continuity, crouch handoff and ground support also passed.

These are automated physics/animation checks, not a claim of visual sign-off. Play-test diagonal rising/falling catches and fast platform drops with Ctrl+F3, inspect maximum catch correction, ensure overlay readability at your resolution, and confirm the restored gait still feels right after W top-out. No source GLB changes or commit/push in this pass.

# Hang top-out — mantle-style locomotion exit

Reviewed TRV_SPRINT_TO_WALL_CLIMB_02's exit: standard mantle hands movement back to the normal motor at supported completion, blends to locomotion using mantle_exit_blend_time (.30s), and does not stop velocity again when its EXIT phase completes. HangUp previously forced CrouchIdle and zero velocity on completion.

TRV_BRACED_HANG_TO_CROUCH now uses that same EXIT lifecycle and the same live blend setting. Once its existing trajectory finishes and support is confirmed, normal input/movement resumes during the .30s crossfade; there is no forced crouch-idle intermediary, extra crouch-to-stand clip, or final velocity reset. Its different clip/path duration is retained rather than copying mantle's frame 51 into a 35-frame animation. Catch and hoist animations, trajectory, root correction, hand-release timing and standard mantle/camera settings are unchanged.

The gait and run-build-up at automatic catch are saved before shared traversal ownership resets the motor. Top-out restores them, allowing held run/sprint intent to continue in that gait without rebuilding sprint from zero. Normal current-input rules still apply: releasing Shift selects walk; releasing movement selects idle. This does not resurrect old horizontal momentum or force sprint after the user cancels it. Previously crouched players retain crouched locomotion. Standing clearance is checked at the actual supported exit; a low ceiling keeps the safe crouched capsule instead of expanding into geometry.

Hang hand/foot/pelvis/environmental contact ownership yields at EXIT just as with standard mantle, allowing ordinary grounding during the blend. W climb-up and S release remain the controls. Release/drop behavior is unchanged. This section supersedes the older forced-persistent-crouch top-out description below.

Changed player_braced_hang_v2.gd, player_v2.gd, player_animation_v2.gd and the hang ownership predicates in player_foot_ik_v2.gd, player_mantle_foot_contact_v2.gd, player_pelvis_ik_v2.gd and player_environment_hands_v2.gd. Added test_hang_gait_exit_v2.gd and updated existing hang tests for the current W/S bindings and locomotion-return expectations.

All eight headless suites passed: hang_gait_exit, hang_exits, braced_hang, hang_playground, climb_camera_entry, mantle_hands_height, sprint_jump_continuity and crouch_handoff. Focused validation covers walk, restored partial run build-up, sprint, idle, prior crouched locomotion and blocked standing clearance; it asserts exact shared blend duration, direct destination state, supported handoff and continued velocity through completion. Playground labels now describe a locomotion return. Play-test holding W+Shift through a sprint catch/top-out, W-only walking, releasing input for idle, and low ceilings. Visual blend quality remains a rendered play-test check.

# Braced Hang exits — repeatable testing (historical)

The existing validated E climb-up is retained and verified through the actual InputMap path. After the .20s settle, E starts TO_CROUCH using TRV_BRACED_HANG_TO_CROUCH, keeps the existing environmental hand support (release over 45-70% of the clip), and finishes supported in persistent crouch. Invalid top support/clearance leaves IDLE untouched. CTRL remains the normal crouch toggle. No standard mantle trajectory or camera changes.

Space / the existing jump action now deliberately releases from Hang IDLE. SETTLE rejects both inputs, and holding an input through settle does not queue an exit. RELEASE immediately ends traversal/controller anchoring and resumes the normal collision/gravity motor; the triggering jump press is consumed. Incoming pre-catch momentum is not restored. Tunable initial release velocity is wall-normal .35m/s outward and .20m/s downward, subsequently governed by normal air control/gravity. Visual hand anchoring fades out over .10s without retaining controller ownership.

Inspected the already-imported TRV_BRACED_HANG_DROP_AND_LAND: full length 1.70s, with wrists leaving around .30-.60s and an authored nearby landing around .85s. Only the source interval .30-.60s (frames 9-18 at 30fps) is used as the private HangRelease clip. Hip translation is canceled in this per-player runtime copy and matched to hang idle height. The original GLB/full source remains untouched. The .30s release presentation yields to ordinary Fall, or immediately to normal landing if actual floor contact occurs first. It cannot make a long drop float or land in midair.

Deliberate-release suppression is keyed to the released collider plus a nearby edge (<1m), not a global hang ban. It clears after leaving the reach region (grab range/vertical allowance plus .20m), on a real supported landing, or after a tunable 1.5s safety timeout. A different ledge remains eligible while the original is suppressed. Clearing on landing is important for the low .5m hang anchor: a fresh jump can retry immediately without waiting for the timeout. Existing non-release regrab cooldown remains unchanged.

Repeated wall-touching jumps exposed an existing hang settle issue: the .002m query margin could overlap a wall that the motor was safely touching, rejecting the first tiny settle movement after a valid catch. The hang-only query margin is now .0001m, below the CharacterBody contact skin. Full capsule sweeps, overlap checks and collision-controlled movement remain in place; the normal mantle validator is unchanged.

The existing hang_course.tscn and hang_detour.tscn legends now display E — Climb Up / Space — Release. The dedicated course already has a broad safe floor beneath its primary low/medium/high structures, verified by release/retry tests; no geometry rebuild was necessary. F3's existing hang display includes RELEASE, settle completion, the last climb destination check, same-ledge suppression/reference and initial release velocity. No new cinematic camera, shimmy, hops, Free Hang or other traversal mechanics.

Files changed for this follow-up: player_braced_hang_v2.gd, player_v2.gd, player_animation_v2.gd, player_mantle_hand_ik_v2.gd, player_debug_v2.gd, player_traversal_v2.gd; hang_course.tscn and hang_detour.tscn control legends; new test_hang_exits_v2.gd and updates to test_braced_hang_v2.gd / test_hang_playground_v2.gd. All player scripts are under Characters/Player/V2; scenes are under test/traversal_playground.

Validation: all eight suites passed headlessly: hang_exits, braced_hang, hang_playground, climb_camera_entry, mantle_hands_height, ground_support, sprint_jump_continuity and crouch_handoff. Coverage includes actual E/Space input, settle and held-input lockout, valid/blocked E climb, persistent crouch, immediate physics detach, bounded outward/downward impulse, faded grip release, ordinary landing, no held-Space jump, large-drop transition to Fall, same-ledge suppression, different-ledge catch, release-land-jump-recatch and climb-crouch-return-recatch without resets. Authored low/medium/high playground ledges also pass release-land-immediate-retry. No script errors in final runs; the unrelated certificate-store warning remains. Subjective release-blend and hand appearance still need rendered play-testing.

# Automatic Braced Hang — first implementation (historical; exits above supersede no-drop scope)

Scope: airborne automatic catch -> CATCH / SETTLE -> IDLE -> TO_CROUCH -> existing persistent crouch. No Free Hang, shimmy, hops, drop, or new input bindings. The active traversal playground is extended, not replaced. Nothing in the source GLB is edited or imported for this pass.

`Characters/Player/V2/player_braced_hang_v2.gd`, mounted at TraversalController/BracedHang, owns this profile independently from the completed mantle trajectory. The motor invokes it before ordinary airborne movement. Shared traversal ownership excludes grounded catches, rolls, step actions, reversals and other traversal. Rising, apex and descending all qualify; there is no falling-only gate. Velocity must approach the wall (dot >= .15); when collision has already stopped horizontal motion, explicit movement intent can qualify instead. Actual away velocity is never overridden by intent.

Detection uses a 160-degree TOTAL cone (+/-80), nine directional samples, a .75m maximum ray range and a small vertical sampling band. The normal-projectable ledge must be within +/- .30m of the expected hand-height band and require no more than .35m horizontal anchor adjustment. Local checks require a near-vertical face, upward top, two-hand width, unobstructed reach lines, and matching bracing wall at .80/1.15m below the lip. A standing capsule sweep/overlap query validates alignment, head and body clearance. Hand-valid lips without the bracing face are classified FREE_HANG_CANDIDATE and rejected; no Free Hang state exists. This deliberately compact query leaves the proven ground mantle detector untouched and reuses ground-support evaluation and the existing visual contact solver.

Anchor defaults: .50m outside the wall, 1.75m below the detected edge. The initial 1.90m offset left the wrists beyond safe reach; 1.75m lets the actual rig reach both targets without stretching. Momentum is zeroed immediately. Alignment eases over the tunable .20s settle; only then can a fresh E press request climb-up. Held E during catch does not skip settle or queue an immediate climb. Normal movement, gravity, dodge and crouch toggles cannot displace the hanging controller. Source movement/removal, lost contact geometry or a newly blocked body/path safely relinquish ownership. The same source/nearby edge is suppressed for 1s after release. Moving platforms are deliberately unsupported in this first pass.

Runtime clips: existing TRV_JUMPING_TO_BRACED_HANG (only its final .20s / six frame intervals), looping TRV_BRACED_HANG_IDLE, and non-looping TRV_BRACED_HANG_TO_CROUCH (35 frame intervals / 1.167s). AnimationTree states HangCatch, HangIdle and HangUp blend in at .12s. Private per-player animation copies cancel horizontal hip travel and compensate the scripted vertical rise; the catch tail is height-matched to idle, and top-out ends at the current crouch idle root height. Imported animations and GLB remain unchanged.

The existing single-pass MantleHandIK layer now accepts the active hang geometry without altering standard mantle timing or tuning. Fixed left/right edge targets use existing exposed spacing (.28/.25m), vertical/normal offsets (.03m), .45m correction cap and .995 reach limit. Settle ramps the clamp; idle holds it; top-out keeps support initially and releases over 45-70% of the clip, based on sampled source hand motion. Runtime sampling of the private top-out clip adds a vertical hand-center correction during support, fading away with release. This cancels source hand-height drift that otherwise exceeds safe arm reach; it does not pull the entire pose toward the wall or move the controller. Existing elbow safeguards and bounded wrist orientation remain. Ground pelvis/planting and ordinary environmental hands yield during hang. Foot contact reuses finite-surface penetration-only correction, .03m clearance, .15m cap and hang-only 50/s response; it preserves valid authored feet rather than pulling them unnecessarily into the wall. Hang-only position-space IK blending prevents a partial joint-rotation blend from arcing the toe into the wall. Standard foot/mantle IK tuning is unchanged. Wall protection lasts through 60% then fades by 75%; top contact takes over late in climb-up. All visual debug drawing is off by default; F3 shows the hang phase, anchor, classification and settle clock, while BracedHang.hang_debug adds hand diagnostics.

E climb-up checks source validity, supported top destination (.45m inward), crouched capsule clearance and an 80-segment swept path before committing. The controller rises before crossing the wall, uses the evaluated HangUp animation clock, and ends supported with crouch requested and the 1.1m capsule. A blocked destination leaves the player hanging. Live support/path checks and a bounded animation timeout prevent stuck ownership. The established camera stays on ordinary smooth follow; no mantle camera or cinematic redesign was introduced.

Playground: press 4 or walk south from the hub to the permanent modular hang_course.tscn. Thirteen named/labeled stations cover basic/rising/apex/falling/diagonal/cone-edge/behind/no-brace/low/medium/high/top-out/chain tests. Heights are 2.25/2.75/3.25m with broad 4m ledges. Approach timing selects the airborne catch phase; jump close for rising, early for falling. The chain adds a second 4.5m platform. Open space is reserved for future traversal. hang_detour.tscn provides optional jump/catch/top-out branches beside the Vertical and Mixed starts; Speed is unchanged. R resets any hang and Home returns to the hub; no gameplay drop exit was added.

Focused tests: test_braced_hang_v2 covers rising/apex/falling, 45/79-degree catches, 100/180-degree rejection, away motion, range/width rejection, settle lockout, stable anchor, bilateral idle wrist contact (<5mm), bounded arm lengths, toe clearance, hand release, persistent supported crouch, blocked top, moved source and no-brace classification. test_hang_playground_v2 checks permanent stations, supported reset and actual jump/catch/top-out on low/medium/high geometry, plus no-brace rejection. Both pass headlessly. In sampled idle, wrist error is effectively zero and toe-base clearance is approximately .047-.063m. The stricter climb-up support check stays below 1.3cm wrist error, and the worst measured solved toe penetration is about 5mm during the initial blend. Solved toes are captured inside the skeleton modifier pass rather than sampling Godot's subsequently restored authored pose.

Files: new player_braced_hang_v2.gd; integrations in player_v2.gd/.tscn, player_traversal_v2.gd, player_animation_v2.gd, player_debug_v2.gd, player_mantle_hand_ik_v2.gd, player_mantle_foot_contact_v2.gd, player_foot_ik_v2.gd, player_pelvis_ik_v2.gd and player_environment_hands_v2.gd. Playground adds hang_course.tscn and hang_detour.tscn and updates traversal_playground.gd/.tscn, vertical_course.tscn and mixed_course.tscn. New tests are test_braced_hang_v2.gd and test_hang_playground_v2.gd. The standard player_mantle_v2.gd and player_camera_v2.gd are unchanged. Verified source GLB SHA256 remains B3CC9744D338A87E6F7594E78ABAEB0F4F572F175684B1A2C2E7B8A5310DD8B9.

Regression validation: all 16 selected existing suites passed: climb_camera_entry, mantle_hands_height, climb_prompt_authority, mantle_geometry, crouch_handoff, sprint_jump_continuity, roll_traversal_windows, traversal_playground, environment_hand_isolation, ground_support, climb_penetration, held_climb, standing_idle_blends, stand_roll_timing, backstep_recovery and turn_arc. Final runs contain no script failures; the pre-existing headless certificate-store warning remains unrelated.

Play-test the catch-tail blend, diagonal settling, wrist/palm appearance, foot clearance and the top-out release before further animation polish. Automated transform/contact checks are not a substitute for subjective rendered animation review. Existing locomotion speeds, jump values, crouch BOW assignments, roll timing, standard mantle trajectory/contact settings and camera settings are preserved.

# Climb Camera Activation After Approach

The camera previously gated its climb anchor on mantle.pose_owned(), which includes committed ENTRY/alignment as well as ACTIVE animation. This captured the anchor where interaction was accepted, before the assisted approach finished, causing the camera to stay behind the moving player.

The gate is now mantle.running && traversal.phase == ACTIVE: the same authoritative phase in which AnimationController enters TRV_SPRINT_TO_WALL_CLIMB_02. ENTRY keeps the ordinary player-relative free-origin follow path. At ACTIVE the existing camera transition captures its anchor at launch; EXIT/completion still uses the original return path. No extra delay, camera framework, framing/offset/easing/rotation changes, or gameplay/IK/trajectory edits. Existing camera tracking/active fields remain available for inspection.

Changed player_camera_v2.gd and added test_climb_camera_entry_v2.gd. The focused test covers far stationary/moving press, held-E running approach, close entry, cancellation and dynamic blocking before animation, exact normal approach follow, matching animation/camera activation, bounded camera motion, unchanged yaw and completed return. Play-test far activation specifically: the camera should travel with the assisted approach before adopting the familiar climb framing at launch.

Final validation: climb_camera_entry, camera_distance, climb_prompt_authority and mantle all passed headlessly. The final camera-entry test resets held-input state between fixtures so cancellation cases genuinely begin an approach. No script/test errors in final runs; the existing unrelated certificate-store warning remains. Subjective framing should still be confirmed in play-testing.

# Mantle Hand Clamp and Phase-Aware Height Retarget

The controller was already height-aware: its trajectory ended at the validated landing. The implicit 2.54m vertical animation-compensation reference is now exposed as reference_climb_height rather than buried in prepare_clip. This is the existing compensation calibration, not a new measurement of a uniquely correct authored wall height. At commitment/preflight actual_climb_height=landing.y-alignment.y and vertical_retarget_offset=actual-reference. Horizontal flattening and private runtime clip ownership are unchanged.

Vertical position now uses the reference trajectory plus actual-minus-reference travel multiplied by a phase-aware weight. Weight is zero through frame 11, .05 by wall reach (17), .65 by hoist start (25), and 1 by frame 37, interpolated with smoothstep between markers. Thus most height difference is absorbed during reach/hoist rather than scaling the opening hop. Frame 50 still converges exactly to the original validated destination. The reference curve is used independently for authored hip compensation, so no per-climb correction accumulates in the animation. No character/skeleton scale, capsule change or animation-driven root motion. Supported height remains detector-owned 1.75-2.5m; no new out-of-range animation fallback. Typical actual/reference ratios are about .69-.99. Playback remains .88 and source starts remain moving=1 / stationary=10; no height-based duration change.

Added MantleHandIK to PlayerV2. It appends its prepare/native TwoBoneIK3D/capture modifiers to the existing single skeleton pass after the environmental arm layer; it never advances the skeleton again. Existing walk/wall-touch hand logic stays excluded during mantle and otherwise unchanged. The dedicated mantle layer is disabled outside ACTIVE and releases before frame-51 landing handoff. No spine/body override or new gameplay movement.

Grip points are captured once per climb from validated ledge_edge, top plane, wall normal and facing-derived tangent, not the reference animation's world height. Left/right lateral spacing defaults -.28m / +.25m, guided by sampled authored frame-24 wrist spacing (~-.33 / +.23). Wrist targets use +.03m vertical and +.03m outward offsets at the true edge; a local ray per grip at capture verifies finite top surface on the same collider. Invalid grips are not acquired and do not alter gameplay validation. Targets do not slide or get resampled every frame.

Hand influence smoothsteps 17-23 from zero to full, stays full through 37 (including requested 24-37 clamp), then releases 37-44. Blending occurs in position space toward fixed targets, with native solver influence active only when needed; no exponential lag during the full clamp. ik_blend_speed=25/s smooths conservative elbow guidance, retaining authored bend direction and preventing side flips. max_hand_correction_distance=.45m and .995 chain reach limit impossible poses; safety can leave contact error rather than stretching. Hand orientation is mild: hand_orientation_weight=.35 with maximum requested angular correction 45 degrees, favoring a palm-down ledge relationship while retaining most authored wrist pose. Fingers are not individually posed; targets are wrist-based, not exact fingertip grips.

Exposed height tuning: reference_climb_height=2.54, reach_height_difference_weight=.05, hoist_height_difference_weight=.65, height_difference_full_frame=37. Hand tuning: start/full/release/release-end=17/23/37/44, separate grip spacing, vertical/normal offsets, correction limit, elbow blend speed and orientation controls. Existing climb debug includes actual/reference height, delta/ratio, phase weight, current target and each hand's weight/error/limited status; cyan/magenta grip markers remain debug-only, off by default.

Changed player_mantle_v2.gd, player_v2.tscn, added player_mantle_hand_ik_v2.gd and test_mantle_hands_height_v2.gd, and these notes. Foot penetration code and its caps/windows are unchanged. Visual acceptance still requires play-testing at different heights: wrist attachment through 24-37, elbow behavior, modest wrist orientation, release after 37 and the revised hop/hoist height. The .15m foot-correction safety limit still permits residual deep clipping; this pass does not expand it or create full-body IK.

Validation: final runs of 17 suites passed: mantle_hands_height (moving/stationary at 1.75/2.1/2.5m; 2m-wide rotated ledge versus standard 3m; stable grips, no elbow flip, unchanged chain length, exact endpoint and phase-weight delta), climb_launch, climb_penetration, climb_polish, climb_prompt_authority, held_climb, mantle, environment_hand_isolation, ground_support, sprint_jump_continuity, roll_traversal_windows, crouch_handoff, run_roll_handoff, sprint_roll, stand_roll_timing, backstep_recovery and traversal_playground. Measured full-clamp wrist error was at most ~1.1mm in these fixtures. An initial 1.2m-wide rotated fixture did not pass climb validation; validation was left untouched and a valid narrower fixture used for hand coverage. No final script/test errors; existing unrelated certificate-store warning remains. Source GLB SHA-256 remains unchanged. Bone-target accuracy is not a substitute for visual palm/finger acceptance.

# Minimal Climb Foot Penetration Prevention

The launch/contact trajectory is retained. This pass only changes the existing visual foot-contact helper and its native TwoBoneIK3D target preparation. The old wall helper could attract a valid foot to the wall with phase-only weight and up to .30m displacement; it is now penetration-only, with a .15m cap and no foot rotation changes. No body/capsule, mantle path, geometry validation, support, hand IK, or source GLB changes.

Wall: measure negative signed distance of the restored animated ankle/toe against the validated wall plane. Only penetrating samples create a target, displaced outward by depth plus .02m clearance, capped at .15m. No negative/pull-in offsets. A short .10m ray across the projected point confirms the same collider/normal exists there; it does not search for another wall. Source-frame envelope fades in 10-15, holds through 30, fades out 30-40. Earlier permission is safe because valid animated positions never request wall IK.

Ledge top: use the validated top plane/normal and sample both the existing .08m ankle-to-sole estimate and authored toe. A short local ray confirms finite top support under each penetrating sample on the same collider, avoiding an infinite-plane lift outside the ledge. Lift only along the top normal, with .02m clearance / .15m cap. Gate using normalized progress through the existing hoist: .60-.80 fade-in (current frames 40-45); correction remains conditional on penetration until the existing frame-51 gameplay handoff. Normal ground IK then resumes through its existing path. Clip sampling showed toe penetration mainly at 47-50, after crossing over the edge. Top contact takes priority if both envelopes are configured to overlap.

Tuning on FootIKController: existing climb_foot_wall_offset=.02, climb_foot_max_correction=.15, climb_foot_blend_in_start/end=10/15, blend_out_start/end=30/40; new wall_ik_blend_speed=25/s, top_surface_clearance=.02, max_top_foot_correction=.15, top_ik_blend_speed=25/s, top_foot_phase_start/full=.60/.80, climb_penetration_full_weight_depth=.02. Strength remains 1. Removed the obsolete broad wall projection-distance export. Influence uses smoothstep from zero to .02m penetration multiplied by phase/strength; target offset and influence each exponentially smooth on activation/release. No world-space foot lock is introduced.

Safety: cap displacement, reduce normal-only offsets to remain within .995 chain reach, reject unsafe/near-zero solutions or lateral crossing, preserve authored ankle orientation and existing knee poles. Recheck reach after target smoothing as animation changes; fall back to the authored target rather than redirecting or stretching the chain. Deep penetration is intentionally only partially corrected. Sampling the moving clip found approximately .48m early right-foot wall penetration around frames 13-15: the .15m cap cannot fully remove it, and this task does not retune trajectory or distort the body to compensate. Bone/sole samples are approximations, not a skinned-mesh collision solver; smooth blend and safety fallback can leave residual clipping.

Debug is off by default. Existing climb-foot overlay now labels WALL / LEDGE_TOP / NONE, raw penetration, current correction, influence and limited status; it draws animated feet, targets and the tested plane normal. Changed player_mantle_foot_contact_v2.gd, player_foot_ik_v2.gd, added test_climb_penetration_v2.gd, updated prior launch/polish test expectations for the new intentional timing/cap, and these notes. The prior .50/.75/.65 contact/launch settings and all gameplay tuning remain unchanged.

Validation: 15 final headless suites passed: climb_penetration, climb_launch, climb_polish, climb_prompt_authority, held_climb, mantle, ground_support, sprint_jump_continuity, roll_traversal_windows, crouch_handoff, run_roll_handoff, sprint_roll, stand_roll_timing, backstep_recovery, traversal_playground. Penetration coverage includes moving/stationary starts at 1.75/2.1/2.5m heights, a 15-degree rotated wall, finite-top rejection, clear samples left alone, smooth release, normal-only/capped targets, preserved knee bend/chain lengths, both-surface improvement and unchanged collision-controlled trajectories/landings. Source GLB hash is unchanged. Final runs have no script/test failures; the existing unrelated root-certificate-store warning remains. In-editor visual acceptance is still required, especially residual early right-foot clipping and the top/ground-IK handoff around frames 47-51.

# Climb Launch / Wall Contact Separation

`TRV_SPRINT_TO_WALL_CLIMB_02` previously started at the .50m wall-contact centerline distance, leaving only .05m outside the .45m capsule. Launch and contact are now separate so the opening hop has space without shifting the subsequent hoist away from the wall.

Mantle exports: moving_climb_launch_distance=.75m, stationary_climb_launch_distance=.65m, wall_contact_distance=.50m, launch_contact_frame=17. Source starts remain frame 1 moving / frame 10 stationary at 30 FPS and .88 playback. Entry type is chosen from the existing .75m/s speed threshold during preflight and commitment, not changed by assisted-approach speed. Acquisition remains 2.5m. The swept, ground-supported approach now ends at launch. Starting closer than launch causes a small validated outward alignment; no teleport or unsupported fallback is allowed.

During ACTIVE, smoothstep over source frames 1-17 moving or 10-17 stationary removes the horizontal launch offset. This takes about .606s moving / .265s stationary at .88 playback, with zero interpolation velocity at the endpoints. Frame 17 reaches the original contact relationship without snapping. The original vertical profile and frame-25 onward hoist/Bezier path are unchanged. Preflight checks the added opening path; runtime still uses collision-checked CharacterBody motion. Private animation-copy horizontal flattening and vertical compensation are unchanged; source GLB, capsule, landing setback/height/support and movement values are untouched.

Wall foot IK now fades in over frames 16-21, remains full through 30 and fades out by 40. Existing reachability, maximum .30m correction, exponential smoothing and visual-only authority remain. Ground IK influence can finish fading on entry, but wall-contact projection is disabled before 16. Expected visual hand/ledge contact is frames 17-21, with WALL_REACH at 17 and hoist at 25. This is a visual expectation, not a new hand pin or measured guarantee; environmental hand IK remains excluded during mantle.

Debug remains off by default. Mantle debug adds current wall distance, selected launch/contact values, source timing and normalized phase; cyan launch, magenta contact, green landing and white wall-normal markers supplement existing detector/candidate visualization. Changed player_mantle_v2.gd, player_ledge_detector_v2.gd, player_foot_ik_v2.gd, added test_climb_launch_v2.gd and this note.

The launch test covers moving/stationary, near/far activation, exact animation launch distance, smooth monotonic gap closure, source-frame 17 contact, no early wall projection, unchanged hoist path and successful landing. Visual hand alignment, the subjective hop/read and any remaining mesh penetration require in-editor play-testing; no hand-IK expansion or contact-distance retune is included.

Validation: all 14 headless tests passed: climb_launch, climb_prompt_authority, held_climb, climb_polish, mantle, ground_support (including coyote/slopes), sprint_jump_continuity, roll_traversal_windows, crouch_handoff, run_roll_handoff, sprint_roll, stand_roll_timing, backstep_recovery and traversal_playground. No script/test failures in the final runs; the existing Windows root-certificate-store warning remains unrelated. Source GLB SHA-256 matches the committed baseline. Automated checks do not certify visible palm alignment or subjective animation quality.

# Backstep Recovery Momentum and Input Exit

The active imported backstep is `DPD_DODING_BACK` (user referred to it as DOD_DODING_BACK); its runtime source-frame slice remains 15–60. The previous movement curve reached zero at normalized .6, approximately source frame 42, even though authored backward hip travel continues after 47.

Preserved the initial tuned push through source frame 36. Frames 36–42 blend toward sampled authored backward hip velocity; the recovery then follows that profile rather than remaining stationary. Source local -Y travel is converted from centimeters to meters before runtime animation normalization/slicing; it remains collision-controlled movement along the captured backstep direction, not root-motion authority. Strength is 1.0, scaled relative to the unchanged 5m/s backstep-speed setting and playback rate. Frames 57–60 smoothly settle the small remaining velocity to zero at the existing clip endpoint. GLB/source animation and curve resource are untouched.

New backstep exports: input_exit_frame=50, exit_blend=.30s, recovery_motion_start_frame=36, recovery_motion_full_frame=42, settle_start_frame=57, recovery_motion_strength=1.0. Current movement input above .01 at source frame 50 or any later frame triggers the same single control-return mechanism as standing roll and a .30s locomotion blend. No input keeps the action playing to source frame 60. Input before 50 cannot exit early. Source-frame conversion explicitly adds the runtime slice's 15-frame origin, so 50 means original clip frame 50, not 50 frames after the cut.

Changed player_dodge_v2.gd, player_animation_v2.gd, added test_backstep_recovery_v2.gd and this document. Standing/running/sprint roll settings are unchanged. The focused backstep test verifies the original initial push, continued movement after 47, held-input exit at 50, late-input exit at 55, no-input finish/zero velocity at 60, source timing at .85/1/1.15 playback speeds, current-direction control and the .30s exit blend. Standing-roll timing, running handoff, sprint roll, roll traversal and idle-blend regressions also pass. Playtest the recovery travel after 47 and the input exit at 50; recovery strength is available for small feel adjustments.

# Standing Roll Authored Lead-In

Supersedes the zero-momentum-before-21 rule below. DOD_STAND_TO_ROLL now uses a reduced, animation-derived forward lead-in from frame 10. Before runtime horizontal normalization, `prepare_stand_leadin` samples the original hip track's forward velocity (rig local +Y, centimeters converted to meters) at source-frame times. Motion uses 65% of this profile, bounded by the existing roll curve, then smoothly blends into the unchanged curve over frames 19–21. New tunables: stand_roll_leadin_strength=.65 and stand_roll_leadin_blend_frames=2. The cached profile survives the motor's per-instance resource duplication. The GLB/source track itself is untouched.

Frame 10 playback start, frame 55 current-input exit, .30s exit blend, full no-input completion and all movement from frame 21 onward remain unchanged. Forward displacement stays under the existing collision-authoritative motor; authored sideways hip sway is not turned into sideways gameplay drift. Running/sprinting rolls and backstep are unchanged. The existing stepper window stays at source frames 20–40; frame 20 can now have enough lead-in momentum to qualify.

Changed player_dodge_v2.gd, player_animation_v2.gd, standing-roll timing and window tests, and this document. Tests check animation-derived early speeds, unchanged post-21 curve, held/late/no-input exits at .85/1/1.15 playback rates, roll traversal windows, traversal/drop/stair safety and running/sprint roll regressions. Inspect the character's lean and forward pickup before 21 during playtesting; adjust lead-in strength if it needs less or more anticipation travel.

# Stand/Walk Roll Timing Refinement

Only DOD_STAND_TO_ROLL is retimed. New dodge exports: stand_roll_start_frame=10, stand_roll_momentum_start_frame=21, stand_roll_input_exit_frame=55, stand_roll_exit_blend=.30s. Stand no-input exit_progress is now 1.0 (previously .95), allowing the complete source finish (frame 72 at verified 30fps). Running/sprinting roll and backstep configuration are unchanged.

The AnimationTree action starts at source frame 10 via a runtime start offset divided by playback speed; the imported/private source clip is not sliced or modified. `dodge.evaluate` includes that offset in its source-clock elapsed/progress values, preserving original movement-curve sampling and the existing stand/walk stepper window of source frames 20–40. Horizontal roll velocity is zero before source frame 21; from 21 onward the original curve is sampled unchanged, including its ending deceleration/zero section. The stepper cannot begin a moving lift at frame 20 while momentum is zero.

At the first motor tick after evaluated source frame 55 (or any later frame), current movement input above .01 returns control and starts the .30s standing-roll-only locomotion blend. This uses the current stick, not the captured starting direction. With no input, ownership continues until source completion; new input after 55 can still exit. Existing accepted traversal lifts finish safely before an input handoff. Normal locomotion/airborne rules own movement after control returns; no running-roll-style extra recovery state was added. Starting/holding input before 55 cannot cut the clip early.

Files: player_dodge_v2.gd, player_v2.gd (passes current stick into the existing timer update), player_animation_v2.gd (runtime offset/stand-specific exit blend), new test_stand_roll_timing_v2.gd, updated roll traversal/window tests and this document. Curve resources, GLB and other gait/climb tuning are unchanged. The stand stair test now expects a shorter assisted traversal, not the original full-stair distance: the delayed momentum and frame-55 input handoff intentionally reduce its travel. The running-roll full-stair assertion remains intact.

Validation: source start=10, zero momentum before 21, unchanged curve afterward, handoff at 55 with held input, late input at 60, and no-input completion at 72, at .85/1.0/1.15 playback rates. Current-direction control and .30s transition verified. Running handoff, sprint roll, stepper source windows, roll traversal/drop/stair safety, standing-idle blends and RUN-jump reset suites pass. Playtest the launch at frame 21 and the moving exit blend at 55; source timing uses the project's existing frame/30 convention.

# Authoritative Climb Prompt + Assisted Approach

Visible climb prompt is authoritative: if the prompt is shown, climb input will be accepted.

This supersedes the previous awareness-only prompt and closer physical-entry rule. The single acquisition range remains 2.50m, but LedgeDetector now runs full Mantle.validate preflight before publishing an available candidate: valid wall/top/height/slope/depth, standing clearance, destination volume and support footprint, complete swept capsule approach, approach support samples every <=10cm, and all 80 existing mantle trajectory segments. Invalid geometry, approach obstructions, unsupported gaps, angle/range or state eligibility suppress the prompt. Activation refreshes/revalidates for genuine last-moment safety changes, not another proximity gate.

Removed the former .95m physical-entry check, .55m alignment-distance rejection, and detector exports mantle_forward_check_distance / mantle_max_reach_distance / mantle_acquisition_extension. The remaining 2.5m acquisition checks all refer to the same prompt range. Internal distance determines presentation and duration only, never refusal of an otherwise validated prompt.

Mantle ENTRY owns assisted movement and ignores ordinary steering, retaining existing ENTRY Jump/Dodge/interrupt cancellation. Near-wall alignment keeps its .12–.25s behavior. New Mantle exports: mantle_approach_speed=4.5m/s (smoothstep peak speed), mantle_long_approach_distance=.55m (presentation threshold, NOT an activation gate). Longer pull-in duration is max(.25s, 1.5*distance/speed); a 2.5m wall distance means roughly 2m travel in .67s to the original animation start. Position/yaw use smoothstep with swept move_and_collide, no teleport. Long ENTRY feeds assisted speed into existing idle/walk/run animation blends; the same _02 climb clip and source-frame entry rules begin after alignment. Gameplay run buildup is not accumulated by the visual approach.

Commitment captures alignment/landing rather than rechecking player angle or steering every tick. Actual source loss/movement, capsule collision, missing approach support, blocked destination or lost destination support still abort safely. Landing support is rechecked with the same existing footprint and captured top normal during the longer committed sequence. No support-probe rules, coyote timing, capsule dimensions, climb height (2.50m), arc, IK settings, camera, source GLB, normal movement values or RUN-jump reset changed.

Held E consumes the validated prompt immediately, including at the far edge. Consumption/next-ledge travel safeguards remain; while a continuing hold is not eligible to rearm, that climb prompt is hidden too, avoiding another visible-but-unavailable condition. Generic interactions stay fresh-press-only. The old failed-entry retry cache was removed because published climb candidates now include full preflight. Safety invalidation may still cancel an interaction if the environment changes after the prompt was sampled; it cannot responsibly guarantee success through a newly appearing wall.

Changed: player_ledge_detector_v2.gd (preprompt preflight and removed closer gates), player_mantle_v2.gd (assisted approach and live safety), player_context_interaction_v2.gd (consume executable candidate/consistent prompt), player_animation_v2.gd (moving approach presentation), updated held-climb/climb-polish tests, new test_climb_prompt_authority_v2.gd, README and DEV_NOTES. player_v2.gd RUN-jump rule is untouched in this pass.

Tests: new authority suite verifies .55/.95/1.5/2.45/2.49m visible prompts all accept and complete, no movement on the acceptance call, per-tick pull-in speed bounds, moving locomotion pose during long ENTRY, steering suppression, no-prompt rejection, valid-wall-but-blocked-approach hiding, prompt recovery, angle invalidation, newly introduced collision interruption, lost destination support interruption and pit rejection. Existing held-input tests now assert immediate far commitment rather than the superseded manual-approach expectation. Climb maximum/geometry, sprint/RUN jump, support/coyote/steps, roll/drop, crouch, idle transitions, camera, hand isolation and playground tests pass. Visual footwork still needs human playtesting; animated movement/speed bounds are verified, not a claim of perfectly locked feet.

Playtest the pull-in from rest and while running near the full 2.5m range, especially footwork and the handoff into the climb clip. Hold E through completion to check rearming, and inspect near-wall alignment for unchanged feel. The playground remains the F5 main scene.

# Held Climb Awareness + RUN Jump Buildup Refinement

This section supersedes the prior RUN-jump preservation rule, not the broader airborne intent architecture. Authoritative timer remains `player_v2.gd::_run_time`. At the motor's confirmed `jump_started` boundary (after roll veto), if the source gait is RUN, set it to zero and clear the running-turn captured buildup. `_update_sprint_buildup` still freezes it in air, resumes earning on grounded movement, and preserves already-active SPRINT jumps. Merely becoming airborne or pressing jump when no jump can start does not invoke this reset. Shift/movement release, crouch, lock-on, running-roll and mantle cancellation remain. No speed, gravity, air-control, animation or support tuning changed.

LedgeDetector's new exported `mantle_acquisition_distance=2.5` meters replaces the previous effective .95m forward awareness (an increase of 1.55m). The minimum/maximum heights remain 1.75/2.50m. Detection still validates the actual face, top, depth, slope and standing destination volume. ContextInteraction uses the detector's range for its systemic climb candidate only; unrelated interaction range remains 2m.

Physical entry is deliberately separate: `physical_entry_distance()` remains .95m from the original .75m forward/.90m reach settings plus .20m extension. The legacy `mantle_acquisition_extension` now explicitly documents its physical-entry-only role. Alignment displacement cap stays .55m; existing .12–.25s swept alignment, standing clearance, ground-support destination check, full trajectory preflight and per-tick collision/source checks remain. `mantle.validate` rejects OUTSIDE_PHYSICAL_ENTRY even for direct calls. A far prompt does not move the player or initiate a several-meter approach: move toward the obstacle while holding E; the short existing alignment starts only when eligible.

Input uses both just-pressed and held E through the existing ContextInteraction tick. Held E arms only the systemic geometry climb, not generic/other interactions. A successful start consumes the collider/top-height/face identity. Keeping E held through entry, active climb, exit and standing still cannot start it again. A different ledge can use the same hold only after at least .50m of normal horizontal travel following traversal exit and renewed movement intent. Fresh release clears intent. Failed preflight is attempted once per physical entry/ledge, with retries only after .10m movement, leaving/re-entering physical eligibility or a fresh press, not every physics frame. The candidate's full refresh/validation still runs on activation. Generic interactions retain discrete fresh-press behavior.

Existing debug shows awareness (cyan) versus physical-entry reach (orange), current entry eligibility and held/consumed status. No new traversal state, auto-walk, input timing minigame or IK system was added.

Changed: player_v2.gd, player_ledge_detector_v2.gd, player_mantle_v2.gd, player_context_interaction_v2.gd; added test_held_climb_v2.gd; updated sprint continuity, climb polish and playground tests to the revised rules, playground README and DEV_NOTES. No GLB, geometry, collision capsule, support/coyote, camera or climb foot-IK changes.

Focused tests cover early awareness at walking/running speeds, holding before awareness, pressing after awareness, stationary far no-teleport/direct-call rejection, physical entry gating, single start throughout held completion, legitimate next-ledge rearming, generic interaction isolation/fresh press, invalid 2.75m walls, RUN takeoff reset from partial/nearly-full buildup, repeated jumps, uninterrupted running to Sprint, and active-Sprint preservation. Updated prior tests now assert the corrected RUN reset rule, rather than preserving their superseded expectations.

Results: all 14 focused suites passed (held climb, sprint continuity, climb polish, mantle, mantle geometry, ground support, playground, traversal phase 0, crouch handoff, running-roll handoff, roll traversal, sprint roll, standing-idle blends and turn arc). No test script errors; unrelated engine certificate-store warning persists. One climb-polish run also emitted a transient Jolt job-capacity warning; its final rerun passed.

Playtest: run toward a 2.4m face while holding E before the prompt; expect early notice followed by the same short collision-swept entry. Keep E held across completion to check for accidental chaining, then walk toward a distinct next obstacle. Check RUN buildup hits 0% exactly on takeoff while SPRINT jumps remain Sprint. Playground remains the F5 main scene.

# Sprint Jump Continuity + Modular Traversal Playground

The inspected V2 motor was adding `_run_time` during airborne movement, rather than explicitly separating accumulation from preservation. There was no jump-entry reset to remove in the current source. The new `player_v2.gd::_update_sprint_buildup` is the authoritative gait/timer update: grounded moving Free locomotion with Shift earns progress; the takeoff tick and airborne ticks retain exactly the existing value; the next eligible grounded tick resumes accumulation. Jumping never completes the buildup by itself. An already active sprint remains active through an ordinary jump. Speeds, gravity, air control and the 4-second buildup duration are unchanged.

Shift release or movement-input release clears progress immediately, including in air; pressing Shift again in air cannot recover cancelled progress or earn new progress. Lock-on, crouch and mantle keep their existing resets. Running-roll entry still resets and roll ownership freezes accumulation; sprint-roll behavior stays intact. Existing running 180 turns preserve their committed momentum/state rather than being a new cancellation; if intent is explicitly released during one, its captured buildup is cleared too so it cannot restore cancelled sprint later. No new wall-blocked/stun/damage system or timer was introduced. Existing traversal interruption owners retain authority.

New scene: `res://test/traversal_playground/traversal_playground.tscn` (open + F6). Main scene and the old lab remain unchanged. Three individually editable PackedScenes branch from an 18m hub: Vertical north (12.15m attainable top followed by a +2.75m impossible face), Speed east (about 100m, repeated 1.0–1.8m gaps, raised platforms, roll-height obstacles and a climb), Mixed west (direction changes, steps, roll/jump/climb faces, post-climb gap, narrow support beam and drops). Local -Z is each module's extension direction. Ordinary saved mesh/collision nodes, names, metadata and Label3D signs expose dimensions; no runtime geometry framework is required. Representative relative heights: .30/.35/.65/.75/1.50/1.70/2.00/2.40/2.50m, plus intentionally invalid 2.75m. A .30m approach-step bypass keeps the 1.70m jump boundary from blocking the upper climb tests. Roll-height faces permit jump alternatives; no artificial roll-only gate was added.

Scene-local controls: 1/2/3 select and reset Vertical/Speed/Mixed; R restarts the current course; Home returns to hub. Walking into a branch selects its start. Falling below Y=-6 resets. Reset replaces the complete player instance for clean action/animation/IK/coyote state, including during committed mantle. This exposed a lifecycle callback after removal: `player_foot_ik_v2.gd::_exit_tree` now disconnects its two pose signals before restoring the skeleton callback mode. No contact solving, climb IK tuning or support-footprint behavior changed.

Files: modified player_v2.gd, player_foot_ik_v2.gd and DEV_NOTES.md; added test/traversal_playground/{traversal_playground.tscn,traversal_playground.gd,vertical_course.tscn,speed_course.tscn,mixed_course.tscn,README.md}, test_sprint_jump_continuity_v2.gd and test_traversal_playground_v2.gd. README contains launch, reset and module-extension instructions. Source GLB and tuned movement values remain untouched.

Verification: sprint continuity at 60% progress, repeated jump/land cycles eventually activating sprint, active-sprint jump, near-full takeoff not promoting, airborne release/repress/stop cancellation, crouch and running-roll cancellation, mantle cancellation/completion. Playground tests exercise safe spawns and fall reset for all routes, committed-climb reset, visible/collision dimensions, actual .30 step/.35 jump/.65 roll/.75 jump/1.50 jump/1.70 bypass, actual 2/2.4/2.5m climbs and 2.75m rejection, three successive real speed-course gaps with preserved buildup and subsequent sprint activation.

Fourteen focused V2 suites passed: sprint continuity, playground, ground support, climb polish, mantle, crouch handoff/continuity, running-roll handoff, sprint roll, roll traversal (including drops), standing idle blends, camera distance, environment hand isolation, and turn arc. An additional old `test_gait_jump_selection_005a2.gd` could not run: it targets the legacy non-V2 player and errors in player/player_animation_controller.gd plus a null node lookup; those untouched legacy files were not changed. Engine root-certificate warning persists. Full mixed-route human-speed playthrough and visual review remain playtesting tasks, not claimed automated coverage.

# Climb Acquisition, Height and Visual Wall-Foot Polish

Focused pass: player_ledge_detector_v2.gd, player_mantle_v2.gd, player_foot_ik_v2.gd, new player_mantle_foot_contact_v2.gd, test_climb_polish_v2.gd, test_mantle_v2.gd, mantle_test_zone_v2.gd and this document. Source GLB, hands, body capsule, support footprint/coyote, gameplay trajectory, camera and locomotion tuning are unchanged.

Authoritative detector exports (TraversalController/LedgeDetector): mantle_max_height is now 2.50m; minimum stays 1.75m, with the existing 5mm detection tolerance. No scene overrides. mantle_acquisition_extension defaults to .20m (0–.25), added to the existing .75m forward acquisition probe: .95m effective straight-on range. The existing .90m reach sanity gate also includes this extension. These are acquisition checks, not permission to execute remotely. E still refreshes geometry and performs the complete support, standing clearance, approach sweep and 80-segment trajectory preflight. The separate execution alignment displacement cap is the original .35m plus the extension (.55m default). Alignment uses the original .12s minimum, extended by distance/2 up to .25s; the clip starts only after swept alignment succeeds. All existing per-tick source and collision checks remain.

Wall IK settings are on FootIKController under Climb Wall Foot Contact: enabled=true, wall offset .04m, projection distance .40m, max correction .30m, strength 1.0; source-frame smoothstep fade-in 12–18, fade-out 30–40 (30fps source). Targets and influence additionally smooth at 20/s. climb_foot_debug=false by default. Debug geometry shows yellow animated source, green/red valid/invalid target, cyan hit normal, and a vertical target bar proportional to weight; F8 foot debug text reports contact validity/weight.

The small contact helper projects the deeper animated ankle/toe sample toward the already validated wall, checks the actual hit belongs to that wall and has a compatible normal, then offsets the native TwoBoneIK3D target. It reuses the existing leg modifiers, authored knee poles and ankle orientation, not a second solver. Corrections are normal-only (no lateral leg crossing), bounded and reach-checked. Planting is released during mantle. Normal ground IK/pelvis eligibility remains unchanged; this helper never writes the body, root, collision, animation source or support state. Invalid contacts fade away. No hand changes.

Automated headless validation: climb polish acquisition/activation revalidation, gradual approach, natural walking approach, invalid remote/high ledges, 1.75/2.0/2.4/2.5m completion with varied depths, bounded/native IK and unchanged trajectory; expanded mantle audit accepts 2.5m and rejects 2.6m. Strong-contact ankle/toe penetration sum drops about 67% in sampled fixtures; maximum native chain-length error is about .000011m. Ground-support, mantle geometry, crouch continuity/handoff, running-roll handoff, environment hand isolation, camera distance, standing-idle blending and phase-0 traversal suites pass. Ground-support suite covers edges/coyote, narrow supports, 15/30/40-degree slopes, 10/15/20cm steps and wall blocking. Older broad step/player suites have pre-existing outdated movement expectations; this is not a claim that every legacy suite is green.

Additional regression passes: roll traversal (including roll-off drops and stairs), roll traversal frame windows, and sprint roll. Fourteen focused headless suites passed in total; the unrelated engine certificate-store startup warning remains.

Play-test from walking distance and view both feet side-on at 1.75–2.5m, especially contact onset and release. This is bounded visual polish, not perfect foot locking: residual penetration during blending/unreachable poses remains, and ankle rotation stays authored to avoid twisting the rig. No rendered visual approval is claimed by headless tests. A later hand-contact pass could reuse the known-wall projection pattern, but is outside this change.

# Standing Idle Transition Smoothing

Standing idle remains IDL_IDLE_A_RAW. Animation-only pass: player_animation_v2.gd, player_grounded_animation_v2.gd, new test/test_standing_idle_blends_v2.gd and this document. No motor speeds, action completion frames, physics/IK, camera or source clips changed.

Default Walk→Idle gait blend increases .20→.30s. Locked movement→Idle increases .15→.30s and retains its existing smoothstep interpolation. New AnimationController/Standing Idle Blending/standing_idle_return_blend=.30s is a minimum crossfade for actual idle-bound returns (input <=.01 and horizontal speed <=.10). Root action returns cover landing, passive fall/air recovery, dodge/backstep/roll, crouch posture returns and mantle. It is applied after action/crouch overrides, preserving any longer source-specific blend. Root baseline is restored on each subsequent moving return so a prior idle transition cannot leak its longer duration into movement.

Nested locomotion returns from RunStop, turn-in-place, WalkPivot/RunPivot and lock-mode changes receive the same minimum when stationary. Moving returns retain existing locomotion/lock durations. Ordinary state transitions retain AnimationTree's standard crossfade method, matching crouch; no new easing resource or startup delay is introduced. Idle→movement and all action-entry timing remain untouched. Run/Sprint stopping still uses existing stop/gait logic before the final idle blend; it is not forcibly shortened to fit .30s total.

New automated audit confirms all root source routes have a >=.30s idle transition and an actual outgoing blend at .10s; moving landing/air returns restore their old duration; nested stop/turn/lock returns receive the minimum; Walk→Idle reaches half weight at .15s and completes around .30s. Crouch modifier and crouch continuity regressions pass. Visual softness still requires user play-testing.

# Player Ground Support Footprint

Standing BODY capsule remains radius .45m / height 1.80m; crouch remains height 1.10m with the same radius. Collision layers/masks, broad wall clearance and slide sweeps are unchanged. New PlayerV2/GroundSupportProbe defines gameplay support separately.

Inspection: motor jump eligibility, gravity/gait decisions and published grounded/airborne state previously used is_on_floor() (plus active StepSolver). Traversal eligibility, crouch entry/motion, StepSolver initiation and roll stepping also used physical floor contact. Animation, hands, FootGrounding, FootIK and pelvis mostly read the published state. There was no explicit jump coyote timer; animation's passive-air grace was presentation, not jump forgiveness.

New support defaults: radius .22m; five rays (center + four corner points at ±radius/sqrt(2), yaw-aligned with the character); start .04m above support plane and end .12m below it; required fraction .60; full fraction .80. Five/four hits = FULL_SUPPORT, three = EDGE_SUPPORT, zero/two = UNSUPPORTED. Inspector allows fraction/radius/cast tuning. Normal is averaged from walkable hits. During physical slope contact, the probe plane accounts for the rounded capsule tangent-plane height and floor incline so short casts do not falsely reject slopes. It does not change the body's floor normal.

has_ground_support requires sufficient footprint hits, no active jumping-away latch, and physical floor contact or confirmed solver support. Physical contact gates acquisition so a falling body is not declared landed merely because ground lies within the .12m probe reach. Broad is_on_floor alone is NEVER sufficient. The raw fraction remains independently queryable for candidate poses. A rising jump cannot repeatedly recharge support from nearby ground.

Support evaluates after move_and_slide and both step correction finish calls. Verified active StepSolver/roll correction temporarily retains gameplay grounding; this is explicit solver ownership, not a coyote timer hiding missing geometry. Those solvers retain their own physical contact and terrain-validation rules. Ordinary gravity/jump/gait logic now consumes footprint support or confirmed correction. Unsupported movement temporarily disables floor snapping and floor_stop_on_slope during the slide, then restores the saved settings. This lets gravity slide the broad rounded capsule off an edge instead of keeping it perched; there is no forced horizontal/backward displacement, teleport, collider shrink or collision exclusion.

Explicit coyote duration .12s: support true→false emits support_lost and exposes support_just_lost for that motor tick. The timer counts down on subsequent ticks, permits one jump, and resets on regained support, jump or traversal ownership. Crouch and dodge continue to veto incompatible jumps. No extra air jump or ledge-grab behavior was added.

Physical is_on_floor remains in StepSolver, roll step initiation, crouch physical transition safety and traversal eligibility (also gated by published airborne state). Motor exposes physical_ground_contact() for existing FootGrounding/FootIK/pelvis terrain eligibility: these retain individual probes and do not globally switch off solely because the gameplay footprint is marginal. Jump/dodge/mantle suppression remains. Animation and environmental hands consume the gameplay airborne state. Roll presentation remains authoritative across support loss, and resolves airborne normally at exit.

Mantle uses support-sized top sampling but retains minimum top depth .55m, walkable/same-source checks and FULL BODY volume/sweeps. Its endpoint requires support fraction >=.60, not a full .45m-radius footprint. Radius-based old minimum .48m is replaced by a layout/threshold calculation: for a flat straight ledge with aligned five-point footprint at 3/5, theoretical minimum is .015m (center margin); requested .15m is valid and selected. This is a 33cm reduction from the previous .48m effective endpoint. Layout thresholds above 3/5 raise the calculated minimum. Final candidate-specific footprint and broad-body checks still decide acceptance. Legacy detector mantle_top_setback is no longer an Inspector control; Mantle Exit owns requested setback. Existing .88 playback, arc, .30 exit fade and camera consume the updated endpoint without timing changes.

Focused test_ground_support_v2 passes: 5/5 flat; 3/5 edge; loss before broad contact disappears; successful one-shot coyote jump; expired rejection; natural unsupported fall; .50m beam supports unchanged .90m-wide body; .15m beam rejects; crouch same footprint; 15/30/40-degree slopes; 10/15/20cm steps without airborne flicker; unchanged wall block; narrow .50m mantle completes and .15m top rejects. test_mantle_v2 passes at 1.75/2.0/2.2m with .15m setback, supported settled feet, no idle drift, camera continuity and frame-51 handoff. Roll-off-edge, crouch modifier, environmental-hand isolation and mantle geometry suites pass.

Historical test_step_solver_v2 still has old speed/distance/curb assertions that fail identically when the pre-support motor is substituted: this pass did not claim that entire legacy suite passes. The focused current-speed step checks above pass, and its pre-existing no-air-flicker assertions do not regress. The older general test_player_v2 likewise contains a 4m/s Walk expectation, inconsistent with preserved 2m/s tuning; it is not a clean acceptance suite for current locomotion.

Lab: GroundSupportTestZone at (150,0,-10), with broad edge, .50m/.15m beams, 1.75m mantle and narrow mantle. Existing Step lab preserves curbs/stairs/slopes. Enable GroundSupportProbe/Ground Support Debug for body capsule wireframe, footprint, green/red probes and hits, state/fraction/body-floor distinction and coyote timer. Mantle debug includes its landing support rays/radius.

Known limits: discrete probes cannot guarantee support over arbitrary holes or dynamic/deforming meshes; straight-ledge minimum is not universal certification. No moving-platform policy, balancing, teetering or ledge grab is introduced. Subjective edge pose/IK appearance still needs manual play-testing. Recommended initial settings remain .22m / .12m / .60 / .12s.

Changed files: player_ground_support_v2.gd (new), player_v2.gd, player_v2.tscn, player_traversal_v2.gd, player_ledge_detector_v2.gd, player_mantle_v2.gd, player_foot_grounding_v2.gd, player_foot_ik_v2.gd, player_pelvis_ik_v2.gd, test_ground_support_v2.gd (new), test_mantle_v2.gd, support_test_zone_v2.gd (new), player_v2_lab.tscn, DEV_NOTES.md.

# Traversal Phase 1A — Mantle Geometry Detection (2026-09-06; historical)

Detection/validation ONLY. No mantle animation, repositioning, root motion, alignment snapping, automatic mantle or airborne ledge grab. E uses the existing Phase 0 short ownership test, including lock-on clear and safe return.

PlayerV2/TraversalController/LedgeDetector (player_ledge_detector_v2.gd) separates detect_ledge_geometry() from refresh_contextual_candidate(). The former returns geometry independent of the prompt; the latter skips queries when disabled or incompatible/airborne and updates a reusable mantle_geometry_candidate.gd adapter. ContextInteraction refreshes it before its ordinary candidate scan. Adapter uses action_text Climb, MANTLE, CONTEXTUAL, priority 0; configured levers/doors may outrank it through existing scoring. E re-runs geometry before accepting. Freed obstacles and newly invalid data suppress the same Phase 0 UI immediately. No detector-specific prompt.

Defaults: height .70–1.40m (5mm numerical boundary tolerance), forward cast .75m from player base, reach .90m, wall normal absolute up-dot <=.25, top slope <=min(40 degrees, existing floor_max_angle), minimum top depth .55m, setback .50m. Inspector exposes all plus enable, priority and debug. Depth is conservatively expanded to fit the actual standing footprint: max(min_depth, effective_setback + radius + .03), with effective_setback >= radius+.03. At current .45m radius this requires .98m, not a razor-thin .55m strip.

Front rays use heights .20/.65/1.05m and center/±.15m lateral origins, center first, deterministic face selection. Wall-like first hit supplies obstacle position/normal/source. Downward top search begins .25m above maximum mantle height and .04m inward from the face. Tall-wall fallback checks above max height if no top is found. Height uses current capsule bottom in world coordinates, not an assumed player-origin offset. Top must be walkable and on the same collider as the face.

Support validation samples five depths and three lateral positions across the standing footprint, with short rays around the expected top plane. It rejects missing/discontinuous/different-body or steep support. One standing-capsule overlap query follows only after earlier tests pass; no exclusion of the obstacle, only the player. It uses the existing full standing height/radius even while crouched, 15mm floor tolerance and 5mm margin. Landing is the inward setback point on validated support (+15mm). Alignment is the face projected to the player's floor height, offset outward by radius+.05; facing is the horizontal inward normal. Both are provisional foot/base references only.

Data includes valid/reject_reason, obstacle point/normal/source, top point/normal, ledge_height, floor_reference, measured/required depth, landing/target position, target normal, alignment position/facing, type and mode. Rejects: NO_FRONT_OBSTACLE, TOO_FAR, TOO_LOW, TOO_HIGH, NO_TOP_SURFACE, TOP_TOO_STEEP, TOP_TOO_SHALLOW, DESTINATION_BLOCKED, BAD_FACE_NORMAL, plus DISABLED/STATE_BLOCKED registration states. Verified depth is a sampled support span, not an exact surveyed ledge depth.

Mantle Debug or Traversal Debug shows query rays, hit crosses, face/top normals, height segment, top search, landing/alignment markers and a wire standing capsule. Overlay reports dimensions, stages and rejection. Debug defaults OFF and does not drive detection.

Lab: MantleLedgeTestZone at (-40,0,-12), built by test/mantle_test_zone_v2.gd. Labeled .40/.60/.70/.80/.90/1.00/1.10/1.20/1.30/1.40/1.50/1.70m blocks plus low ceiling, .20m thin shelf, vertical-front 55-degree wedge, corner and 6m wall. Approach within .75m of the face; no climb occurs on E.

Automated PASS: .40/.60 TOO_LOW; .70–1.40 valid; 1.50/1.70/6.0 TOO_HIGH; low ceiling DESTINATION_BLOCKED; thin shelf TOP_TOO_SHALLOW; 55-degree top TOP_TOO_STEEP; near-corner footprint cleanly rejects consistently under small jitter. test_mantle_geometry_v2 also covers debug geometry, crouched candidate, Phase 0 prompt, locked E test/no reposition, source removal, walk-away dismissal, and disabled/Dodge/airborne volume-query skipping. Phase 0 interaction, crouch continuity/modifier, run-roll and hand-isolation regressions pass.

Limits: conservative static/simple top assumptions, same-collider support (seams between separate bodies reject), discrete footprint samples cannot prove absence of arbitrarily small holes, no swept approach/climb path, and complex overhangs/nonplanar tops may reject. This is a reusable staged geometry foundation, not certification that any arbitrary dungeon ledge is climbable. Phase 1B must revalidate and collision-sweep an actual mantle path, add action-specific alignment/animation timing and interruption profiles, and continue to use this candidate data; airborne ledge catch remains a separate future producer.

# Traversal Phase 0 — Context Interaction Foundation (2026-09-06)

InputMap interact uses physical E. No existing player-controller E conflict or binding removal. Godot's built-in macOS text-editing shortcut mentioning E is unrelated and retained. Automatic StepSolver/roll traversal still does not use E.

General interaction/context_interactable.gd component registers in context_interactable group and supplies action_text, interaction_type, priority, availability, grounded/LOS requirements, InteractionPoint and can_interact / get_action_text / get_interaction_type / get_interaction_point / begin_interaction API. Generic activation emits interacted(player) and increments a debug counter; it does not acquire traversal authority. The type enum reserves mantle, ladder, rope, crawlspace, squeeze, vault, ledge, wall-run/jump and generic values without implementing them. candidate_data carries type/mode/source/point/target position/normal/text/priority and test settings.

PlayerV2/ContextInteraction scans the small registered candidate set each motor input tick, validates availability, 2m chest-to-point distance, 80-degree FULL facing cone (+/-40 degrees), grounded/action eligibility and optional raycast visibility. Score = explicit priority + 2*facing dot - normalized distance. Current valid selection is retained until another exceeds it by candidate_switch_margin .15. This lightweight Phase 0 registry can later be replaced with an Area/ShapeCast broad phase for large worlds. E revalidates the candidate immediately before activation. Prompts disappear on range/facing/availability/action changes, traversal start and source removal.

Temporary CanvasLayer UI is PlayerV2/ContextInteraction/InteractionUI/Prompt (lower center), formatted E to {action_text}; it never derives action text from the enum. Debug defaults OFF, with candidate/type/mode/distance/action and traversal lifecycle text plus a range circle and selected-point line. Final UI art and remappable/controller button glyphs are deferred.

PlayerV2/TraversalController accepts request_contextual_traversal(data) and request_automatic_traversal(type,data) separately. Automatic requests bypass candidate prompts, not eligibility. Successful traversal clears LockOnController through its existing clear() API, releasing the camera's old target, and emits traversal_started, traversal_phase_changed and traversal_finished signals for future consumers. Timed dummy lifecycle: ENTRY -> ACTIVE -> EXIT -> NONE, default .8s. active_traversal_type / is_traversing expose authority. Motor integration suppresses player movement/Shift/Jump/Dodge inputs only while owned; normal braking, gravity, collision and crouch posture continue. No teleport, alignment, traversal animation or indiscriminate physics disabling. Input resumes on completion or source-loss release. Lock/crouch toggles are ignored only while owned.

New requests reject active roll/recovery, traversal, StepSolver/roll traversal, 180-turn and incompatible landing states. Grounded is the contextual default; a future source may opt out. Crouch itself is allowed. Interrupt hooks expose interruptible, window-open and explicit reason allowlist (DODGE/JUMP/DAMAGE/KNOCKBACK/PLAYER_CANCEL). Only PLAYER_CANCEL is allowed by default; light damage never automatically detaches. Hooks are not globally wired to Dodge/Jump/damage inputs; future action profiles own that policy and may change it on lifecycle signals.

Reusable test scene: test/traversal_test_interactable.tscn. Lab instances TestMantle (-4,0,3), Climb/MANTLE, and TestGeneric (-6,0,3), Interact/GENERIC_INTERACT. Both are primitive non-colliding marker fixtures; approach facing them and press E. Climb runs the timed ownership test, not a mantle. Interact prints/emits a generic callback only.

Automated test_traversal_phase0_v2 covers E input, empty/behind/out-of-range/occluded/unavailable/freed candidates, stable multiple-candidate scoring, generic activation, crouched and locked start, lock clearing, lifecycle/ownership return, default-grounded rejection, Dodge and active-state rejection, interruption windows and source loss, and automatic request path. Existing crouch continuity/modifier/locked/toggle, run-roll handoff and hand-isolation regressions pass. Normal headless startup is clean apart from the environment's existing root-certificate warning. No source animation, movement tuning, IK, StepSolver, roll curve, hands or camera changes.

Known limits: dummy duration only, facing is character-based not screen-based, debug placement is temporary, generic callbacks are trusted scene components, large-world broad phase and real traversal/action profiles remain future work. Phase 1 should add bounded mantle candidate geometry/clearance and an explicit motion/animation ownership profile first, then automatic ledge detection as a separate producer of the shared request data. No mantle/ledge/ladder/rope/crawl/wall-run behavior is implemented in Phase 0.

# Softer Crouched Idle Blends (2026-09-06)

Crouch move-to-idle and idle-to-move blends restored to .30s each (ranges extended to .60s). These also govern posture transitions into/out of crouched Idle and returns to crouched Idle; final edge configuration prevents the .08s posture handoff from overriding Idle softness. Locked idle uses the same .30s radial blend. Direct moving posture switches remain .15s; idle grace .15s, movement-intent continuity, BOW assignments, physical tuning and action takeoff timing are unchanged. Supersedes the shorter continuity defaults below.

# Crouch Locomotion Continuity (2026-09-06)

Removed the crouch run-stop node, binding, edges and timer/selection logic. The requested BOW_RUNNING_TO_STOP behavior was actually bound as BOW_STANDING_RUN_FORWARD_STOP in this project. That source animation remains in the imported GLB; it is no longer selected by crouch. Other BOW assignments remain intentional and unchanged.

Animation intent uses current raw stick magnitude > crouch_move_input_threshold (.12). Separate animation_moving / animation_running flags retain the previous movement presentation during crouch_idle_entry_delay (.15 seconds) of sub-threshold input. Returning input clears the timer without re-entering the animation. Real stops crossfade straight to Idle, using crouch_move_to_idle_blend .15s; idle departure uses crouch_idle_to_move_blend .12s. Settings appear under Crouch > Locomotion Continuity, with existing direction smoothing speed 12. Recommended initial tuning is .12 / .15s / .15s / .12s respectively.

Free movement selection was already input-based, not velocity-based; it now tolerates short gaps/overlapping opposite keys. Locked Cartesian direction interpolation could cross the blendspace's Idle center even with continuous input. It now smooths direction angle around the cardinal diamond, keeping movement weight separate from heading; only true Idle entry reduces that weight. Current direction is tracked from input independently of physical velocity. This eliminates Idle weight during Locked reversals without changing acceleration, braking, speed or facing physics.

Motor change only passes delta to presentation continuity. Existing running-speed calculation, direct moving crouch architecture, toggle, capsule/clearance and action priority are retained. Dodge/air/inactive posture clears presentation grace. Debug shows raw intent, timer, retained animation mode/direction, speed and stop-clip-disabled status.

Automated PASS: test_crouch_continuity_v2 (Free/Locked Walk/Run W↔S, A↔D, rapid WASD, forced zero-speed samples, brief input gaps, true stop, noise rejection, zero Idle weight on Locked diamond, Dodge during grace, source stop retained); existing crouch, locked crouch, modifier handoff and toggle suites also pass. Manual visual play-testing remains recommended. Earlier run-stop documentation below is historical and superseded.

# Crouch Locomotion Modifier Architecture (2026-09-06)

Supersedes moving handoff timing in the previous section. User confirmed preservation of BOW assignments, functional Shift crouch-running, and CTRL toggle; no LOC replacements or Walk-only downgrade.

Moving entry/exit now bypass CRC posture clips entirely. Physical ENTER/EXIT tracks capsule resizing independently, while presentation immediately selects crouch Walk/Run (Free) or the corresponding Locked directional blendspace, and returns directly to standing Loops/Locked. Existing current-input gait/direction priming avoids idle weight on re-entry. Moving enter/exit blend settings default to .15s each (Inspector Crouch > Moving Transitions, range .10–.20); existing collider transition speed 4.0 remains there too. Moving completion depends on capsule height, never idle handoff progress or clip duration.

Stationary entry/exit retains CRC clips and the previous .88/.08s handoff. Starting movement during stationary entry bypasses the remaining clip once the crouch capsule is established; starting movement during exit bypasses the clip after the existing clearance check. There is one physical phase controller and one animation selector, not competing state machines. No moving route includes CrouchIdle or a posture clip as an intermediary.

Standing Run/Sprint buildup is cleared on entry without stopping momentum. Shift continues to select the intentional BOW crouch Run at its existing speed; without Shift, crouch Walk retains its speed. Free exit returns through Walk before normal gait promotion; Locked retains its current supported Walk/Run restoration. No movement tuning or action curves changed.

Capsule interpolation keeps its original dimensions, rate, and fixed base. Repeated full-height clearance validation remains authoritative during exit expansion. A blocked release keeps crouch movement; when clear, current input selects direct moving exit or stationary posture exit. Dodge priority and return behavior, jump restriction, source GLB, IK, StepSolver, hands and camera remain unchanged. Debug includes modifier state, physical phase, selected clip, movement, previous gait, target speed and whether a posture clip or direct resize is active.

Regression: updated test_crouch_handoff_v2 now tests direct moving entry/exit, no intermediary node, smooth independent capsule sizing, speed preservation, Run/Sprint entry, stationary interruption, low ceiling release, and all four Locked directions at Walk/Run. It passes, as do crouch, locked crouch, toggle and run-roll handoff suites. Visual blend feel requires manual play-testing; recommended initial blends are .15s/.15s.

# Crouch Dynamic Transition Destinations (2026-09-06)

Preserves CTRL toggle and the current CRC/BOW set; older hold-CTRL / LOC clip examples in the task are not asset or input changes. Existing Free selection was already dynamic, not a hardwired Idle bridge. The hitch risks were full transition-tail playback, stale/smoothed destination gait or direction (especially late input), and nested standing Start routing through Free Loops before Locked.

Inspector: Crouch > Transitions exposes enter/exit handoff progress .88/.88 (range .80–.95), handoff crossfade .08 seconds (.05–.15), and meaningful input threshold .15 (.10–.20). Ordinary crouch locomotion crossfades remain .30 seconds. Start manual tuning at the defaults; .90 progress and .10–.12s blend are alternatives if the default feels too early/sharp.

The motor supplies CURRENT stick and Shift every physics tick, not a transition-entry snapshot. At handoff, Free entry selects CrouchIdle without meaningful input, otherwise BOW crouch Walk/Run according to current Shift. Locked entry selects its current directional Walk/Run blendspace, primed to current combat input (or its idle center). Free exit selects standing Idle/Walk directly; normal Run/Sprint promotion follows physical completion. Locked exit selects current directional Walk/Run or its existing Idle, never Sprint. Source crossfade supplies pose blending, so destination gait/direction does not first interpolate from an obsolete Idle. Nested standing Start now resolves to current Free/Locked mode in the same evaluation.

One handoff pulse per transition; normal destination selection continues afterward. Original physical phase completion thresholds, capsule dimensions/interpolation and repeated clearance validation remain in place through the outgoing tail. Dodge/air interruption and blocked clearance clear handoff metadata. No horizontal physics retiming, movement speed changes, source clip edits, IK, StepSolver, hand interaction or camera changes. Debug crouch text includes transition phase/progress/threshold, current stick/combat input, mode, predicted and last chosen destination.

Automated regression: test_crouch_handoff_v2 covers stationary/moving entry and exit, adding/releasing input mid-clip, sub-threshold noise, all Locked cardinal directions, Shift exit, actual nested playback destination, one-shot handoff and original physical completion. Crouch, locked crouch, toggle, walk-direction, run-roll handoff and environmental hand isolation suites pass. Visual feel still requires play-testing.

# Persistent Crouch Toggle (2026-09-06)

Crouch idle/movement/run-stop crossfades now use a dedicated crouch_locomotion_blend_time (.30s). Locked directional pose blending is rate-limited by the same duration, retaining exponential direction smoothing. These are presentation-only changes; movement speeds, crouch toggle/clearance, entry/exit timing, dodges and source clips are unchanged.

CTRL now toggles the crouch request on each press; releasing or holding the key does not change the request. This supersedes earlier hold-to-crouch instructions. The request persists through movement, Lock-On and dodges. Toggling off beneath a ceiling waits for standing clearance. Animation mappings, movement tuning and IK are unchanged. Deterministic step_motor tests still supply an explicit desired crouch state.

# Crouch BOW Animation Set (2026-09-06)

User-directed replacement of the previous LOC/torch movement set using ONLY Actions already present in Blender Master Rig.glb. No desktop FBX imported or copied. Canonical backward Run is BOW_STANDING_RUN_BACK. User shorthand CRC_Crouch_to_Standing / CRC_Standing_to_crouched resolves to the existing CRC_CROUCH_TO_STANDING / CRC_STAND_TO_CROUCH. This section supersedes the earlier crouch Walk-only rule: Shift now selects crouch Run, but never Sprint.

| Role | Imported Action | Seconds |
| --- | --- | --- |
| Enter | CRC_STAND_TO_CROUCH | .666667 |
| Exit | CRC_CROUCH_TO_STANDING | .666667 |
| Idle | CRC_CROUCH_IDLE | 2.533333 |
| Walk forward/left/right | BOW_STANDING_WALK_FORWARD / BOW_STANDING_WALK_LEFT / BOW_STANDING_WALK_RIGHT | 1.233333 each |
| Walk back | BOW_STANDING_WALK_BACK | 1.500 |
| Run forward | BOW_STANDING_RUN_FORWARD | .900 |
| Run left/back | BOW_STANDING_RUN_LEFT / BOW_STANDING_RUN_BACK | .700 each |
| Run right | BOW_STANDING_RUN_RIGHT | .800 |
| Forward run stop | BOW_STANDING_RUN_FORWARD_STOP | .900 |

Walk and Run each have a target-relative four-direction Locked BlendSpace with CRC Idle at center. Free mode rotates toward travel using the existing smoother and uses the corresponding BOW forward Walk/Run. Forward Run release uses the .9 s nonlooping stop clip, with existing motor deceleration; renewed movement, crouch exit or Dodge cancels it. Locked sideways/backward stops blend to Idle instead of playing a mismatched forward stop. Loops, horizontal travel cancellation and all playback configuration affect only duplicated runtime resources. No source pose editing or bow prop added.

Crouch Walk speed remains inherited current Walk (2 m/s). New crouch_run_speed=0 inherits current standing run_start_speed (4 m/s); positive values override. Crouch running is a separate request flag, not permission for the standing Sprint buildup or running-roll action. Shift is consumed by crouch and standing gait stays Walk internally; Sprint timer remains zero. Moving crouch ALT still selects DOD_STAND_TO_ROLL, stationary ALT Backstep. CTRL hold, locked crouch, capsule/base preservation, clearance, Jump suppression, foot IK, environmental-hand exclusion and camera behavior are retained.

Updated crouch tests validate the imported mappings, locked four-direction Run including Back, speeds, no Sprint, run-stop completion/interruption, and crouch Run's walk-roll ownership. Existing core crouch and standing regressions pass. These BOW_STANDING clips are used as requested; their authored posture/weapon-arm pose may still need future art adjustment to become a consistent low-profile crouch set. No claim of new mesh-level head-clearance correction.

Changed player_crouch_v2.gd, player_animation_v2.gd, the motor's crouch input handoff, crouch tests and these notes. No GLB/FBX changes; no commit/push.

# V2 Phase 5A — Crouch Rebuild

2026-09-06. Replaces the previous temporary crouch implementation's clip selection and lock rejection. The user authorized torch presets for missing directions and horizontal-travel cancellation in runtime copies only. GLB remains SHA256 B3CC9744D338A87E6F7594E78ABAEB0F4F572F175684B1A2C2E7B8A5310DD8B9.

## Verified Actions and source review

| Role | Canonical Action | Duration | Runtime looping |
| --- | --- | --- | --- |
| Enter | LOC_STAND_TO_CROUCH_B | 4.100 s | None |
| Exit | LOC_CROUCH_TO_STAND_B | 3.466667 s | None |
| Idle | CRC_CROUCH_IDLE | 2.533333 s | Linear |
| Free / Locked forward | LOC_SNEAK_FORWARD | 1.700 s | Linear |
| Locked left | LOC_WALK_STRAFE_LEFT_SLOW | 1.500 s | Linear |
| Locked right | LOC_WALK_STRAFE_RIGHT_SLOW_RAW | 1.500 s | Linear |
| Locked backward, temporary torch fallback | TRC_CROUCH_TORCH_WALK_BACK | 1.200 s | Linear |

All source Actions import with loop mode NONE. Loop modes are set only on duplicated runtime resources. Neutral CRC_CROUCH_IDLE is a suitable canonical crouch idle and has approximately matching endpoint pose; no frozen arbitrary sneak pose used. No neutral crouch-backward Action found. Magic and torch backward candidates exist; the user-authorized torch backward clip is used normally, not reversed. Its torch-carrying upper-body pose is temporary and no torch prop is spawned.

RAW right strafe contains -90.095 rig units of lateral Hips travel, about -.901 m at player scale, over 1.5 seconds. Only the Hips position track has significant translation in the reviewed Actions; no separate authored world/root travel was found. Existing instance-local library duplication and horizontal Hips X/Y normalization now cover all crouch Actions, including RAW right strafe. Vertical local Z and bone rotations are preserved. Runtime test confirms constant horizontal Hips coordinates while the separately loaded source clip still retains >80 rig units of lateral displacement. CharacterBody remains the only movement authority; no root-motion-driven physical displacement was added.

Source limitations are important: the two requested slow strafe clips are upright walking poses (sampled head height ~1.56 m), NOT visually deep crouch poses. CRC idle head is ~.78 m; sneak head is ~1.12-1.16 m at endpoints; torch backward head ~1.22-1.24 m. Sneak has about 4.8 cm vertical endpoint mismatch despite matching rotation endpoints. Left strafe rotation seam ~.38 degrees, torch backward ~.056 degrees; others nearly zero. These are endpoint checks, not exhaustive loop-quality approval. Source vertical motion was not flattened or retargeted to invent crouch. Therefore pose-height transitions and sneak-loop bob remain visible; upright strafes can intersect a low visual ceiling even though the capsule safely fits. Replace these with authored low-profile strafe/backward clips and a height-consistent forward/Idle set when the library is ready.

## State, movement and priorities

CTRL remains HOLD TO STAY crouched in Free AND Locked-On. CrouchController retains STANDING/ENTER/CROUCHED/EXIT, with AnimationTree playback driving transition completion, no duplicate timer. Default playback 1x and exit progress 1.0 retain the full authored 4.1/3.4667-second clips. Long transition duration is intentional pending user tuning; no accelerated arbitrary .6-second window. Enter/exit playback speeds expose .8-1.2 and configure custom timeline duration when the player tree is built.

Free crouch rotates toward camera-relative travel with the same angular Walk smoother and uses LOC_SNEAK_FORWARD for all movement directions. Idle camera orbit still does not turn the character. Standing 180 actions remain excluded. Locked crouch stays target-facing using the existing target-relative movement basis. CrouchLocked is a five-point cyclic BlendSpace2D (neutral center, forward, left, right, torch backward); input is exponentially smoothed at 12/s. Lock/unlock changes movement mode without forcing a stand. No crouch-specific camera was added.

Shift cannot enable Run/Sprint or accumulate Sprint buildup in either mode, including transitions and crouch-started Dodge. Crouch speed inherits the current 2 m/s Walk speed by default (`crouch_move_speed=0` means inherit; positive value overrides). Jump is blocked, with no auto-stand-and-jump. Dodge and airborne presentation remain higher priority. Stationary ALT uses current Backstep; moving ALT uses DOD_STAND_TO_ROLL even with Shift. Crouch-started Dodge retains the reduced collider, then held CTRL returns to crouch; released CTRL checks standing clearance. Lock stays active if the target remains valid. Environmental hand eligibility continues to reject crouch.

## Collider, safety and tuning

Standing capsule height 1.80 m, radius .45 m, local center .90 m; crouch height 1.10 m, same radius, center .55 m. Each instance duplicates its shape. Every resize recomputes center from the original base, preserving the bottom. Entry begins shrinking at `crouch_collider_transition_speed=4 m/s`; exit expands at that rate only after a FULL standing-capsule overlap test. This is a physical collision transition, not an exact animated mesh/head envelope; at default speed it completes well before the long transition clips.

The standing query uses the original full capsule, collision mask and self exclusion, with existing 2 mm floor-contact tolerance. CTRL release under a roof keeps crouch active with no exit spam, continuously checks clearance and automatically exits once clear. Exit rechecks clearance each tick; if obstructed it cancels back to crouch and restores the small collider. Reduced-capsule Dodge does not expand into the ceiling. No ray-only clearance shortcut or StepSolver redesign.

Inspector Crouch defaults: move speed 0 (inherit Walk=2), enter/exit crossfades .15/.15 s, enter/exit playback 1/1, full-clip exit progress 1/1, collider transition 4 m/s, capsule 1.10 m, locked direction blend 12/s. These are starting values, not a claim the inconsistent source heights have been solved. No crouch IK multiplier or camera offset was needed for the tested numerical stability. Existing foot grounding/IK/pelvis/knee implementation and settings were left unchanged.

## Lab, tests and debug

Existing crouch zone retains standing-clear corridor, 1.30 m tunnel/room, too-low obstacle, open exits and cumulative curbs. Added a 15-degree slope and a target beside the tunnel using the existing lock target contract. The existing open target arena remains available. Crouch debug shows CTRL, Free/Locked, phase, physical dimensions, clearance/blocker, node, dominant canonical Action, target-relative input/blend and speed.

Updated `test_crouch_v2.gd` passes natural-duration entry/exit, capsule-base preservation, Free motion, Shift/Jump suppression, no hands, low-roof release/no spam, Lock-On under the roof, stationary/moving crouch dodges, CTRL release during Dodge, automatic stand after clearing, low-tunnel traversal, too-low collision, curb/three-stair traversal and Free direction changes.

New `test_crouch_locked_v2.gd` passes exact four directional clip assignments, smoothed cardinal blend convergence, target-facing, Walk speed, Shift/Jump suppression, lock/unlock retention, runtime RAW cancellation/source preservation, Free angular smoothing, and 20-degree slope finite/non-stretching pole-consistent knees. Standing regressions pass: Walk direction, environmental-hand isolation, sprint roll, running-roll handoff and locked-roll realignment. No claim that all historical IK suites are green; their pre-existing limitations are documented below.

Rendered new Idle, Free sneak and Locked right strafe were inspected. The right strafe render confirms the source's upright posture while physical state is crouched; it has no accumulating RAW sideways drift. Tests plus snapshots are not comprehensive interactive visual approval. There is no promise of mesh-safe low-ceiling traversal with the currently requested upright clips.

Future assassination/sneak-attack systems may query CrouchController.active()/phase and current lock state. No attacks, stealth detection, noise, enemies, prone, cover or new Dodge mechanics implemented.

Files changed: `Characters/Player/V2/player_crouch_v2.gd`, `player_animation_v2.gd`, `player_v2.gd`; `test/crouch_test_zone_v2.gd`, `test/test_crouch_v2.gd`, new `test/test_crouch_locked_v2.gd`; this document. GLB/source animations unchanged. Not committed or pushed.

# Master GLB Refresh (2026-09-06)

Replaced Characters/Player/Models/Blender Master Rig.glb with the desktop export, preserving the asset path/import configuration. Source and destination SHA256: B3CC9744D338A87E6F7594E78ABAEB0F4F572F175684B1A2C2E7B8A5310DD8B9. Previous asset is recoverable in the task workspace at work/master_glb_backup_20260906/Blender Master Rig.glb.

Animation count 843 -> 847 with no removed names; node-name inventory and 65-joint skin count unchanged. Verified imported new clips: LOC_CROUCH_TO_SPRINT (.5333 s), LOC_CROUCH_TO_STAND_B (3.4667 s), LOC_CROUCHED_WALKING (1.1 s), LOC_STAND_TO_CROUCH_B (4.1 s). Existing controller mappings remain unchanged; new crouch Actions were imported but not activated.

Nine selected regressions pass: Walk direction, hand contact/pose/isolation, crouch, Dodge, sprint roll, running-roll handoff and locked-roll realignment. Normal startup runs 180 frames without script errors. Import succeeded; editor also reported stale legacy PlayerTest instance warnings and an environment permission error saving global editor settings, plus the existing root-certificate warning. No asset-import or V2 runtime script errors found. This is automated compatibility verification, not exhaustive visual approval of all 847 clips. No commit/push performed.

# Selective Foot IK Rollback (2026-09-06)

At the user's request, reverted Walk foot IK responsiveness, slope-adaptive stabilization, target-displacement/bend-reserve refinements and their diagnostic startup guard to the pre-responsiveness foot system. Restored the foot IK, grounding, planting and knee-test files from the saved pre-change revision. Removed the three experiment-specific test scripts and their UID sidecars; recovery copies and superseded notes are in the task workspace under work/foot_ik_rollback_backup_20260906.

Walk-to-Idle environmental hand persistence, Walk direction smoothing, crouch work, tuned movement and other systems are preserved. No new stair solver or IK substitute was added. This rollback is not committed or pushed.

Verification: restored four files match the saved originals after line-ending normalization. Motor and both environmental hand scripts retain their exact pre-rollback SHA256 hashes. Seven selected tests pass: Walk direction, hand contact, hand pose, hand isolation, crouch, sprint roll and running-roll handoff. Normal automatic startup runs 180 frames with no script errors; the unrelated root-certificate-store warning remains. Visual playtesting is still the user's final check.

# Minor Cleanup — Hand Idle Persistence + Walk Turn Smoothing

2026-09-06. This section supersedes the older Walk-Only Isolation section's deliberate removal of Idle Hold; its hard action-state isolation remains in force.

## Environmental hands

The regression came from using strict WALK eligibility for both acquisition and continued skeletal ownership. `can_acquire_environment_hand_contact()` requires ordinary grounded Free Walk, meaningful movement, no incompatible action, no selected contact and an expired cooldown. `can_persist_environment_hand_contact()` permits Walk or Idle only with a live existing surface and a contact acquired during Walk. Contact updating continues to validate the sensed surface, safe reach, body angle and normal continuity; persistence permission does not bypass those geometric checks.

Walk -> Idle now retains the selected hand as IDLE_HOLD, with the existing Idle follow rate, wall orientation and tangent. Idle -> Walk along the same wall resumes CONTACT without restarting staged reach or applying cooldown. Idle without a Walk-acquired contact cannot acquire. Walking away, losing the surface/reach or exceeding geometric limits releases through the existing release/cooldown path. Run, Sprint, rolls/backstep, Jump/Fall/Land, Lock-On, 180 turns and other incompatible actions still immediately clear all environmental arm authority, including deferred modifier execution. Debug distinguishes acquisition permission, persistence permission and Walk acquisition provenance.

## Free Walk direction

Previously ordinary Walk fed raw input directly into its velocity target, while facing used a quick proportional blend. There was no angular-rate-limited travel target for ordinary successive 45-90 degree input changes. The existing large-turn arc and authored reversal handling were separate paths, not a general Walk smoother.

PlayerV2 Inspector **Free Walk / Walk Direction Turn Speed** defaults to **360 degrees/second**, with recommended tuning range **240-480** (lower gives wider turns, higher responds faster). Raw camera-relative `desired_move_direction` remains immediately available to decisions. After reversal/arc selection, ordinary standing Free Walk rotates `smoothed_walk_direction` toward the desired horizontal yaw using shortest-angle `rotate_toward`, bounded by turn speed times delta. That unit direction feeds the existing acceleration/deceleration target and Walk facing. No linear direction interpolation through zero at a reversal.

The smoother bypasses crouch, Run/Sprint, locked movement, airborne/actions/dodges, authored 180 ownership and the existing large-turn arc. Walk180 still reads raw input before smoothing. No-input frames retain current facing rather than following a stale target; orbiting the camera while Idle does not rotate the body. Existing movement speeds, acceleration/deceleration, action curves, camera, StepSolver, Foot IK, pelvis and source clips were not changed. Enable `debug_walk_direction` for desired/smoothed direction, facing error, angular speed and active Walk180 diagnostics.

## Verification

Automated headless checks (not interactive manual playtesting): repeated W -> D -> S -> A -> W and diagonal changes produce progressive unit-direction rotation, with maximum yaw step approximately **6 degrees at 60 FPS** at the default speed. Raw input updates immediately; genuine opposite input still triggers Walk180. Idle camera orbit preserves yaw, and Run/Sprint/Lock bypass smoothing. The angular helper also converges consistently at 30/60/120 Hz.

Hand contact, sensing, IK, pose and isolation tests pass. Coverage includes no spontaneous Idle acquisition, Walk -> Idle Hold -> Walk without reacquisition, preserved tangent, and action handoffs from Idle Hold with zero native IK/wrist authority and source-pose comparisons. Running-roll handoff, sprint-roll, locked-roll realignment, turn-arc and crouch regressions also pass (11 selected tests total including the new Walk direction test). The unrelated Windows root-certificate-store warning remains. No interactive visual approval is implied.

Files in this cleanup: `Characters/Player/V2/player_v2.gd`, `player_debug_v2.gd`, `player_environment_hands_v2.gd`, `player_environment_hand_ik_v2.gd`; `test/test_walk_direction_v2.gd` (new), `test_environment_hand_contact_v2.gd`, `test_environment_hand_ik_v2.gd`, `test_environment_hand_pose_v2.gd`, `test_environment_hand_isolation_v2.gd`; this document. Crouch implementation remains on hold and unchanged by this cleanup. Not committed or pushed.

# V2 Phase 5A — Crouch Foundation (2026-09-06)

## Input, state and Actions

InputMap `crouch` uses physical CTRL, hold-to-crouch (not toggle). The motor's optional final `crouch_held` argument supports deterministic tests while preserving prior call signatures. New `CrouchController` owns STANDING / ENTER / CROUCHED / EXIT, capsule size, standing-clearance queries and requested state. AnimationTree owns transition playback/progress; no duplicate clip timer.

Verified current imported canonical Actions and lengths:

| State | Action | Source length |
| --- | --- | --- |
| Enter | `CRC_STAND_TO_CROUCH` | .666667 s |
| Exit | `CRC_CROUCH_TO_STANDING` | .666667 s |
| Idle | `CRC_CROUCH_IDLE` | 2.533333 s |
| Walk | `MGC_CROUCH_WALK_FORWARD` | 1.166667 s |

**MGC_CROUCH_WALK_FORWARD is temporary** and must be replaced with a neutral crouch-walk Action after a future master GLB update. All moving directions currently use it, with ordinary camera-relative Free facing and no dedicated crouch pivot/strafe/backward clips. Standing 180 clips cannot start while crouched. Only runtime instance-local animation copies are configured: transitions non-loop, Idle/Walk loop, horizontal Hips motion normalized as with existing locomotion while authored vertical crouch remains intact. No source clips were renamed or changed.

Inspector controls live on CrouchController under Crouch: speed (0 inherits motor Walk), capsule height 1.10 m, enter/exit blends .15/.15 s, enter/exit exit-progress .90/.90, debug false. Transition source windows therefore run about .60 s before changing state. Shift is ignored and Sprint buildup reset throughout crouch, including transitions and crouch-started dodges. Jump is ignored while crouched; no automatic stand-and-jump in Phase 5A. Normal gait logic resumes after the standing transition, with the completion tick still Walk rather than jumping directly into Sprint.

## Physical collider and standing clearance

Standing collider was inspected: CapsuleShape3D **height 1.80 m, radius .45 m**, centered at local Y=.90 (bottom Y=0). Crouch duplicates the shape per player instance and uses **height 1.10 m, same .45 m radius**, center Y=.55. It lowers only the capsule top, preserving its base. The Inspector height is clamped between capsule diameter and original standing height. Resize is immediate and stable in deterministic floor/tunnel/curb tests; no character scale or VisualRoot offset was introduced.

Standing height/radius are derived once from the original collider. On CTRL release, a direct standing CapsuleShape3D overlap query checks its full intended volume against the motor collision mask, excluding the player RID. A 2 mm upward query tolerance avoids floor-contact false positives; no expansion into a detected obstruction. Blocker name/result appear in debug. A blocked request retains the small capsule and does not restart the exit clip; the released CTRL state is checked each physics tick. Once clear, the full collider is restored and CRC_CROUCH_TO_STANDING plays automatically. Expansion is done only after the clearance check, so the standing collision body protects the rest of the exit transition.

This remains an approximate capsule, not exact animated head/hand collision. The temporary magic walk's head bone peaks near **1.30 m** above the body base in the sampled cycle, above the 1.10 m physical capsule; head/arms can visually intersect particularly tight overhangs even though collision traversal is valid. Crouch Idle is much lower. Until the neutral clip arrives, use higher visual tunnel clearances or tune Crouch Capsule Height upward (and corresponding lab geometry) if mesh clearance matters more than the initial compact crawl-space size. No arbitrary downward mesh offset was used because it would sink the feet.

## Compatibility and priorities

Entry requires Free, grounded, ordinary Locomotion/Loops, no Dodge/recovery, active StepSolver/roll traversal or 180 turn. Crouch remains a physical mode if stepping off an edge: existing Fall/Land presentation has priority, with no crouch jump. Dodge wins over crouch presentation. A crouch Idle ALT uses existing Backstep; moving ALT uses DOD_STAND_TO_ROLL, never the Shift Run/Sprint roll. Crouch-started Dodge retains/reasserts the crouched capsule throughout the action, including interruption of crouch-enter/exit. Afterward, held CTRL returns to crouch; released CTRL attempts standing and remains small when obstructed.

Lock-On while already locked ignores CTRL. A lock attempt while crouched is rejected; if clear it begins a stand transition, and the player must request Lock-On again once standing (release CTRL to stay standing). A future externally forced locked+crouched state clears Lock-On, attempts standing and reports any ceiling blocker rather than allowing an invalid combined mode. No combat locomotion or camera tuning changed.

Environmental hand eligibility explicitly rejects CROUCH, including transitions/dodges. StepSolver already queries the live CollisionShape3D transform/shape and base-relative risers, so no duplicated solver or threshold adjustment was needed. Crouch allows the normal step path and normal smooth Free facing, while standing 180 actions stay suppressed. Foot terrain sensing, leg IK and pelvis stay unchanged and active as permitted by their existing support logic. Crouch Idle does not opt into the special standing-Idle extended-reach override. On the test curb, IK remained finite/non-stretching and pelvis drop remained within the existing .20 m limit (sample around -.006 m); no crouch-specific IK multiplier was needed for this foundation.

Camera framing and distance controls are untouched; no automatic crouch camera drop. Crouch debug is default off and displays CTRL, phase, physical dimensions, clearance/blocker, animation mode and speed through the existing debug overlay. Enable CrouchController.crouch_debug for it; the normal debug panel must also be enabled.

## Lab and verification

New Crouch Test Zone is centered around **(45,0,8)**, east of spawn, with its own floor and simple box collision. Labeled lanes: standing-clear 2.10 m, low beam 1.65 m, short tunnel 1.30 m, too-low obstacle .85 m. It also includes a larger 1.30 m low-ceiling room with open exits and three .10/.20/.30 m cumulative curbs under a 1.60 m overhang. These values are test geometry, not automatic derivatives of Inspector capsule tuning.

`test_crouch_v2.gd` passes: actual CTRL mapping; Enter/Idle/Walk/Exit nodes; physical height and bottom preservation; inherited current **2 m/s** Walk speed; Shift/Sprint and Jump suppression; no crouch wall hands; blocked standing/no transition spam; tunnel traversal with CTRL released inside and automatic standing outside; Backstep/moving roll and post-dodge CTRL handling; released CTRL during low-ceiling dodge without expansion; blocked Lock-On and locked CTRL suppression; too-low obstacle collision; crouch curb traversal; camera-relative direction changes without standing pivot clips; finite non-stretching leg IK and bounded pelvis correction.

Standing regressions passed: environmental hand isolation/pose, running-roll handoff, sprint roll and locked-roll realignment. Enter/Idle/Walk renders were inspected; tests are automated plus rendered inspection, not interactive manual playtesting. Existing historical tests with hardcoded old walking speeds were not rewritten as part of this feature. Root-certificate warning remains unrelated.

Known limitations: temporary magic arm/height profile, one forward crouch clip for all travel directions, no crouch strafing/combat/Jump, no anatomical head collision, no special camera offset, and existing terrain support weights rather than dedicated crouch foot planting. Reduced-capsule dodges may have visible source-pose intersections in very tight spaces; movement remains collision constrained. No Run/Sprint crouch, prone, stealth/noise, sliding or cover mechanics added. Not committed or pushed.

# Environmental Hand IK — Walk-Only Isolation (2026-09-06)

## Reproduced ownership leak

The old state gate stopped *contact acquisition*, not skeletal authority. On the first evaluated Stand Roll frame after wall contact, `environment_hand_contact_active` was false but positional weight was .90, wrist correction .90 and native TwoBoneIK influence **1.0**. Following frames still had .885/.844/.782 positional/wrist weight with native influence 1.0. The generic .22-second RELEASING path kept preparing body-relative wall targets/poles and writing hand rotation over the Dodge pose. This was an actual ownership leak, not a need to lower contact weights globally.

Foot IK owns the one production `skeleton.advance()` call following AnimationTree evaluation. Environmental preparation, the two arm solvers and hand correction remain appended after the foot modifiers. The mixer-applied boundary check previously only began a fade; it now removes authority immediately for actions. Preparation and final capture also check the same eligibility, covering deferred modifier execution without a second production skeleton advance.

## Authoritative eligibility and Idle change

`EnvironmentalHandInteraction.can_use_environment_hand_ik()` is the single authoritative boolean, backed by its diagnostic `eligibility()`. Sensing, candidate choice, contact updates, preparation, final hand writes and the evaluated-pose boundary all derive from it. Allowed: enabled, valid rig, ordinary grounded FREE WALK, meaningful movement input/speed, Locomotion/Loops presentation, no higher-priority state. Rejected reasons include DISABLED, MISSING_RIG, LOCKED, DODGE, JUMP, FALL, LAND, NOT_GROUNDED, RUN, SPRINT, TURN, TRAVERSAL, ACTION, IDLE and TOO_FAST. Presentation/action checks precede Idle, so a stationary action cannot accidentally receive the Idle fade exception.

Idle Hold is disabled. The old optional held-side/allow-Idle arguments remain compatibility signatures only; they no longer grant Idle eligibility or probe updates. Walk -> Idle clears contact and uses the existing .22-second release. Once complete, Idle has zero native IK, pole/position and wrist weight and no hand write. This short exit fade is the **only deliberate non-Walk skeletal exception**, following the explicit requested smooth Idle release; there is no ongoing Idle contact or new Idle acquisition. Any action interrupting that fade immediately cancels its authority. Legacy IDLE_HOLD enum/settings are inert compatibility fields, not reachable contact states.

## Forced handoff, cache reset and bone writes

`protect_non_walk_pose()` routes Idle to the bounded release and every other rejection to `ensure_environment_hand_pose_released()`. Forced handoff sets both actual native solver influences, positional/pole weights and wrist weights to exactly 0. It clears selected side, collider, contact positions/normals/tangent, acquired/persistence flags, reach timers/transforms, desired rotation, release caches and marker targets. It also handles an already-RELEASING arm, rather than checking only the contact-active flag. Noneligible action preparation returns before target solving; capture does no wrist writes. Helpers still run control/read-only diagnostics, but the arm solvers have zero influence.

The system uses `set_bone_global_pose()` inside a SkeletonModifier3D pass, **not persistent `set_bone_global_pose_override()`**. Godot restores modifier input poses after evaluation. Inactive operation skips all hand writes and clears their cached targets/write flags; no global override-clear call is made that could disturb Foot IK or another owner. Regression tests compare all upper-arm, forearm and hand input/output transforms inside the modifier pass to verify that no manual correction survives into an action.

Forced release starts the existing global 1.75-second cooldown immediately. Ordinary walking-surface/Idle release starts it after the .22-second fade. Already-running cooldown is preserved and counted down, never restarted every ineligible frame. Both hands remain blocked on a quick return to Walk. Staged reach (.55 seconds), fingers-up/palm-to-wall orientation, positional/rotation settings and ordinary walking drag remain unchanged.

## Regression results

New `test_environment_hand_isolation_v2.gd` establishes real wall contact before each transition. It verifies zero actual native IK/wrist/pole influence at the action boundary, then waits for Godot's deferred modifier pass before comparing captured arm transforms. It also re-evaluates the same pose with the component disabled to compare against enabled-but-ineligible output; this test-only skeleton advance does not change production update ownership.

Passing cases: Stand Roll (`DOD_STAND_TO_ROLL`), Run Roll (`DOD_RUN_TO_ROLL`), Sprint Roll (`DOD_SPRINT_TO_ROLL`), Backstep (`DPD_DODING_BACK`), Run, Sprint, Jump, passive Fall and Land, Lock-On, ordinary reverse-input turn, Idle release and immediate Walk-return cooldown. All three bones on both arms match the incoming evaluated animation transforms outside the Idle exit fade; disabled reference comparisons also match. Jump and passive-fall cases both reach Land. The run/sprint/lock cases each checked 150 subsequent ineligible frames; no stored wall pose reappeared.

Eight targeted suites pass: environmental isolation, pose, contact, arm IK, sensing; running-roll handoff, sprint roll and locked-roll realignment. Existing tests expecting persistent Idle contact now expect release/cooldown instead. Walking reach/orientation, wall-end/pillar/corner behavior and one-hand selection remain covered. These are deterministic headless pose comparisons, not a claim of interactive visual playtesting or of passing every historical movement test. The unrelated Windows root-certificate warning persists.

Changed only environmental sensing eligibility, hand controller/modifier documentation, hand tests and these notes. No Roll curves/timing, traversal, lock-on movement, camera, StepSolver, Foot IK/pelvis or animation assets changed. Not committed or pushed.

# Environmental hands — palm reversal (2026-09-06)

The user's close-up screenshot confirms the fingers-up pose still presented the wrong hand surface. Reverse its X/Z axes (180 degrees around finger-local +Y), preserving projected-up finger direction. The active convention is now palm +Z facing into the wall; this supersedes the earlier -Z interpretation. Palm-depth offset and debug/test palm-axis signs match the correction. No reach, release, cooldown, movement or sensing behavior changes.

# Environmental hands — fingers-up contact (2026-09-06)

User-requested orientation-only refinement: the contact frame now maps finger-local +Y to world up projected onto the wall plane, while palm-local -Z continues facing into the wall. Travel tangent still controls existing drag/pole behavior, but no longer determines finger direction. Both hands use the same geometric construction with their existing per-hand offsets. Reach staging, positional/rotation weights, palm clearance, release, cooldown, sensing and movement remain unchanged. The hand pose test now measures finger alignment against projected up instead of travel tangent. This supersedes the along-travel finger orientation documented below.

# Environmental Hand Interaction Phase 4.1 (2026-09-06)

## Corrected hand axes and geometric basis

**This section supersedes the Phase 3/4 palm-sign assumption.** Reinspection of both hand rest transforms confirms +Y toward Middle1 (about 9.533 imported units), with Left Thumb1 X=-2.682 and Right Thumb1 X=+2.682. However, thumb Z displacement alone does not identify the palm-facing normal. Close-up rendered local-axis/mesh inspection exposed that the old +Z contact put the thumb edge underneath and the wrong side of the hand toward the wall. The corrected mapping is:

| Hand | Palm normal | Finger forward | Thumb-side / secondary |
| --- | --- | --- | --- |
| Left | -Z | +Y | -X |
| Right | -Z | +Y | +X |

Local +Z is the dorsum/back-of-hand side. With N the outward wall normal and T the stable tangent, construct bone-local world axes Z=N, Y=T projected perpendicular to N, X=Y cross Z, then orthonormalize. Consequently actual palm -Z faces -N and fingers +Y follow T. This is a proper right-handed basis; the mirrored thumb sides naturally face upward on their respective walls. The modeled palm offset is now (0,.0477,-.012) meters so depth follows the corrected palm sign. Clearance remains .05 m. No GLB, finger poses or skeleton assets were modified.

Per-hand rotation offsets are exposed in degrees and post-multiplied in local space after the geometric basis. Both defaults are **(0,0,0)**; no arbitrary 180-degree offset is needed to mask an incorrect mapping. Existing native arm IK and post-IK hand orientation order remains intact, including its approximate prepared-forearm bend guard. This is still not anatomical twist simulation.

## Slower staged reach

Inspector sections on EnvironmentalHandIK now group Environmental Hand Interaction / Reach and Contact Pose. Recommended defaults:

| Setting | Value |
| --- | --- |
| `hand_reach_total_duration` | .55 seconds (range .40-.80) |
| `hand_reach_prep_fraction` | .40 |
| `hand_rotation_start_fraction` | .35 |
| Contact position weight | .90 (preserved) |
| Contact rotation weight | .90 |
| Left / right rotation offsets | (0,0,0) degrees |
| Release duration / global cooldown | .22 / 1.75 seconds (unchanged) |

The existing REACHING state has lightweight internal/debug stages REACHING_PREP and REACHING_CONTACT; no new AnimationTree states. Position easing uses two smoothstep segments: 0 to .35/.90 over the prep fraction, then to 1 over the remaining approach. At default settings this gives positional authority about .35 at 40% progress, .76 at 80%, and .90 at completion before reach safety attenuation. The procedural target itself also eases; early Walk animation remains dominant. Rotation uses a separate smoothstep from the configured .35 start fraction to 1: no contact rotation before 35%, about .70 at 80%, and .90 at completion. This deliberately favors the requested delayed rotation over forcing .15 rotation at exactly 40% progress. No Curve resources were needed; duration, split, delay and final weights are Inspector controls.

The actual animated hand transform is captured once at acquisition, with a fixed body-relative copy. This prevents the walking character from leaving a frozen world-space start behind during the .55-second gesture. The target interpolates from that captured start toward the continuously updated wall endpoint, while procedural authority blends it with live animation. Plane-normal correction now follows the same staged approach rather than taking over early. The captured start is not resampled from each Walk frame. First prepared target is verified equal to the animated wrist. The old `hand_reach_in_duration` is a compatibility alias to total duration.

## Tangent continuity, Idle and release

T starts from horizontal velocity projected onto the raw wall-normal plane. At Idle/low speed, fallback order is last tangent projected onto that plane, projected character forward, then world UP cross N. Near-horizontal surfaces are already excluded by existing sensing. If a new tangent opposes the old one, negate it to preserve sign. Remaining angular changes are bounded to 300 degrees/second and the frame is reconstructed orthonormally. This prioritizes continuity over instantly pointing the fingers backward on reversed travel.

Walk -> Idle preserves the tangent and established wrist reference, preventing Walk/Idle wrist cycling from reasserting itself. Idle -> Walk resumes the same contact without restarting staging. Actual reverse input can invoke the existing locomotion turn action and release the contact normally; it does not force the hand to remain attached through a turn. Release/cooldown rules, eligibility, side selection, loss grace and their timings are unchanged.

F11 shows prep/contact stage, normalized progress, prep fraction, separate weights, actual palm mapping and angular error. World-space local axes use X=red, Y=green, Z=blue on the solved hand and desired contact frame. Wall normal/tangent and desired palm/finger directions are also drawn. The orange palm direction is -Z, not the blue +Z axis.

## Tests and remaining limitations

Updated hand pose tests pass for both sides: 33 evaluated frames at 60 FPS (.55 seconds), both stages observed, prep authority <=.35, zero early rotation, fixed captured start, orthonormal basis, per-hand offset application, delayed rotation, stable long contact and Idle basis, no Idle-resume reacquisition, tangent reversal continuity, real reverse-input safe release, and unchanged smooth release/cooldown/action suppression. Measured established palm-normal errors: about **1.13 degrees left / 2.75 degrees right**; finger-tangent errors about **8.3 / 8.8 degrees** at .90 rotation authority. Left and right contact-pose renders were inspected in addition to headless tests; this is not a claim of interactive manual playtesting.

All four environmental hand suites pass, plus running-roll handoff, sprint roll and locked-roll realignment. The contact test now compares drag travel against configured walk speed rather than a hardcoded distance based on the old 4 m/s. Current user tuning is 2 m/s Free Walk (and 2 m/s locked forward Walk), preserved. Narrow-pillar/rough-wall tests permit an aborted prep instead of requiring full contact before a short target disappears. Uneven-wall case retained 38/75 active frames and conservatively released at a sharp corner, with the existing global cooldown.

Broader Player, Foot IK and StepSolver suites retain failures under current tuning. Running those same suites with EnvironmentalHandIK disabled produces the same failures (Player 4 assertions; Foot IK 3 traversal assertions; StepSolver 21 travel/threshold assertions). Several checks assume the former walking speed/fixed travel time. No movement or foot-system fixes were attempted in this scoped task. Existing root-certificate warning is unrelated.

Remaining limitations: source finger curl is untouched and can keep fingertips from reading as a perfectly flat hand; the palm is an approximate center/depth model, not mesh collision. Fixed body-relative start avoids world pinning but still blends with live shoulder/arm motion. Very short walls can disappear before the slower gesture settles. Sign continuity may retain the former finger direction during reverse movement, or locomotion may release for its normal turn action. The wrist/forearm guard remains approximate, not a full anatomical joint-limit system. No sensing, movement, StepSolver, Foot IK, lock-on, dodge/roll, camera or cooldown changes were made. Not committed or pushed.

# Environmental Hand Interaction Phase 4 (2026-09-06)

## Contact pose, reach and cooldown

`player_environment_hand_ik_v2.gd` now owns one explicit state machine:
`INACTIVE -> REACHING -> CONTACT <-> IDLE_HOLD -> RELEASING -> COOLDOWN -> INACTIVE`.
REACHING can also cancel directly to RELEASING; if walking stops during reach, it finishes into IDLE_HOLD. Only eligible Free Walk can acquire. The selected side remains locked through release completion. Existing Phase 3 persistence labels remain compatibility/debug labels; they are not a second state machine.

Recommended initial Inspector settings:

| Setting | Default |
| --- | --- |
| `environment_hand_contact_weight` / `environment_hand_position_weight` | .90; two names for the SAME positional value, not multiplied |
| `environment_hand_contact_rotation_weight` | .85, independent of position |
| `hand_reach_in_duration` | .30 seconds |
| `hand_release_duration` | .22 seconds |
| `hand_contact_reacquire_cooldown` | 1.75 seconds, GLOBAL to both arms |
| `hand_palm_clearance` | .05 m, unchanged |
| `hand_max_wrist_rotation` | 150 degrees; now the start of conservative prepared-forearm bend attenuation, not a global animation-to-wall rotation cap |
| Wall / Idle target follow | 12 / 5 per second, unchanged |

Legacy IK-weight API aliases the positional value. Old per-second reach/release-speed fields no longer drive transitions. Smoothstep `t*t*(3-2*t)` controls both duration-based fades. Reach stores the starting hand transform and updates the end transform against the moving wall each pose. Both the positional target and its authority ease in; native TwoBoneIK remains full influence on that blended target to avoid the old joint-angle wall-penetration arc. Palm normal separation approaches the clearance plane over the reach, rather than snapping to it at acquisition. Established contact maintains the plane independently of tangential animation contribution.

Release captures the actual blended target, pole and hand orientation in body-relative space. These blend back to the live animated pose, without a stale world-space wall pin or a first-frame switch to a different rotation source. Completion starts the global cooldown. Sensors may still report candidates while walking during cooldown, but neither side can acquire. No randomness is used. Existing probe-loss grace remains .15 seconds and does not release/cool down on a tolerated miss. Genuine surface loss, wall end, unsafe reach, body angle, sharp normal change, walking away, Run/Sprint, Lock-On, Dodge, Jump/Fall, incompatible actions or disabling the component release first, then cool down. Idle itself does neither.

## Verified rig axes and contact frame

Re-inspected runtime rest transforms of both hands in the current GLB. Middle1 lies at approximately local (0,9.533,0) imported units from the wrist: **+Y is the finger/hand long axis**. Index/Pinky X offsets mirror between sides; Thumb1 sits approximately +1.576/+1.574 units along Z. The current rig's palm-facing convention is **+Z on both hands**, also consistent with its rest-world downward palm direction. Skeleton world scale remains .01. No rig assets or fingers were changed.

Let N be the raw outward wall normal. T is horizontal motor velocity projected onto the wall plane, normalized. At low speed or Idle, preserve the previous tangent projected onto the current plane; if unavailable, use character forward projected onto the plane, then projected world up as a degeneracy fallback. Build an orthonormal frame with local Z = -N, Y = T, X = Y cross Z. Thus fingers follow drag direction and palm faces the wall, including when Idle stops movement.

The previous correction aligned only the palm normal and inherited the Walk wrist every frame. Phase 4 applies the wall frame in the existing post-IK hand modifier. During reach, the residual wrist reference eases toward the acquisition pose held in body space; established contact no longer inherits cyclic Walk wrist swings. Rotation authority .85 leaves a small stable residual, rather than a time-varying Walk residual. Shoulder/body animation and native upper-arm/forearm solving continue normally. Idle retains the tangent/reference and resuming Walk does not restart reach or cooldown.

Environmental elbow-pole longitudinal direction is now opposite the wall tangent, using the existing .10 m magnitude and .30 m outward / -.25 m vertical offsets. This avoids bending the forearm back against the desired finger direction. Shortest quaternion blending avoids unnecessary full rotations. A prepared target/pole forearm-direction estimate attenuates rotation when long-axis bend exceeds the configured threshold toward 180 degrees. This is an approximate inversion guard, **not anatomical forearm-twist limits**; no forearm torsion or finger overrides were added. Applying the old 90-degree cap to the global animated-hand/frame difference incorrectly preserved the wrong wrist pose, since that angle includes the pre-IK arm orientation.

## Verification and limitations

New `test_environment_hand_pose_v2.gd` covers mirrored .30-second acquisition, smoothstep progression/authority, established palm clearance, wall-frame orientation, Idle tangent preservation, same-contact resume, .22-second release, immediate-return cooldown with valid candidates, cooldown expiry, and Run/Lock/Dodge/Jump cancellation during REACHING. Updated Phase 2/3 tests isolate scenarios by allowing cooldown expiry and now expect a global cooldown before the opposite corridor hand can acquire. A deliberately shortened reach cap correctly releases instead of requiring a stale clamp flag. Rough-wall tests permit conservative release/cooldown instead of demanding rapid retouches.

Measured left/right reach: **18 evaluated frames at 60 FPS**. Established maximum palm-normal error about **25.85 / 24.21 degrees**, finger-tangent error **16.97 / 16.70 degrees**, with .85 rotation authority. Established long-wall modeled palm clearance remains approximately .050 m; Phase 3 test minimum .049988 / .050003 m. Walk -> Idle -> Walk preserves the acquisition count. Wall end and narrow pillar release; sharp-normal rejection remains; corridor opposite-hand acquisition waits for global cooldown. Uneven alternating blocks produced 28/75 active frames before conservative unsafe-reach release, now intentionally followed by cooldown rather than repeated grabbing.

Ten targeted suites pass: environmental hand pose/contact/IK/sensing; player; Foot IK; StepSolver; running-roll handoff; sprint roll; locked-roll realignment. Deterministic headless tests and an inspected rendered Idle-hold image were used, not manual interactive playtesting. The engine's unrelated root-certificate-store warning persists. This does not claim every historical test in the repository passes.

F11 adds explicit state, reach progress, positional/rotation authority, cooldown time, acquisition eligibility, wall tangent, palm axis and normal-angle error. Existing debug geometry adds tangent, animated hand long axis, blended target, final target and palm direction.

Limitations: .85 rotation deliberately leaves residual angular error; tune toward 1.0 for stricter palm alignment. The palm center/depth remains an approximation, not hand-mesh collision, so unusually curled source fingers still need visual review. A reach starting with an already penetrating animated hand eases out rather than teleporting to clearance. Small pillars can cancel before a .30-second reach completes. Sharp/rough edges intentionally release and can leave hands inactive for the full cooldown. Bend safety is approximate, not anatomical twist solving. No simultaneous hands, finger IK, torso lean, collision physics or random gesture scheduling was introduced.

Movement, StepSolver, Foot IK/grounding, lock-on, dodge, roll traversal and camera scripts hash-match the prior committed versions. Surface sensing architecture/script and all tuned movement values remain untouched in this phase. Changes are not committed or pushed by this implementation task.

# V2 — Environmental Hand Interaction Phase 3 (2026-09-06)

## Palm contact model and penetration diagnosis

Phase 2 targeted a **wrist bone**, not the visible palm, using Phase 1's .025 m offset and no surface orientation. Rest-pose inspection confirms both hands use local **+Y toward fingers**, with Middle1 about **9.533 cm** from the wrist and a mirrored X spread across Index/Pinky. Both share the same palm-facing +Z convention, so no asymmetric clearance was needed. A second reproduced problem was native **joint-angle influence blending**: the wrist followed an arc that could enter the wall even with a target outside it. The initial Phase 3 test measured modeled palm penetration of roughly 6 cm before correcting that blend path.

New shared settings on EnvironmentalHandIK:

| Setting | Default |
| --- | --- |
| `hand_palm_clearance` | .050 m; Inspector range .03–.10 |
| `hand_palm_local_offset` | (0, .0477, .012) meters in hand-local axes |
| `hand_surface_rotation_weight` | .80 |
| `hand_max_wrist_rotation` | 90 degrees before rotation-weight scaling |
| `hand_wall_drag_follow_speed` | 12 /second |
| `hand_idle_hold_follow_speed` | 5 /second |
| `hand_contact_release_speed` | 9 weight units/second |
| `hand_contact_max_body_angle` | 75 degrees from the selected outward side |
| `hand_max_surface_normal_change` | 45 degrees |
| Phase 1 `hand_target_loss_grace_time` | .15 seconds |

The .0477 m local offset is half the measured wrist-to-middle-knuckle distance; .012 m is an exposed initial palm-depth allowance, not a mesh collision model. Local meter offsets are transformed with an orthonormal hand basis, respecting the imported skeleton's .01 scale without multiplying the offsets twice. This is shared for both hands. Phase 1's `.025` probe offset remains useful for sensing; Phase 3 builds its own palm target from the raw hit and does **not** add the two clearances together.

Palm center target = hit + normal × clearance. The wrist goal subtracts the oriented palm-local offset. Rotation turns local palm +Z approximately toward the negative surface normal using a shortest-axis correction capped to 90 degrees and scaled by .80; it fades with reach authority. No finger/forearm torsion writes or finger IK are added. Wrist orientation is applied by the final hand modifier after the native two-bone solve.

To avoid the penetrating joint-blend arc, the existing .75 reach weight now blends the **target position and elbow-pole position**, while the native solver runs at full influence whenever that blended target is active. This retains animated tangential motion while preserving segment lengths. Normal separation eases from the animated hand toward the clearance plane as reach weight rises, never requesting a position behind that plane. At established weight the palm target's normal separation is exact; rotation uses the matching basis for wrist compensation. Release returns the blended target to the animated hand with the previous body-relative offset, not a stale wall pin. Effective arm reach and unsafe shoulder/vertical limits still release contact instead of stretching. Native solver influence is therefore no longer itself the user-facing reach-weight value.

## Contact state and Idle hold

`environment_hand_contact_active` records contact authority; `active_side`, `contact_surface`, `contact_world_position`, `contact_hit_position`, `contact_surface_normal`, `contact_initial_normal`, and `contact_acquired_while_walking` record its context. Debug persistence is WALL_DRAG / IDLE_HOLD / RELEASING / NONE.

Acquisition is strictly grounded eligible **Free Walk**, using the existing Phase 1 best-side choice. **Idle never acquires contact.** An active contact retains the same hand until release, ignoring later score differences. Legacy Phase 2 switch-margin and blend-out fields remain non-exported compatibility fields; use contact release speed now.

Phase 1 `sample(delta, held_side)` may validate only that existing side in Idle; it does not query/acquire the other hand. The normal no-argument Phase 1 API remains walking-only. All action/ground/lock/speed checks apply before the Idle-hold exception. Camera orbit is irrelevant because probe directions use VisualRoot/body orientation, not camera yaw. Returning Idle → Walk along the wall retains the contact and its acquisition count.

Wall drag follows live hit positions rather than a fixed world point. It exponentially smooths position at 12/s during walking and 5/s during Idle, then reprojects onto the latest raw collision plane at the configured clearance. Raw normals keep plane separation exact; tangent speed is diagnostic only, not a movement/physics input. Coplanar collider seams can continue one contact. Cumulative normal change from acquisition and per-hit normal change are bounded, so a pillar cannot gradually twist the arm all the way around it.

Release occurs for invalid/deleted surface, expired hit grace, reach/side/behind-body violation, body angle >75 degrees, normal change >45 degrees, Run/Sprint, Lock-On, Dodge, Jump/Fall/Land, traversal or other non-locomotion action, or disabled component. A mixer-applied boundary check revokes contact immediately when an incompatible action is evaluated, since Godot may defer the modifier pass; IK then fades at 9/s. It adds no query or second skeleton advance. Grace is only for missing surface samples while otherwise safe, never a delay before action suppression.

## Results, debug and limitations

`test_environment_hand_contact_v2.gd` passes: no Idle acquisition, long left/right drag without world locking, clearance-plane projection, modeled palm staying outside the wall, Inspector clearance changes during hold, Walk → Idle → Walk without reacquisition, camera orbit preservation, walk-away release, Run/Lock/Dodge/Jump release, wall-end release, pillar pass and synthetic sharp-normal rejection, plus uneven-wall contact. Flat-wall minimum modeled palm distance was **.0499878 m** for a .05 m setting on both sides. Walking and Idle-hold renders were inspected; the hand is outside the wall rather than buried in it.

Uneven block test retained contact for **59/75 ticks**: sharp exposed block edges can trigger the deliberate corner-release policy, followed by walking reacquisition. This is safer than forcing the arm around every edge, but does not claim perfectly uninterrupted contact across rough geometry. The updated Phase 1/2 tests pass, as do six existing movement/Foot IK/StepSolver/roll suites. Older tests expecting Idle release were updated to the new explicitly requested behavior; Phase 1 grace test now derives its expiry from configuration.

F11 or the IK debug toggle shows contact active/acquired state, selected side, persistence, clearance versus modeled actual palm distance, normal, target and tangent speed. The environmental overlay replaces the base movement text while enabled so contact data fits. Geometry adds raw hit/normal and clearance target alongside the wrist IK target, poles and solved chains. Debug remains OFF by default.

Limitations: palm depth/center are calibrated approximations, not skinned-mesh collision. Arbitrary hand poses, finger curls and irregular surfaces still require visual testing; there is no finger placement, collision or fingertip tracing. Wrist rotation is bounded globally relative to the authored hand basis, not a full anatomical wrist/forearm joint-limit model. The .05 m setting is conservative and may look slightly separated from some surfaces. Rough corners may release briefly. Only static environment geometry is supported.

Before contextual objects, manually test both hands at .03–.07 clearance, with .80 rotation weight and current 12/5 follow rates. Tune the local palm-depth allowance conservatively for this mesh; do not reduce clearance solely to force contact on one frame. Validate unusual finger curls and corner cases before adding contextual touch points. No two-hand contact, body lean, hand physics, weapon interaction or movement changes.

Modified: `player_environment_hands_v2.gd`, `player_environment_hand_ik_v2.gd`, `player_environment_hand_modifier_v2.gd`, `player_debug_v2.gd`; updated `test_environment_hands_v2.gd`, `test_environment_hand_ik_v2.gd`; added `test_environment_hand_contact_v2.gd`; this document. Movement, StepSolver, FootGrounding, Foot IK/pelvis/planting and GLB/animation assets are unchanged. No Git commit/push.

# V2 — Environmental Hand Interaction Phase 2 (2026-09-06)

`PlayerV2/EnvironmentalHandIK` now consumes Phase 1 candidates and blends **one arm at a time** toward the selected smoothed target. No new physics probes, movement changes, fingers, palm-normal orientation, torso lean, combat reach or world-space wall lock.

## Solver and update architecture

Uses native `TwoBoneIK3D`, matching the existing leg IK architecture. Verified chains are `mixamorig_LeftArm → mixamorig_LeftForeArm → mixamorig_LeftHand` and `mixamorig_RightArm → mixamorig_RightForeArm → mixamorig_RightHand`; parent relationships are checked at binding. Shoulder/clavicle and torso are excluded. The existing .01 world skeleton scale is respected by world-space pose conversion.

Two lightweight `SkeletonModifier3D` instances bracket the native arm solvers: preparation reads evaluated animation and Phase 1 targets, then a read-only capture records solved positions. These are appended after the existing pelvis/leg/ankle modifiers. **The existing Foot IK owner still advances the skeleton exactly once; no callback-mode change or second advance is added.** Foot IK scripts/parameters are untouched.

When bound, Phase 1's automatic physics callback is disabled and its existing `sample(delta)` is called once inside arm preparation. This places shoulder-level sensing after the existing lower-body modifiers and before arm rotations, with two queries per eligible evaluated pose and no duplicate probes. If the IK component is removed, sensing's autonomous callback is restored. Disabling IK via its `enabled` property still permits Phase 1 sensing/debug and smoothly releases its influence.

## Hand selection and safety

If only one side is valid, choose it. If both are valid, higher proximity score wins (left wins a tie). Retain the active side until invalid or the alternative exceeds its score by **.20**. On a switch, completely fade the old arm to zero, then acquire the next on a following evaluated pose—never simultaneous influence. Corridor tests show no alternation with comparable scores. No persistent hand-contact lock or object wrapping exists.

The target is Phase 1's smoothed/offset position, without another surface query. Upper-arm/forearm lengths are measured in world space; prepared reach is clamped to `min(max_environment_hand_reach, .95 × measured chain length)`. Default configured maximum is **.60 m**, while this rig's ~.562 m chain yields an effective ~.534 m safety cap. Weight tapers from 85% to 98% of measured chain length. Targets crossing inward through the torso or outside the conservative vertical shoulder range receive zero desired influence. Segment-length tests verify no stretching. Phase 1 still limits acquisition to .50 m and applies its height/side/normal rules.

`LeftElbowPole` / `RightElbowPole` markers are body-facing-relative to the current upper-arm origin: **.10 m forward, .30 m outward, −.25 m vertical**. This favors a downward/outward elbow bend. Solvers affect only the three-bone arm chains, not clavicle or torso.

## Inspector defaults and orientation

| Setting | Default |
| --- | --- |
| Enabled | true |
| `environment_hand_ik_weight` | .75 |
| `hand_switch_score_margin` | .20 |
| `hand_reach_blend_in_speed` | 6.0 weight units/second |
| `hand_reach_blend_out_speed` | 9.0 weight units/second |
| `max_environment_hand_reach` | .60 m, further limited by measured chain |
| `elbow_pole_forward_offset` | .10 m |
| `elbow_pole_outward_offset` | .30 m |
| `elbow_pole_vertical_offset` | −.25 m |
| `environment_hand_ik_debug` | false |

Position solving only. No extra palm-normal rotation correction or `hand_surface_rotation_weight` control is added: there is no corresponding orientation solve to tune yet. The hand/fingers inherit the native arm result; finger bones are not individually solved or overridden. A partial weight retains animation contribution, so exact palm contact is not guaranteed or claimed.

The weight ramp is bounded `move_toward`, not a snap; full .75 influence takes approximately .125 seconds to acquire and .083 seconds to release at defaults. Phase 1's existing target smoothing is retained. During release the previous reach offset becomes shoulder/body-relative and fades away instead of pinning the hand to a stale world point during an action.

## State suppression / debug / validation

All Phase 1 eligibility remains authoritative: Idle, Run, Sprint, Locked, Dodge, Jump/Fall/Land and traversal/action states have no new reach authority. Invalid states initiate immediate fade-out, without waiting for Phase 1's target-loss grace. Reaching does not slow, freeze or steer gameplay. Run-roll handoff and current visible recovery remain unchanged.

F11 Phase 1 debug also displays arm diagnostics; alternatively enable EnvironmentalHandIK's own debug toggle. Overlay shows active side/switch state, validity/scores, per-arm weight/reach/clamped status and pole validity. Geometry: white animated hand, orange solved hand, magenta target, cyan elbow pole, green shoulder/elbow/hand segments. Debug is OFF by default. A rendered left-wall pose was inspected with .75 weight and ~.342 m target distance; the elbow remained bent and the other arm followed animation.

New `test_environment_hand_ik_v2.gd` passes left/right long-wall reach (67 sampled ticks above .2 weight out of 70), hand approaching target, inactive-arm animation preservation, no simultaneous weights, finite/no-stretch chains, no inward elbow flip, one sensing sample per pose, stable both-sided corridor, fade-before-side-switch on wall loss, Idle/Run/Lock/Dodge/Jump release, pillar acquisition/release, uneven-wall continuity, and a deliberately reduced reach-cap test. The cap assertion checks the prepared offset; final blended shoulder pose can differ by a few millimeters during native modifier evaluation. Phase 1 sensing suite and six existing suites (player, Foot IK, StepSolver, Run handoff, Sprint roll, locked realignment) also pass. Existing certificate-store warning remains environmental.

Known limits: this is a reach-following foundation, not polished wall dragging. Palm orientation/contact offsets still need authoring; unusual corners/rapid geometry changes can change targets; very short pillar passes may produce only a small reach. Position-only IK does not guarantee an anatomically ideal wrist angle from every camera view. The component currently relies on the V2 skeleton's existing modifier-update owner, not a standalone alternate rig. Future rigs must pass chain validation.

Before Phase 3, manually test both sides at multiple camera angles, start/stop, uneven surfaces and pillar passes. Begin with .75 weight, .20 margin and 6/9 ramps; lower weight toward .6 if the reach feels too assertive. Adjust elbow offsets conservatively before introducing palm orientation. Phase 3 may add deliberate contact persistence/release rules after this motion is accepted; none is implemented now.

Files changed: new `player_environment_hand_ik_v2.gd` and `player_environment_hand_modifier_v2.gd`; updated `player_v2.tscn` and `player_debug_v2.gd`; new `test/test_environment_hand_ik_v2.gd`; this document. Movement, StepSolver, FootGrounding, Foot IK/pelvis/planting source files and animation/GLB assets are unchanged. No Git commit/push.

# V2 — Environmental Hand Interaction Phase 1 (2026-09-06)

**Sensing only. No arm/hand/finger IK, bone overrides, animation changes, movement authority, attraction, or contextual interaction selection.** Dedicated `PlayerV2/EnvironmentalHandInteraction` contains `LeftHandProbe`, `RightHandProbe` (ShapeCast3D), `LeftHandTarget`, `RightHandTarget` (Marker3D), plus runtime debug geometry. Component physics priority 30 samples after motor 0 / animation controller 10 / AnimationTree 20, reading current evaluated bone poses in world space.

## Verified rig

Canonical skeleton: `PlayerV2/VisualRoot/MasterRig/Base Armature and Mesh/Skeleton3D`. Its effective world basis scale is .01; PlayerV2 and VisualRoot are unit scale, MasterRig has the existing 180-degree yaw correction. Exact bones (underscore, not colon):

| Side | Shoulder | Upper arm | Forearm | Hand |
| --- | --- | --- | --- | --- |
| Left | `mixamorig_LeftShoulder` | `mixamorig_LeftArm` | `mixamorig_LeftForeArm` | `mixamorig_LeftHand` |
| Right | `mixamorig_RightShoulder` | `mixamorig_RightArm` | `mixamorig_RightForeArm` | `mixamorig_RightHand` |

Both hands have Thumb/Index/Middle/Ring/Pinky chains numbered 1–4. Rest upper-arm-to-forearm and forearm-to-hand distances are approximately .278 m and .283 m in world units. `LOC_WALKING` is the current Free Walk clip, length 1.06666672229767 seconds. Actual evaluated walking probe origins in the test were approximately 1.33–1.34 m above floor. Origins use `LeftArm`/`RightArm` at the outer shoulder joint, not central clavicle or swinging hand. Skeleton global transform converts the imported units; lateral directions use VisualRoot local -X/+X, forward is -Z.

## Configuration and clean Phase 2 data

Inspector on EnvironmentalHandInteraction:

| Setting | Default |
| --- | --- |
| Enabled / debug | true / false |
| Reach distance | .50 m from upper-arm origin; raw and offset target both validated |
| Sphere radius | .08 m |
| Forward bias | .10 (dimensionless forward contribution to lateral direction) |
| Collision mask | 1: world/environment |
| Surface offset | .025 m outward along collision normal |
| Vertical limits from origin | -.40 to +.25 m |
| Maximum behind body | .15 m |
| Position smoothing | 14 /second, exponential |
| Normal smoothing | 12 /second, normalized exponential |
| Miss grace | .10 seconds |
| Maximum horizontal speed | 4.5 m/s (normal Walk is 4) |

The body and environment currently share layer/mask 1, so the body is explicitly excepted. Casts ignore Areas and accept StaticBody3D only; ancestry containing the player, queued deletion, or `lock_on_target`, `enemy`, `enemies`, `hitbox`, `weapon` groups is rejected. This excludes existing dummy helpers and non-static characters without requiring world tags. Vertical normals (absolute Y > .6), wrong-facing surfaces, excessive distance/height, behind-body and wrong-side contacts are rejected. No extra raycasts or physics queries: at most two manually updated sphere casts per eligible tick, none when ineligible. Sphere sweep endpoint can encounter geometry beyond nominal reach due radius, but actual contact distance validation enforces .50 m.

Both candidates independently expose `left/right_hand_surface_valid`, `...surface_position`, `...surface_normal`, `...target_position`, `...target_score`, and raw/smoothed target position aliases. `left/right_surface_normal` are also available. A lightweight per-side record additionally provides collider, origin, query endpoint, distance, provisional flag and reason. Score is simple 0–1 proximity, not hand selection. Target = contact + normal × offset; markers follow smoothed targets only while valid. Invalidating clears data/score and hides/resets markers. This is the read-only data boundary intended for Phase 2.

Position/normal interpolation occurs only on continuous hits to the same collider with compatible normals. New geometry or sharp normal changes seed fresh targets instead of interpolating across corners/gaps. Brief missing hits retain a provisional target only while still reachable, collider valid, and grace not expired. State loss, deleted/rejected collider or loss of reach clears immediately, with no grace carrying into an action.

## Eligibility and debug

Requires grounded Free WALK with meaningful movement input, actual speed above .1 and at most 4.5, outer animation Locomotion and grounded Loops. Run, Sprint, Idle, lock-on, active dodge or visible Run recovery, Jump/Fall/Land, non-loop action states, active StepSolver/RollTraversal and 180 turns invalidate both sides immediately and skip queries. Future action states must remain outside the explicit Locomotion/Loops allowlist. This component never changes those states or their configuration.

**F11** toggles `environment_hand_debug` (default OFF). Use **F3** to show the existing overlay if hidden. White crosses = origins; green/red cast lines and circular radius footprints = valid/invalid; yellow = contact/normal; cyan = raw target; magenta = smoothed target. Mesh vertices are world-space with an identity top-level transform. The overlay shows eligibility, query count, side validity, HIT/GRACE/rejection status, distance, score, target and normal. Both sides can report valid; no actual reach is selected.

## Hand Interaction Test Zone

New `PlayerV2Lab/HandInteractionTestZone`, west of the original floor: **X -55 to -31, Z -3 to 27**, connected at the western edge. Includes a long wall at X -36, opposite-side wall ending abruptly at X -40, segmented uneven stone-like wall at X -44, cylinder pillar near (-47,18), narrow rail at X -47/Z 9, and a 1.04 m interior corridor centered X -51. Walk within roughly .5 m of either upper-arm origin to inspect contacts. Existing lab lanes, StepSolver geometry and player spawn remain unchanged.

## Validation / limits / next phase

`test_environment_hands_v2.gd` passes: independent left/right wall hits (45/45 sampled walking ticks each), strict reach/normals, both-sided corridor, grace expiration, enemy rejection, every eligibility gate with zero extra queries, wall-end release, narrow pillar acquisition/release, distant-wall rejection, uneven-segment continuity, rail contact, floor rejection, deleted-collider release, and exact no-write assertions for every skeleton bone pose plus motor transform/velocity. Six existing suites also pass: player, StepSolver, Foot IK, locked roll realignment, Run handoff and Sprint roll. A rendered debug capture was inspected and corrected for world-space debug alignment; left-wall contact was about .36 m away, right invalid. Default Godot certificate-store warning is environmental and unchanged.

Limitations: two shoulder-level lateral casts do not search the entire vertical reach band; low furniture may not be found. Static geometry only; moving platforms/physics props are deliberately not supported. Continuous flat surfaces smooth well, but segmented objects seed new targets and curved corners may require future surface projection. Provisional grace retains a bounded world target, not a confirmed live contact. No hand/palm orientation or shoulder reach feasibility solve exists yet. Current collision layers are broad; a dedicated touchable-world layer is advisable before enemies/weapons proliferate.

Before Phase 2, manually walk the west-side zone with F11 at different camera angles, tune comfortable reach/height and inspect curved/segmented surfaces. Then design arm-length constraints, palm offset/orientation and single-hand selection/weight blending using these existing data outputs, without giving the system movement authority. Do not add IK until target behavior is accepted.

Files: new `Characters/Player/V2/player_environment_hands_v2.gd`, updated `player_v2.tscn` and `player_debug_v2.gd`; new `test/hand_interaction_zone_v2.gd` and `test/test_environment_hands_v2.gd`; updated `test/player_v2_lab.tscn` and this document. Movement controller, StepSolver, FootGrounding, Foot IK, pelvis/planting and animation scripts/assets are unchanged. No Git commit/push.

# V2 — Locked Dodge Facing Reacquisition (2026-09-06)

Yaw audit: `player_v2.gd` writes VisualRoot yaw toward captured direction while a moving dodge is active, then immediately selects `lock_on.face_target(delta)` after dodge completion. Normal facing was already exponential `lerp_angle` at rate 12, **not a literal hard target-yaw assignment**. At 60 Hz its first update consumes about 18.13% of the remaining error (~32.6 degrees from a 180-degree roll). That abrupt change of owner/large first angular step is the identified procedural source of snap-like recovery. Animation/grounded Locked code does not independently set VisualRoot yaw; the CharacterBody's target-relative input basis is separate from visual facing. No imported bone/clip edits were made.

`LockOnController` now owns a lightweight `lock_roll_realign_active`, elapsed time and start-facing vector. Motor captures dodge activity before evaluated-timeline completion, then requests recovery in the same control-return tick if locked and not jumping/starting another dodge. A facing error above the threshold starts recovery; Backstep follows the same actual-error check and ordinarily skips it. `face_target()` dispatches exclusively to bounded shortest-angle recovery OR existing normal facing, never both in one tick. Each recovery update queries the live LockOnPoint direction, not a captured target position.

Inspector: **LockOnController → Dodge Facing Recovery**:

| Setting | Default |
| --- | --- |
| `lock_roll_realign_start_angle` | 8 degrees |
| `lock_roll_realign_finish_angle` | 4 degrees |
| `lock_roll_realign_speed` | 450 degrees/second |
| `lock_roll_realign_delay` | 0.00 seconds |
| `lock_roll_realign_max_duration` | 0.30 seconds |

Default rotation is bounded to 7.5 degrees per 60 Hz motor tick. Completion/timeout only releases ownership, with no terminal yaw snap; the existing smooth normal facing takes over on the next tick. At 450 degrees/s a 180-degree recovery may hit the .30-second timeout first; normal exponential facing smoothly finishes the residual. Recommended initial tuning is the defaults, with speed 360–540 and delay 0–.08 available for playtesting. Delay consumes the same maximum-duration budget.

Movement never waits for facing: current target-relative combat input still drives movement, independent of VisualRoot yaw. Run control return and realignment begin at frame 59 (or after an already active safe lift completes). **The user's corrected visible Run recovery through frames 59–65 is preserved**, rather than reintroducing the obsolete animation cut at 59 mentioned in the task template. Walk roll starts recovery at its existing exit. Existing animation blends, Sprint constant velocity, movement tuning, IK, traversal and camera code are unchanged. Locked camera still targets LockOnPoint, not roll-facing yaw. Locked mode already excludes 180 turns/turn arcs, and regression tests assert that remains true.

Unlock, target invalidation/removal and distance break call `clear()`, which immediately cancels recovery. Jump or a new accepted dodge cancels it in the motor before yaw application. Normal action/facing rules resume; Free rolls never activate this state. Existing dodge-chaining restrictions remain intact.

F10 lock tuning or dodge debug now shows LOCK ROLL REALIGN active flag, facing error, thresholds, speed, elapsed/delay/maximum, target and yaw owner. New `test_lock_roll_realign_v2.gd` verifies bounded yaw across Walk/Run left/right/forward/backward/diagonal exits, continued strafe and changed input, frame-59 timing, live moving-target direction, aligned Backstep, small-error skip, delay, timeout without snap, invalid target/manual unlock, Jump and new-dodge cancellation. These are deterministic headless checks; visual feel still needs manual playtesting.

Files changed: `player_lock_on_v2.gd`, `player_v2.gd`, `player_debug_v2.gd`, new `test_lock_roll_realign_v2.gd`, and this document. No new animation state, camera architecture, root motion, turn animation or Git commit/push.

# V2 — Run Roll Buildup Reset / Sprint Exit Blend (2026-09-06)

A successfully started `DOD_RUN_TO_ROLL` now clears `_run_time`. It stays frozen during committed rolling and begins advancing again when current-input control returns at frame 59, using the unchanged four-second buildup duration. Sprint rolls retain eligible Sprint; Walk/Backstep and rejected dodge requests do not receive this reset.

Sprint has its own Inspector setting, Dodge resource → Sprint Roll → `sprint_roll_exit_blend`, initially **0.30 seconds** (previously shared Run's .20). This is a presentation-only longer crossfade into locomotion; full-clip constant Sprint-roll velocity, 100% source playback, traversal frames 9–24 and normal motor control remain unchanged. Run retains .20; Walk/Backstep and airborne Fall transitions retain their existing blends. Recommend playtesting .25–.35 seconds for visual feel; no claim of visual verification from headless tests.

Extended Sprint tests seed Run close to Sprint, verify timer reset and fresh Run recovery, verify Sprint eligibility preservation, and verify independent .30/.20 transition values including Run after Sprint. Targeted tests pass. No Git commit/push.

# V2 — Constant Sprint Roll Momentum (2026-09-06)

Sprint roll now commands its full existing roll speed (8 m/s by default) in the captured direction throughout the entire native clip, with no Run Curve slowdown/pause. Sprint exits at 100% instead of the shared .95 maximum, then retains the existing .20-second locomotion blend. Collision response and gravity still apply normally; this does not force the body through obstacles.

Sprint traversal initiation is restricted to source frames **9–24 inclusive** (0.30–0.80 seconds at 30 FPS). Debug uses the same centralized window selector. A previously validated lift may finish safely after the window closes, as before; no new lift can start outside it. Run remains 15–30; Walk remains 20–40. Run/Walk curves, animation timing and other tuning are unchanged. Sprint selection/full-duration constant motion and exact window-boundary tests pass, alongside Run handoff and traversal-window regressions. No Git commit/push.

# V2 — Sprint-only roll clip (2026-09-06)

Actual Free Sprint gait now selects `DOD_SPRINT_TO_ROLL` (verified imported duration **1.20000004768372 s**, 30 FPS). Shift-held Run during buildup still selects `DOD_RUN_TO_ROLL`; Walk remains `DOD_STAND_TO_ROLL`. Locked movement cannot select Sprint, and no-input Backstep is unchanged.

Sprint reuses existing Run/Sprint action plumbing, speed, normalized movement Curve, playback multiplier, .95 exit maximum, .20 exit blend and traversal frames 15–30. The runtime DodgeRun node receives the captured clip at each new action, including restoring the running clip after a Sprint roll. Sprint is prepared as a non-looping instance-local animation with the same horizontal root normalization as other rolls; imported GLB is untouched. Run-specific frame-59 control return/frame-65 visible recovery applies only to the running clip, not the shorter Sprint clip. Running and walking timing/behavior/tuning are unchanged.

Added `test_sprint_roll_v2.gd` covering Sprint/Run/Walk selection, native duration, non-looping playback, return to locomotion, Run-after-Sprint reset, Locked exclusion and no-input Backstep. Updated existing clip-selection expectations and kept the frame-59 suite scoped to Run. No Git commit/push.

# V2 — Run Roll Recovery Presentation Correction (2026-09-06)

Supersedes the early visual cut described below: frame **59 returns movement authority only**, while the unchanged Run roll continues playing its **59–65** recovery poses. Current input steers the CharacterBody and facing through the normal motor during this visible recovery; no input holds position. At evaluated source frame **65**, presentation begins the existing **0.20-second Run Roll Exit Blend** into current Idle/Walk/Run/Sprint or Locked locomotion. The source clip, playback rate and movement curves are untouched.

`run_roll_animation_exit_frame = 65` is a separate Inspector marker converted from actual clip length using the same 30 FPS source timing. `run_roll_recovery_visible` owns only presentation; `is_dodging` remains false after control returns. Evaluated playback continues advancing during recovery. New dodges cannot chain into this short presentation tail. Jump/airborne interrupts it normally; active ledge-lift deferral remains intact. The former `.08` `run_roll_handoff_blend_time` is retained as a non-exported compatibility field, no longer an active tuning setting. Tune the existing `.20` `run_roll_exit_blend` for the outgoing blend instead. The `.95` safety maximum still applies.

Updated deterministic handoff tests verify the actual DodgeRun state remains through source frames 59–65 while movement changes immediately at 59, followed by locomotion. Includes no input, 90/180 turns, Sprint, Locked, camera changes and .9/1/1.15 playback. No Git commit/push.

# V2 — Run Roll Input Handoff (2026-09-06)

Only `DOD_RUN_TO_ROLL` now returns control early. Its imported duration is **2.46666669845581 seconds** at the GLB import's **30 FPS**: approximately 74 frame intervals (timestamps 0 through 74, not an assumed 74-key count). No GLB, source clip, Curve asset, Stand/Walk roll, Backstep, movement speed, acceleration, gravity, camera, or IK tuning was changed.

Inspector: PlayerV2 → Dodge resource → Run/Sprint Roll:

- `run_roll_input_handoff_frame = 59`
- `run_roll_handoff_blend_time = 0.08` seconds; suggested manual range 0.05–0.15.
- Existing speed, playback multiplier and Curve remain editable.
- `run_roll_exit_progress = 0.95` remains the safety maximum when the marker is configured later. Its `.20`-second `run_roll_exit_blend` remains the fallback; ordinary frame-59 exits use `.08` instead.

At action start, normalized marker = `(handoff_frame / SOURCE_FPS) / actual Animation.length`. Default: **1.9666666667 source seconds / 2.46666669845581 = 0.797297287**, approximately **79.7297%**. Custom timeline length is source length / captured playback multiplier, so using evaluated AnimationTree progress aligns handoff to the same source frame at .9, 1.0 and 1.15 playback. The first motor tick after a pose reaches the marker returns control exactly once; no independent wall-clock timer and no extra idle motor tick.

Before 59, direction remains captured and the existing Curve controls translation. The frame-43 stop/43–59 settling section and saved 59–65 ramp are unchanged; the ramp is normally bypassed by handoff but remains available to the safety-exit path. No optional second frame-43 gameplay state was introduced.

On handoff, the same motor tick reads current camera-relative Free input or target-relative Locked input and executes ordinary acceleration/air control. Below the existing .15 meaningful-input threshold, grounded handoff enters Idle with no residual roll drift. Small-input suppression lasts only until meaningful input returns, not indefinitely through subsequent locomotion. Free uses its existing Idle; Locked remains locked and uses its existing `IDL_IDLE_D` destination. The Free locomotion blend target is set to current intent so the outgoing roll's .08 blend does not lead into a second stale-gait recovery blend.

Current Shift and existing Free buildup determine gait: eligible Sprint survives a direction change, releasing Shift restores Walk, and Locked remains Walk/Run only. A brief direction-based reorientation guard suppresses old-facing Run180/Walk180/turn-arc chaining while normal motor rotation catches up; it releases at the existing 35-degree arc-release angle (or no input/Locked). No turn rate or movement tuning changes. New current direction is authoritative throughout reorientation.

Rolls still persist across ledges and shallow recontact before handoff, without Land interrupting. If airborne at handoff, the existing Fall state and normal air control take over instead of Idle. Existing IK suppression ends with dodge and existing reacquisition blending resumes; no foot snapping or IK architecture changes.

If a validated RollTraversal correction is active at the marker, handoff waits for that existing collision-swept vertical correction to finish (or cancel through its existing safety checks). Horizontal roll recovery is held at zero while waiting, preventing a renewed captured-direction tail. The next motor tick returns current-input control; it enters Fall if still unsupported. No new lift starts outside the existing Run 15–30 / Walk 20–40 windows. The helper and its height/speed limits were not changed.

Debug adds evaluated source frame, configured marker/progress, control-return flag, pending-lift flag, current input and recorded handoff mode/gait/direction alongside existing Curve/captured-direction diagnostics. `handoff_this_tick` is a one-tick event; `run_roll_control_returned` persists for inspection until the next dodge begins.

Validation: new `test_run_roll_handoff_v2.gd` passes no input/subthreshold input, same direction, 90/180-degree changes, Sprint 90/180 changes, Shift release, Locked left/Idle, camera rotation during roll, .9/1/1.15 playback, 1 m recontact, 60 m airborne exit, and a real validated .7 m lift whose evaluated pose is advanced to frame 59 to deliberately force overlap. Both direction-change tests accelerate in the requested direction in the first handoff tick and show no pivot/arc chaining afterward. Existing Curve/frame-window suites deliberately configure a later marker to continue testing the preserved fallback tail; exit-blend suite verifies .08 normal, .20 fallback, unchanged .10 Stand/Backstep/Fall exits.

Full headless regression: **23/27 suites pass**. The same four previously documented failures remain: `test_idle_contact_v2` (reachable Idle sole contact), `test_foot_planting_v2` (Idle locks), `test_contact_refinement_v2` (terrain-error ratio), and `test_lock_on_v2` (old uniform-speed assertions conflicting with current directional speed tuning). No new failing suite; these unrelated issues were not modified. Godot's environment certificate-store warning is also unchanged.

Files changed: `player_dodge_v2.gd`, `player_v2.gd`, `player_animation_v2.gd`, `player_debug_v2.gd`, `test_run_roll_handoff_v2.gd`, `test_run_roll_exit_blend_v2.gd`, `test_dodge_curves_v2.gd`, `test_dodge_frame_windows_v2.gd`, and this document. No Git commit/push requested or performed. Visual feel still requires manual play testing; start with frame 59 / .08 seconds and adjust only the handoff blend within .05–.15 as needed.

# V2 — Roll traversal source-frame windows (2026-09-06)

New assist initiation is restricted to **Run/Sprint roll frames 15–30** and **Stand/Walk roll frames 20–40**, inclusive endpoints at the imported 30 fps. Source frame is evaluated dodge play position × captured playback multiplier × 30, so changing playback speed preserves source-frame alignment. Existing curve threshold, ground requirement and geometry validation still apply. A previously accepted bounded correction may finish after the window closes; it cannot initiate another lift outside the window. This prevents renewed traversal during the late Run momentum ramp.

Debug now shows evaluated source frame, selected window and open/closed state. Added test_roll_traversal_windows_v2 covering exact boundaries, out-of-window and late-recovery rejection, .9/1/1.15 playback, real playback acquisition and active-lift completion. Window, traversal, dodge frame-timing and run exit-blend suites pass. Traversal diagnostics now separate assist-only rise from subsequent CharacterBody collision response: pressed-against-ledge Run cases produced total rises .1399/.1374 m, of which .1197/.1242 m were assist. The assist stayed below its 8 m/s cap, with no positive launch velocity; no motor/physics tuning was changed to mask contact correction.

No changes to ordinary locomotion, dodge Curves, airborne persistence, Backstep or exit blending. No Git commit/push performed.

# V2 Phase 4B.3 — Roll Traversal (2026-09-06)

## Persistent grounded-start rolls

Moving rolls (`DodgeStand` / `DodgeRun`) now remain active through floor loss and recontact until their existing evaluated animation exit. `dodge.is_rolling()` centralizes that distinction; `dodge_airborne` reports current physical floor loss while rolling. Grounded start checks remain unchanged: no aerial dodge. Backstep retains its old floor-loss cancellation and receives no 70 cm assist.

Normal gravity/fall-speed limits continue during unassisted airborne rolls. Horizontal velocity still comes exclusively from captured direction × existing speed × existing Curve. Active Roll has full-body priority over Fall and Land; recontact does not count as ordinary landing or trigger sink inside the action. At roll completion, grounded returns to current locomotion mode; airborne enters existing AIR_FALLING_IDLE directly, then ordinary landing logic handles subsequent contact. No hard-land/fall damage or new landing clip.

Existing Foot IK/pelvis suppression and knee/plant gating already cover active dodge, so no IK architecture/configuration changes were needed. All movement Curves, including run frame 43 stop and 59–65 ramp, remain unchanged, as do base speeds, Backstep trim, and .20-second run-roll exit blend.

## Dedicated RollTraversal component

New `PlayerV2/RollTraversal` uses `player_roll_traversal_v2.gd`, a separate instance inheriting the existing StepSolver's support checks, capsule sweeps, bounded smoothstep lift, and debug renderer. The ordinary StepSolver script and its **0.35 m** setting are untouched; no temporary mutation of the normal instance occurs.

Inspector **RollTraversal → Roll Traversal**:

| Setting | Default |
| --- | --- |
| roll_max_step_height | 0.70 m |
| roll_step_up_speed | 8.0 m/s maximum vertical correction |
| roll_step_forward_check_distance | 0.45 m beyond capsule radius |
| roll_step_min_curve_value | 0.20 (must exceed this to start) |

New lift validity:

1. Moving roll active (not Backstep), nonzero horizontal movement, curve > .20, and actual floor contact with a walkable floor-reference probe. New assists are not acquired in free flight.
2. Requested horizontal motion agrees with captured dodge direction (dot > .99). Forward low probe reaches radius + .45 m; it must hit an opposing, non-walkable face ahead (normal dot direction <= -.25), not a nearby side/slope.
3. A downward top probe finds a walkable surface. Height relative to actual floor is at least .025 m and no more than .70 m plus 2 mm numerical tolerance.
4. Reused support validation requires center support plus at least 6/8 samples of the inner capsule footprint (radius × .6), testing two centerline insets. Thin rails/unsafe narrow tops are rejected.
5. Actual capsule overlap queries must clear both raised starting position and destination. CharacterBody test_move sweeps must clear the vertical lift and raised horizontal path. This rejects ceilings/overhangs and blocked destination bodies.

Accepted lift uses the existing smoothstep correction through `move_and_collide`, bounded per tick to configured lift speed; never assigns body position or bypasses collision. During this short, validated assist only, its swept correction owns vertical motion and snap is disabled; positive launch velocity is not stored. Free airborne rolls outside an assist keep normal gravity. Horizontal Curve motion is never replaced or steered.

Support and clearance are rechecked while active. A started correction may finish if the curve drops below threshold or action exits, but cannot start anew during zero-motion recovery. It terminates at verified height, on support/clearance loss, disable, or a .4 s safety timeout. It does not hover indefinitely waiting for forward input to reach a cached point. A player who stops short of the top can fall back naturally after the bounded lift ends.

## Debug / tests / limitations

Enable the Dodge debug checkbox for numeric Roll Traversal status, or RollTraversal's Debug Steps for reused accepted/rejected probe lines, hits and a destination body-envelope wireframe. Actual clearance tests use the full capsule. Numeric fields include airborne state, vertical velocity, progress/curve, candidate height, top/support/clearance, direction match, active state and target Y. F3 still controls debug-panel visibility. Camera architecture unchanged.

`test_roll_traversal_v2.gd` results for BOTH Stand and Run rolls:

- 30 / 50 / 70 cm: accepted and reached top with bounded per-frame rise.
- 75 / 80 cm and full 4 m wall: rejected with no lift.
- 70 cm with low ceiling or .25 m-wide top: rejected.
- 20 cm / 1 m drops: roll retained; 1 m drops recontacted during roll without Land interruption. Existing floor snap can keep a slow 20 cm descent grounded, which is intentionally unchanged.
- 60 m platform: gravity continued during roll; exit while airborne selected Fall. Further ALT in flight rejected.
- Existing six-step lane: six bounded assists, reaching 1.2 m top for both roll types without launch; IK remained finite.
- Locked left-tangent 70 cm curb: climbed using captured strafe, target/heading relationship and camera framing retained, no large per-frame camera position jump. Rendered locked ascent/top views inspected.
- Backstep/ordinary locomotion against 70 cm obstacle: no special lift; ordinary max remains .35 m. Side-only elevated surface gives no upward vacuum.
- Zero curve blocks new acquisition; an accepted lift can finish with zero curve; deleting support mid-lift cancels to gravity.

Full V2 regression: **21/25 pass**. Remaining failures are the previously known idle_contact, foot_planting, contact_refinement, and lock_on hardcoded uniform-speed expectations. The old run-roll exit-blend test now expects roll persistence before eventual Fall and still verifies the .10-second airborne handoff blend. No script errors.

Recommended initial tuning: retain .70 / 8.0 / .45 / .20. If lift feels too abrupt in manual play, try 6 m/s before changing detection distance; lower the max if level geometry should constrain rolls more. This is a grounded-contact low-obstacle assist, not a mantle, aerial wall climb, moving-platform prediction, or guaranteed corner capture. The single forward face probe is conservative on glancing corners. Existing full-size upright capsule clearance is retained throughout roll. Snapshot/automated checks do not replace subjective camera/animation feel playtesting.

Files: added `Characters/Player/V2/player_roll_traversal_v2.gd` and `test/test_roll_traversal_v2.gd` (+ generated UIDs); updated player_v2.tscn, player_v2.gd, player_dodge_v2.gd, player_animation_v2.gd, player_debug_v2.gd, test_run_roll_exit_blend_v2.gd, and these notes. No ordinary StepSolver, IK, camera or Curve asset modifications. No Git commit/push performed.

# V2 — Run momentum ramp frames 59–65 (2026-09-06)

Updated only the run movement curve's recovery ramp: translation remains zero from frame 43 through frame 59, then smoothly scales from zero at 59 to full configured momentum at 65, remaining full through the existing exit. This replaces the earlier 65–70 ramp. Curve coordinates are 59/74 = .7972973 and 65/74 = .8783784; existing zero tangents ease the acceleration. Backstep, walking roll, base speeds and the .20-second exit blend are unchanged. Curve, frame-window and exit-blend tests cover the new timing at 1.0/.9 playback. No commit/push performed.

# V2 — Run-roll exit blend (2026-09-06)

Added Inspector `Dodge → Run/Sprint Roll → Run Roll Exit Blend`, default **0.20 seconds**. Only DodgeRun → Locomotion uses this presentation crossfade in Free/Locked mode. Backstep, walking roll and airborne handoff retain their existing .10-second blends. Movement curve frames 43/65, exit progress, base speeds and recovery/retrigger timers are unchanged. New test_run_roll_exit_blend_v2 and existing test_dodge_frame_windows_v2 both pass. No commit/push performed.

# V2 — Revised Backstep endpoint / Run pause and resume (2026-09-06)

Supersedes the frame-45 Backstep endpoint and frame-26 Run stop below. Backstep now retains original source frames **15–60** (0.5–2.0 s at the verified 30 fps), giving a 1.5-second runtime clip. Existing speed/profile and full trimmed-window exit remain unchanged; measured travel ~2.21 m.

Run/Sprint movement eases to zero at **frame 43** (1.4333 source seconds, 43/74 = 58.1081%), stays zero through **frame 65** (2.1667 s, 87.8378%), then resumes along the originally captured direction. Resume is a linear ramp from zero at frame 65 to full configured dodge speed at frame 70, retained through the existing exit (.95, approximately frame 70.3). This is resumed dodge movement, not an early handoff to normal controls. No hard speed snap; animation playback speed and exit rules unchanged. First-lobe points are at frames 0/.25, 4/.75, 9/1, 30/1, 36/.7, 40/.25, 43/0; later points 65/0, 70/1, 74/1.

Updated frame-window and curve tests verify the new trim against original poses, pause/resume at 1.0/.9 playback, held-input stationary pause, captured resumed direction, and no stored wall velocity during the pause. All four dodge suites pass. Walking roll, camera, lock-on, IK, StepSolver and base-speed tuning unchanged. No Git commit/push performed.

# V2 — Dodge frame timing adjustments (2026-09-06)

- Import frame rate verified at 30 fps; source frame timestamps use frame / 30 (frame 0 = time 0).
- Running/Sprinting roll movement curve now reaches zero at frame 26: 0.8667 source seconds, 26/74 = 0.351351 normalized source progress. Earlier movement-curve points were compressed proportionally to retain its acceleration/deceleration shape; base speed and animation playback are unchanged. Remaining recovery has zero translation. Stand/Walk roll is unchanged.
- Backstep's instance-local animation is sliced to original frames 15–45, inclusive endpoint poses: source 0.5–1.5 s, a one-second clip at 1x. All 31 authored 30 fps pose samples are retained, with no playback acceleration. Imported GLB/full action remain untouched. Exit defaults to 1.0 so it reaches frame 45 rather than cutting the trimmed window early.
- Backstep keeps its existing speed and movement-curve shape, evaluated over the trimmed action's normalized progress. This intentionally shortens travel to ~1.47 m at 5 m/s, with translation stopping at trimmed progress .60 and recovery continuing in place. Run/Sprint now travels ~5.69 m; no magnitude retuning performed.
- New test_dodge_frame_windows_v2 verifies sliced poses against the original source, one-second duration, and zero run motion after frame 26 at 1.0/.9 playback. Updated curve-default/timing tests. Existing dodge selection, general dodge and curve tests pass. No Git commit/push performed.

# V2 Phase 4B.2 — Dodge Movement Curves (2026-09-06)

Replaced the single shared exit-remapped `dodge_speed_curve` with three saved Curve assets. No saved scene/resource overrides of the old property existed. The earlier notes below describe historical behavior.

## Inspector and resources

Open `PlayerV2 → Dodge / Roll → Dodge`, then Backstep, Stand/Walk Roll, or Run/Sprint Roll. Each group contains its existing speed, playback and exit controls plus a graphically editable Movement Curve. Shared recovery/debug settings remain in their own group.

- `res://Characters/Player/V2/Curves/dodge_backstep_curve.tres` → `backstep_movement_curve`
- `res://Characters/Player/V2/Curves/dodge_stand_roll_curve.tres` → `stand_roll_movement_curve`
- `res://Characters/Player/V2/Curves/dodge_run_roll_curve.tres` → `run_roll_movement_curve` (also Sprint)

Saved assets are the source of defaults, not hardcoded production point arrays. At player startup, curves are copied per instance so runtime changes cannot mutate the reusable assets. A null field gets a duplicate of its corresponding default; assigned custom curves are preserved. Empty curves safely yield zero. Default graph range is 0–1.5 to allow modest overshoot; movement clamps only negative values, not values above 1.0.

Default points `(clip progress, movement multiplier)` use linear tangents:

| Curve | Points |
| --- | --- |
| Backstep | (0,0), (.10,.20), (.20,.75), (.30,1), (.42,.65), (.52,.20), (.60,0), (1,0) |
| Stand/Walk | (0,0), (.08,.45), (.18,.90), (.30,1), (.60,1), (.75,.55), (.85,.10), (.90,0), (1,0) |
| Run/Sprint | (0,.25), (.08,.75), (.18,1), (.60,1), (.72,.70), (.80,.25), (.86,0), (1,0) |

Base speeds preserved: Backstep 5.0, Stand/Walk 6.0, Run/Sprint 8.0 m/s. Playback remains 1.0 for all, exits remain .90 / .95 / .95. Input threshold, direction capture, rotation, lock-on/camera, recovery, collision, gravity, StepSolver and IK timing/architecture are unchanged.

## Timeline and zero-speed recovery

`AnimationTree.mixer_applied` reads the active dodge state's evaluated play position. Existing custom timeline length = imported source length / user playback multiplier. `dodge_progress = evaluated_position / timeline_length` therefore represents normalized full source-clip progress. Curves sample this directly; there is **no division by exit_progress**. Exit truncates the profile, it does not stretch it. Changing a playback multiplier before starting an action stretches clip and curve timing together; settings remain captured for that action as before.

The motor still overwrites horizontal velocity every active dodge tick with `captured_direction * base_speed * max(0, curve.sample(progress))`. Thus a zero curve explicitly sets X/Z velocity to zero; ordinary locomotion stays suppressed until existing completion rules allow exit. No previous speed is retained or banked against walls. Movement reads the last evaluated pose, so timing has normal one-physics-tick evaluation latency rather than a separate movement clock. Numeric debug distinguishes latest Clip Progress from Sampled Progress, and shows Curve Value, Effective Dodge Speed, direction, and actual horizontal velocity (including collision response).

Measured flat-ground defaults at 60 Hz / 1.0 playback: Backstep ~3.98 m (was ~9.54 m), Stand/Walk ~9.37 m, Run/Sprint ~13.80 m. Zero-speed visual recovery lasts approximately .80 s / .12 s / .22 s respectively before exit. Backstep stops at source progress .60; stand .90; run .86. At .9 playback all timing stretches by 1/.9; because base speed is unchanged, distance also increases proportionally. This is intended timing synchronization, not distance normalization.

## Designer workflow and limitations

- Too far overall: lower that type's Base Speed.
- Correct distance but movement lasts too long: move the curve's zero tail earlier, then retune speed if necessary.
- Run translation ends too early: extend the run curve's nonzero phase; do not change the other curves.
- Animation too fast/slow: adjust Playback Speed; movement timing follows automatically.
- Edit the saved Curve assets or assign a custom Curve in the corresponding Inspector field. No code change/custom graph UI needed. Edit local scene/resources for persistent changes, not only the running Remote inspector.
- These are the requested initial point profiles, not final per-pose artistic calibration. Long full-length roll clips still travel far at 6/8 m/s. Early exit before a nonzero part of a custom curve truncates it and resumes ordinary motor response; place a zero tail before the chosen exit when a planted recovery is desired.
- No root motion, displacement extraction, motion warping, event markers, stamina, immunity, attacks or chaining added.

Files: updated `player_dodge_v2.gd`, `player_v2.gd` (startup curve isolation only), `player_debug_v2.gd`, `test/test_dodge_v2.gd` (distance assertion accommodates shorter Backstep), and these notes. Added the three Curve assets and `test/test_dodge_curves_v2.gd` (+ UID).

Verification: curve suite passes saved default points, per-instance isolation, null fallbacks, type selection including Sprint, actual progress domain, .9 playback synchronization, no-input/held-input stationary recovery, custom early-zero profile, >1 overshoot, and wall-release no-launch checks. Existing dodge and locked-direction suites pass. Full V2 regression: 18/22 suites pass, with the same idle_contact, foot_planting, contact_refinement and lock_on uniform-speed expectation failures. Editor import and 120-frame main-scene smoke test completed without script errors. No Git commit/push performed.

# V2 — Dodge Selection + Locked Direction Refinement (2026-09-06)

Verified the imported Godot library before wiring: neutral backward dodge is exactly `DPD_DODING_BACK` (2.700 s). No weapon-specific action substituted. This section supersedes the stationary-roll and locked-roll-facing rules in the earlier foundation notes below.

- `dodge_movement_input_threshold=0.15`: below threshold selects BACKSTEP even with residual velocity or a Run/Sprint gait. At/above threshold selects `DOD_STAND_TO_ROLL` for Walk or `DOD_RUN_TO_ROLL` for Run/Sprint. Current Shift intent is respected on the trigger frame, including starting from rest. Source horizontal speed/gait/mode are captured for diagnostics.
- Free backstep captures character backward (`visual.global_basis.z`) without turning to that direction. Locked backstep captures away from target and retains existing target-facing.
- Moving locked direction uses the same combat basis as locomotion: `forward=lock_on.direction()`, `right=forward.cross(UP)`, then normalized `right*stick.x-forward*stick.y`. W moves toward, S away, A/D tangent left/right; diagonals have the same type-based speed. Direction and raw combat input/basis are captured once, not retargeted during action.
- The previous moving direction math already followed combat input; the visible bias was target-facing remaining active during lateral/backward rolls. Moving rolls now orient the visual toward captured travel in either mode using existing 20/s dodge yaw response. On locked exit the existing smooth face_target response resumes, without a snap. Backsteps never use travel-facing, even if input changes while active.
- Inspector `PlayerV2 → Dodge / Roll → Dodge`: new Backstep Speed **5.0 m/s**, Playback Speed **1.0**, Exit Progress **0.90**. Duration still follows evaluated clip timeline; same normalized speed curve and recovery used. Existing roll speeds, playback, curve, exits and recovery unchanged.
- At these suggested starting values the long source produces about **9.54 m** of backstep travel. This is not yet a tuned short hop: manually lower Backstep Speed if a short retreat is desired (e.g. 1.5–2.0 m/s gives roughly 2.9–3.8 m with the same clip/profile). Keep playback 1.0 initially. Input threshold 0.15 is the initial recommendation; raise toward 0.20 if small analog input unintentionally rolls.
- Lock targeting, camera/distance, combat movement speeds, locked Sprint prohibition, airborne handling, IK architecture and StepSolver are unchanged. Existing dodge suppression applies to Backstep too. Optional dodge debug now reports captured magnitude, source speed, raw combat input, direction, and target-relative forward/right.

Files: updated `Characters/Player/V2/player_dodge_v2.gd`, `player_v2.gd`, `player_animation_v2.gd`, `test/test_dodge_v2.gd`; added `test/test_dodge_selection_v2.gd` (+ UID); updated these notes. No GLB modifications.

Validation: both dodge suites pass, including ALT dispatch, momentum-release selection, threshold boundary, all locked cardinal/diagonal directions at both gaits, actual displacement (no toward-target bias), normalized speeds, travel-facing, captured input persistence, smooth exit-facing and camera target framing. Rendered Free Backstep and Locked lateral roll poses inspected. Full V2 regression: 17/21 suites pass; the same known idle_contact, foot_planting, contact_refinement and lock_on uniform-speed expectation failures remain. Editor import and 120-frame main-scene smoke test completed; no script errors. No commit/push requested.

# V2 Phase 4B.1 — Dodge Foundation (2026-09-06)

Ground-only committed roll, driven by CharacterBody3D physics and the evaluated AnimationTree clip timeline. Existing InputMap `dodge` already binds left ALT and is now consumed by V2 via `is_action_just_pressed`; no duplicate binding added. No root-motion extraction.

## Actions and direction

- Imported exact names verified: `DOD_STAND_TO_ROLL` (2.400 s), `DOD_RUN_TO_ROLL` (2.467 s). Idle/Walk use Stand; Run/Sprint use Run. Runtime instance-local clips are non-looping; Hips local X/Y translation is normalized using the existing rig convention, while authored vertical movement and rotations remain.
- One Resource, `PlayerV2.dodge`, owns configuration, captured clip/type, source gait/mode, direction, evaluated elapsed/progress, cooldown and recovery. No repeated ALT restart, buffering, aerial roll, or jump-cancel. Simultaneous grounded Jump + ALT gives Jump priority.
- Free input uses camera-relative requested direction; no input defaults to character forward. Free visual yaw approaches captured direction at 20/s, bypassing Walk180/Run180 and turn arcs.
- Locked input uses captured target-relative axes, with no-input default away from target. Existing target-facing continues; travel does not rotate the locked body. Lock and camera are not cleared or retargeted by dodge. Explicit unlock or normal invalid-target/range-break behavior still works, and current mode determines exit.

## Inspector: PlayerV2 → Dodge / Roll → Dodge

| Setting | Initial value |
| --- | --- |
| Stand Roll Speed | 6.0 m/s peak |
| Run Roll Speed | 8.0 m/s peak |
| Stand / Run Playback Speed | 1.0 / 1.0 |
| Stand / Run Exit Progress | 0.95 / 0.95 |
| Dodge Rotation Speed | 20/s |
| Dodge Recovery Time | 0.10 s |
| Dodge Retrigger Delay | 0.05 s |
| Debug Dodge | Off |

Inspector-editable Curve uses points (0,0), (.1,.8), (.25,1), (.7,1), (.9,.4), (1,0), with linear tangents. The curve spans the configured playable exit window, ensuring zero requested speed at early exit. Horizontal velocity is replaced with captured direction × peak speed × curve; ordinary acceleration does not run underneath. Collision, gravity and move_and_slide remain authoritative. Recovery is the outgoing animation crossfade with ordinary motor acceleration resuming immediately, not an additional movement lockout. Retrigger waits the greater of recovery and retrigger delay.

Source playback is only scaled by the explicitly selected playback multiplier; no arbitrary movement duration drives clip speed. At these starting values, measured flat stand travel is about 10.74 m over ~2.28 s, and run travel is expected around 14.7 m. These are long full-clip rolls, not a final short combat dodge tune. First playtest the supplied values, then lower the speed curve's plateau (e.g. 0.45–0.60 for roughly 5–6.5 m stand travel) or peak speed if needed. Keep playback at 1.0 initially; do not accelerate the clip to shorten displacement.

## Coordination and safety

- StepSolver automatic lift is suppressed/cancelled during the active roll. Ramps remain ordinary body collision; stairs may stop the roll. Existing solver resumes afterward. No geometry or solver tuning changed.
- Foot IK's existing fade-out targets zero, planting releases, pelvis target returns to zero, and knee stabilization is gated out by non-Locomotion presentation. Existing fade-in/confidence logic reacquires after exit; no permanent disable or tuning changes.
- Losing floor support cancels roll immediately and commits Fall; subsequent real landing uses existing Land behavior. Normal roll completion goes directly to Locomotion and does not count as landing or trigger sink. Collider stays upright/full-size; no roll-shaped collision or under-obstacle capability added.
- Free sprint buildup freezes during dodge if Shift and movement remain held; releasing either resets buildup. Normal gait rules resume on exit. Locked mode continues to forbid Sprint. No new sprint restoration mechanic.
- Inert hooks `dodge_invulnerable=false`, `dodge_stamina_cost=0.0`, and `can_cancel_attack_into_dodge=false` have no gameplay effect. No attacks, stamina consumption, immunity windows, chaining or weapon-specific clips implemented.
- Existing Free orbit, locked tracking, SpringArm collision, and wheel-distance preference are unchanged. Optional debug is enabled through the Dodge resource's `Debug Dodge` checkbox and appears in the existing debug canvas (F3).

## Verification and files

Added `player_dodge_v2.gd` and `test/test_dodge_v2.gd` (plus generated UIDs). Updated `player_v2.gd`, `player_animation_v2.gd`, `player_foot_ik_v2.gd`, `player_pelvis_ik_v2.gd`, `player_debug_v2.gd`, and these notes. No scene or InputMap edit needed.

All 20 V2 suites run: 16 pass; same known failures remain in idle_contact, foot_planting, contact_refinement, and lock_on's old uniform-speed expectations. No script errors. Dodge tests cover actual ALT dispatch, repeat/jump rejection, all source gaits and Sprint restoration, Free back direction/reversal priority, Locked cardinal/diagonal/no-input directions, target preservation, unlock during roll, animation-driven duration at 0.85x/1.15x, IK release, clean exit, walls, stairs and support-loss Fall handoff. Rendered stand-roll poses inspected at three points; subjective feel still needs manual playtesting, particularly roll distance and forward-roll presentation during lateral/backward locked travel.

No Git commit or push performed for Phase 4B.1.

# Corrected master rig / backward locomotion (2026-09-06)

Imported the desktop Blender Master Rig.glb (SHA256 9345D5BF993AF4DECA19461C2F1ED779457237440EDF66AB26D3896C8E480607). Previous binary backed up outside the project in Codex work/rig_backup_20260906_031339. Import settings retained.

- Updated Walk uses re-exported LOC_WALKING_BACKWARDS under its existing name.
- RunBack now uses LOC_RUNNING_BACKWARDS instead of the diagonal placeholder LOC_RUNNING_BACKWARDS_RIGHT.
- Export omits IDL_IDLE_A and IDL_IDLE_B. User authorized RAW fallback: all executable Idle A references, including legacy controller and integration-test references, now use IDL_IDLE_A_RAW. No executable Idle B references existed. Historical notes below remain historical. Combat Idle D remains unchanged.
- Added explicit backward Walk/Run blend-tree wiring assertions to test_lock_on_v2.gd. Movement, camera, and IK tuning unchanged.
- Godot import and 120-frame main-scene smoke test completed without script errors. All 19 V2 suites ran: 15 passed; remaining failures are the previously known idle-contact, idle-planting, terrain-refinement assertions and 10 hardcoded uniform-speed assertions in lock-on tests (directional speeds are user-tuned). New backward mapping assertions pass; no script errors in suite logs. This is automated compatibility verification, not a guarantee of visual animation quality.
- No commit or push performed.

# V2 — Mousewheel Camera Distance Levels (2026-09-06)

One shared player preference now drives Free and Locked camera distance. Inspector: **PlayerV2 / CameraRig / Camera Distance Levels**:

- `camera_distance_level`: integer **5**, clamped 1–10, ready for a future preference store (no save/load added).
- `camera_distance_min=2.0 m`, `camera_distance_max=6.5 m`.
- `camera_distance_smoothing=12 /s`, exponential approach of requested SpringArm length.
- `camera_distance_display_duration=5.0 s`.

Linear mapping: min + (max-min)*(level-1)/9. Defaults give 0.5 m per level: 1=2.0 m, **5=4.0 m**, 6=4.5 m, 10=6.5 m. Thus the default requested distance is now 4.0 m rather than the earlier 4.5 m. Min/max stay Inspector-tunable; invalid reversed ranges collapse to the safe minimum rather than invert the wheel direction. The old independent `distance` and `lock_camera_distance` exports were replaced, not left as competing distance authorities. Optional `lock_camera_distance_multiplier=1.0` scales the selected distance during lock, blended by the existing mode weight.

The existing camera `_unhandled_input` consumes pressed vertical wheel events before generic mouse-button capture: Up subtracts one level, Down adds one, with no wrap. A wheel event does not recapture a released cursor and already-handled UI scrolling does not reach the camera. Other orbit/F/gameplay controls remain intact. Level changes update the notification immediately, while requested SpringArm length approaches the newest target smoothly; collision hit length never writes the user's level. Startup initializes the selected distance without a notification.

UI: **PlayerV2/UI/CameraDistanceDisplay**, a viewport-anchored Label on a separate CanvasLayer. Text `Camera Distance: N`, top margin 20 and right margin 24 logical pixels, right aligned, mouse-ignore. It stays independent of F3/F10 debug visibility. Every actual level change (wheel or runtime Inspector) restarts a single countdown. After five seconds it hides; no fade added. Repeated input at a clamped endpoint is not a level change and does not refresh the timer. Anchor checks account for the project's canvas stretch mode: 1280x720, 1920x1080 and 800x600 window sizes all retain the top-right inset in logical canvas coordinates.

Free orbit and Locked target-facing/height/pitch behavior are unchanged. The SpringArm remains the only camera-distance placement authority; its existing mask, player exclusion, Free near-plane shape and Locked sphere sweep remain. Level 10 near a wall retracts via actual collision while the requested arm stays 6.5 m and level stays 10; removing the wall restores the selected distance. The optional multiplier defaults to one, so toggling lock cannot silently replace the chosen zoom. F10's default-off camera diagnostics now include selected level, target distance, requested arm length and collision length.

New `test/test_camera_distance_v2.gd` passes: real viewport wheel dispatch, direction/clamping, non-snapping distance response, newest UI value/timer restart/hide, free orbit independence, resolution anchoring, Free/Locked zoom endpoints, target framing, multiplier, wall retraction/restoration with preference preserved, unlock persistence and configurable min/max. Existing camera-tuning and core player suites pass. The old `test_lock_on_v2` has speed assertion failures because it still assumes all combat directions use 4/6 m/s: current user tuning is backward Walk **3.0**, strafe Walk **3.5**, backward Run **4.5**. Those movement values and the old test were left untouched by this zoom task. The previously documented Idle A contact issues were not modified. Rendered level 1 Free and level 10 Locked views inspected for framing and top-right notification. Recommended starting settings remain min 2.0/max 6.5/smoothing 12; raise minimum toward 2.5 if a future character mesh needs more close-camera clearance.

Changed this pass: `player_camera_v2.gd`, `player_v2.tscn` (UI only), new `test_camera_distance_v2.gd` (+UID), `test_lock_tuning_v2.gd` (assert selected distance instead of removed legacy distance property), and this document. No movement, targeting, animation, StepSolver, foot IK or pelvis edits. No settings menu, save system, shoulder/FOV/first-person features. No commit or push performed.

# V2 Phase 4A.2 — Locked Camera + Combat Locomotion Tuning (2026-09-06)

## Inspector guide and defaults

Select the V2 player instance, or edit its reusable scene for persistent defaults:

| Node / Inspector category | Controls and defaults |
| --- | --- |
| PlayerV2 / Lock-On Movement | `lock_walk_forward_speed`, `lock_walk_backward_speed`, `lock_walk_strafe_speed`: **4.0 m/s each** |
| PlayerV2 / Lock-On Movement | `lock_run_forward_speed`, `lock_run_backward_speed`, `lock_run_strafe_speed`: **6.0 m/s each** |
| PlayerV2 / Lock-On Movement | `lock_acceleration`, `lock_deceleration`: **0**, meaning inherit existing motor response |
| CameraRig / Lock-On Camera | `lock_camera_distance=4.5 m`, `lock_camera_height=2.0 m`, `lock_camera_target_height_bias=0.0 m` |
| CameraRig / Lock-On Camera | position smoothing **8/s**, rotation smoothing **12/s**, enter/exit blend times **0.25/0.25 s** |
| CameraRig / Lock-On Camera | target framing weight **0.65**, max pitch up/down **40/45 degrees** |
| AnimationController / Lock-On Animation Blending | mode enter/exit **0.15/0.15 s**, Idle-to-move / move-to-Idle **0.15/0.15 s** |
| AnimationController / Lock-On Animation Blending | Walk-to-Run / Run-to-Walk **0.20/0.20 s**, direction blend speed **15/s** |
| DebugCanvas | `lock_tuning_debug=false`; **F10** toggles the compact tuning overlay |

Physical speed defaults deliberately preserve 4A.1 rather than selecting final combat pacing. Suggested manual experiment: backward Walk **2.8**, strafe Walk **3.2**, backward Run **4.5**, strafe Run **5.0**, with forward Walk/Run left at **4.0/6.0**. These are suggestions, NOT saved defaults. Change one value at a time in the Inspector. Remote Inspector changes apply during that session; edit the scene/local Inspector to persist them.

## Locked camera architecture

Retains CameraRig -> YawPivot -> PitchPivot -> SpringArm3D -> Camera3D. No direct camera positioning bypasses SpringArm. Locked mode smooths a world-space follow anchor toward the player, owns yaw from the horizontal player/target relationship, and aims pitch toward `lerp(player chest at 1.55 m, LockOnPoint + target height bias, target weight)`. Height is the **arm pivot/anchor height**, not an exact camera lens height: pitching the arm also moves its endpoint vertically. Default height was raised from the first 1.7 m trial to **2.0 m** after rendered inspection showed excessive player-head occlusion of the dummy. The original global FOV remains unchanged.

Yaw/pitch use exponential response; the entry weight ramps smoothly over 0.25 s and rotation continues converging at the selected smoothing rate. Anchor position and arm distance blend between Free and Locked using that weight. Locked mouse motion is ignored. Unlock retains the current view angles (no return to a stale pre-lock yaw), immediately restores mouse input, and blends anchor/distance back over 0.25 s. Free sensitivity/pitch bounds/distance remain unchanged. Target loss uses the same exit path. Pitch limits avoid inversion with elevated targets; extremely close/high targets still require sensible framing values and may be constrained by collision/pitch limits.

Collision remains the existing SpringArm query with the existing mask, excluded player RID, and margin. A **0.12 m SphereShape3D** is selected only while Locked or blending out; Free's original shape (null = automatic camera near-plane shape) is restored afterward. The near-plane fixture initially put the lens origin ~2 mm into a wall even though the view plane was protected; increasing margin did not meaningfully fix it. The small sphere solved that origin-clearance issue without adding a new query system or touching body collision. In the wall fixture, requested arm length 4.5 m retracts to ~1.689 m; camera Z 17.679 remains clear of wall front Z 17.8. This is not a promise against every thin/fast-moving geometry case; normal camera-collision playtesting still applies. Godot [SpringArm documentation](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html) describes the retained shape-cast architecture.

## Movement and animation tuning

Directional physical speed is the weighted interpolation of longitudinal and strafe values, using abs(input.x)/(abs(input.x)+abs(input.y)); it never adds cardinal speeds. Motor input stays normalized/raw, and analog magnitude still scales the result once. Ground acceleration/turn response/deceleration inherit the existing values when overrides are zero. Positive overrides adjust locked ground acceleration/braking only; air control, free movement, lateral damping, jump/fall and StepSolver remain unchanged. No Sprint buildup or Sprint gait is introduced.

AnimationController exports the independent blend values. Mode settings update only edges into/out of the nested Locked node. Combat Idle/Walk/Run transitions capture their current blend on a request change and interpolate over the chosen duration; rapid toggles start from the current blend, not a reset pose. Physics reads `combat_input`; the animation object separately exposes `raw_combat_move_input` and smoothed `move_blend`. Direction smoothing changes only animation, not physical steering or speed. Runtime tests lower direction response to 1/s while showing immediate raw right input.

No optional playback-rate controls were added. No rate is calculated from CharacterBody speed. Existing cyclic directional phase synchronization is retained; solo clips remain at source speed. All previous canonical mappings, including the explicitly approved temporary `LOC_RUNNING_BACKWARDS_RIGHT`, remain unchanged. Mode transitions, Idle D, Walk/Run cardinal spaces and shared airborne architecture remain intact.

F10 / `lock_tuning_debug` (default OFF) replaces the ordinary HUD with a compact targeting/camera/movement/blend view: mode, distance/height/weight, collision length, physical target/actual speed, Run/Sprint state, raw/smoothed input, branch/clip and directional F/B/L/R weights. Weights are computed from the actual 2D space's triangulation and closest edge, not guessed from raw input; they are within-direction weights, before the separate Idle/Walk/Run blend.

## Validation and scope

New `test_lock_tuning_v2.gd` passes: entry displacement bounded, behind-player target focus, mouse suppression/restoration, 400-frame Run circle with target in a 1280x720 viewport (sample ~649,349), elevated/depressed targets and pitch limits, no stale-yaw reset on unlock, restoration of Free anchor/distance, real SpringArm wall collision, independent Inspector speed changes, diagonal interpolation, raw-vs-smoothed input, tunable Walk/Run duration, live mode-edge durations, and directional debug weights. Existing `test_lock_on_v2` passes with the new camera, including indefinite Shift, invalid targets, Sprint entry, jumps, and locked 20 cm stair traversal. Rendered Idle and Run circling checked for player/target framing; this is not exhaustive human motion-quality testing.

Full run: **15 suites pass, 3 existing Idle A-related suites fail** (Idle contact, Idle locks, contact-strength ratio). Same known failures as Phase 4A.1; no assertions weakened and no IK retuning. Main scene and editor import load without new script errors. Existing certificate-store and old canonical-lab recovery warnings remain unrelated.

Changed this pass: `player_camera_v2.gd`, `player_v2.gd`, `player_animation_v2.gd`, `player_grounded_animation_v2.gd`, `player_combat_animation_v2.gd`, `player_debug_v2.gd`, new `test/test_lock_tuning_v2.gd` (+UID), and this document. No StepSolver, foot probes/IK/planting/pelvis, body collision, target acquisition, animation assets, weapons/attacks/dodge, or Sprint-rule changes. No commit or push performed.

# V2 Phase 4A.1 — Lock-On Combat Locomotion (2026-09-06)

## Controls, target contract and lab

`lock_on` InputMap action uses physical F; the existing motor physics input boundary consumes its just-pressed state. F acquires a candidate or clears the current lock. Runtime `LockOnController` is a child of the reusable PlayerV2 scene, with FREE / LOCKED_ON modes. Target eligibility is a Node3D in group `lock_on_target`, with a direct Marker3D child named `LockOnPoint`. No target-dummy path is hardcoded in the controller. Removing the group or marker, queueing/freeing the target, or leaving range clears lock safely; target tree-exit also clears the reference immediately.

New reusable `res://test/lock_on_target_dummy.tscn`: orange capsule/base, chest marker at 1.4 m, F-key label; deliberately no collision/combat/AI. One instance at **(8, 0, 10)** in `player_v2_lab.tscn`, visible ahead-right from spawn (0, 0.1, 18), away from the main test lane. Existing terrain geometry is unchanged. Yellow chest reticle is owned by the locking player, follows LockOnPoint and faces the camera. Its unshaded/no-depth-test material keeps it visible inside the dummy mesh; it disappears on unlock. This is debug UI, not final occlusion-aware targeting art.

Inspector settings on LockOnController: acquisition **20 m**, acquisition half-angle **80 degrees** from horizontal camera forward, break distance **30 m**, rotation response **12 /s exponential**. Score is normalized angle + 0.25 * normalized distance, so centered candidates lead, with distance breaking similarly centered choices. Runtime break radius is at least acquisition radius. No line-of-sight rejection, target cycling, camera auto-orbit, or enemy-specific target API added.

## Movement and mode boundaries

Locked forward is normalized horizontal player-to-marker direction; right = forward cross world-up. Input uses right*x - forward*y, diagonals normalized. Body yaw smoothly follows target independently of camera orbit and velocity. At coincident horizontal positions use current body forward rather than a zero basis. A/D are tangential motion through the normal CharacterBody motor, not orbital position constraints.

No Shift: existing Walk **4 m/s**. Shift: existing Run end speed **6 m/s**, immediately requested without buildup; acceleration/deceleration remain existing values. Locked `_run_time` and published buildup stay zero, gait is only Walk/Run. Entering lock immediately cancels Sprint gait/buildup and any active/pending free 180; the next animation update removes any Free Sprint blend contribution even during the Free-to-Locked crossfade. The Locked animation branch contains no Sprint. Unlock begins normal Free buildup from zero rather than a hidden saved Sprint timer. Neither toggle writes velocity or body position; speed changes use the existing motor response. Free movement retains all tuned values and its previous camera-relative logic.

Locked input bypasses only free directional-arc/reversal initiation and travel-facing yaw; it does NOT use the global action/StepSolver suppression flag. StepSolver still receives target-relative horizontal motion and ordinary eligibility. Existing Jump/Fall/Land logic is retained: logical lock persists in air, yaw can track target, and landing returns to Locked. No special combat jumps. Stationary free-turn/pivot animation callbacks cannot overwrite locked target yaw because their coordinator is canceled and grounded Free actions are bypassed.

## Animation architecture and exact imported Actions

Preserved outer Locomotion / JumpStanding / JumpMoving / Fall / Land machine. Inside Locomotion: original Free `Loops` and action nodes plus dedicated `Locked` branch. This keeps existing ordinary-locomotion IK/planting hooks and recovery ownership intact. Locked uses a 1D Idle/Walk/Run blend (0/1/2), with four-cardinal 2D spaces under Walk and Run. Idle is separate, not embedded in direction spaces. Direction parameters use normalized combat input (+X right, +Y forward), exponentially filtered at 15/s; gait blends at 0.2 s. Grounded mode transition uses existing 0.15 s return blend into Free, 0.15 s turn blend into Locked. No per-frame animation restart or time seeking.

| Combat role | Actual imported Action |
| --- | --- |
| Idle | `IDL_IDLE_D` |
| Walk forward | `LOC_WALKING` |
| Walk back | `LOC_WALKING_BACKWARDS` |
| Walk left / right | `LOC_LEFT_STRAFE_WALKING` / `LOC_RIGHT_STRAFE_WALKING` |
| Run forward | `LOC_RUNNING_FOWARD_A` (existing rig spelling) |
| Run back, TEMPORARY | `LOC_RUNNING_BACKWARDS_RIGHT` |
| Run left / right | `LOC_LEFT_STRAFE` / `LOC_RIGHT_STRAFE` |

The requested `LOC_WALK_BACKWARDS`, `LOC_RUNNING_FORWARD_A`, and `LOC_RUNNING_BACKWARDS` are absent under those exact names. User authorized the existing backward-right run pending re-export. Replace **`player_combat_animation_v2.gd` -> `CLIPS.RunBack`** when the proper neutral backward action is imported; no state/motor change needed. No weapon-specific substitutions made.

All nine clips are checked at runtime, looped in the instance-local animation library and use the existing in-place hips-horizontal normalization/reference from Free Idle A. Authored vertical and bone rotation motion remain; source GLB is untouched. Directional spaces use `SYNC_MODE_CYCLIC_MUTABLE` (solo clips keep natural speed; mixed clips share normalized phase). Parent gait space stays independent because it has nested spaces and a separate Idle. See Godot's [BlendSpace2D sync documentation](https://docs.godotengine.org/en/stable/classes/class_animationnodeblendspace2d.html). No seams are hidden with source edits, seeks or root-motion hacks. Backward-right is knowingly not a true straight backpedal; source-loop/motion-quality playtesting remains appropriate after the replacement export.

## Debug and validation

V2 HUD adds LOCK-ON: mode, target name, marker distance, acquisition angle, combat gait/input, yaw error, Sprint Allowed, FREE/LOCKED branch and dominant combat clip (labeled directional blend). Existing air animation label remains visible. Camera script is unchanged. Rendered locked Idle D and Run-strafe poses/UI were inspected; reticle depth behavior was corrected after that visual check.

New `test/test_lock_on_v2.gd` passes: real parsed F-key input; group/marker acquisition; front/behind/range checks; centered-versus-near scoring with a second test-only dummy; all eight directions at 4/6 m/s; diagonal normalization; target-facing; indicator clear; camera orbit independence; loop resource/branch structure; 1000 Shift-strafe frames with no Sprint/buildup; lock while Sprinting; preservation of toggle velocity; cancel active Free Run180 and backpedal without retriggering; standing/moving locked jumps, Fall/Land return, playback recovery; target removal/freeing; and locked Walk/Run ascent of six existing 20 cm steps. Circling for 16.67 s (~two revolutions) measured radius 8.00 -> 8.60 m, maximum yaw error 3.95 degrees. Small outward integration drift is retained rather than adding prohibited orbit constraints.

Existing regression run: **13 pass, 3 fail**; new lock-on suite passes separately. Remaining failures are the committed Idle A baseline's Idle sole contact, both Idle-lock assertions, and contact-strength improvement ratio. The latter was explicitly repeated against committed 5b10bf4: both old/current runs give mean 0.0259134 -> 0.0163896 m, above the test's 0.60 ratio threshold. Tests were not weakened and IK was not retuned for combat. Other suites pass: motor, grounded animation, foot IK, pelvis, landing compression, pivots, arcs, recovery, passive fall, grounding, StepSolver, narrow steps, knees. Main scene loads without script errors; environment certificate-store warning remains unrelated.

StepSolver, FootGrounding, FootIK (including 40 cm Idle pelvis selection and knee guidance), planting, pelvis modifier, camera and reversal resource are byte-identical to committed 5b10bf4. Body capsule/physics settings and all existing motion exports are unchanged. Existing strafing/terrain contact imperfections are not solved in this foundation. Dummy can be walked through; acquisition/reticle can see through walls; no final lock camera, health, weapons, attacks, dodge, stamina, damage, target cycling, or AI.

Changed: `project.godot`; `player_v2.gd/.tscn`, `player_animation_state.gd`, `player_animation_v2.gd`, `player_grounded_animation_v2.gd`, `player_debug_v2.gd`; new `player_lock_on_v2.gd`, `player_combat_animation_v2.gd`; lab scene, new dummy scene and lock-on test; corresponding generated UIDs; this document. No commit or push performed for Phase 4A.1.

# V2 — Idle A Selection (2026-09-06)

User requested `IDL_IDLE_A` (not RAW), replacing `IDL_IDLE_B_RAW`. Verified the clip exists in the canonical GLB (8.3333 s). Updated primary Idle mapping, grounded hips-reference lookup and active blend-space node. No movement, crossfade, IK, pelvis or imported asset edits. Player and grounded-animation suites pass. Idle-contact suite reports one reachable-sole contact failure; planting suite reports both Idle-lock assertions failing with this different authored pose. Retained all existing tuning and test assertions; animation selection alone does not guarantee the previous Idle B contact results. See the latest test results before treating this as a stable IK checkpoint. No commit/push performed.

# V2 — Idle B RAW Selection (2026-09-06)

User requested the RAW version of the same active Idle letter. Verified both `IDL_IDLE_B` and `IDL_IDLE_B_RAW` exist in the canonical Blender Master Rig.glb. Switched the V2 primary Idle mapping, grounded blend-space Idle node and grounded hips reference lookup to `IDL_IDLE_B_RAW` (9.9667 s). Existing runtime looping/in-place normalization and all movement, crossfade, IK and pelvis settings remain unchanged; no imported animation data edited. Player, grounded animation, Idle contact and foot planting suites pass. Knee stability has one strict-threshold failure: the 25-degree UPHILL Walk fixture measures 5.53 mm inward deviation against its 5 mm assertion; downhill, diagonal, turning and stair checks pass. Left the test and IK tuning unchanged rather than broadening this animation-selection request. Changed `player_animation_v2.gd`, `player_grounded_animation_v2.gd` and this document. No commit/push performed.

# V2 — Downhill Walk Knee Stabilization (2026-09-06)

## Diagnosis and scope

Existing `LeftKneePole` / `RightKneePole` markers already feed native `TwoBoneIK3D` chains (UpLeg -> Leg -> Foot). They were positioned at the animated knee plus its projected bend vector times 0.6 m. That is an animation-derived plane, not an anatomical body-relative reference: a small inward component becomes a much larger medial bend when terrain IK flexes the leg. Below 15 mm bend magnitude the old fallback abruptly chooses body-forward. The existing "knee_stable" test only checks the solver agrees with its own pole, so it cannot detect an inward-pointing pole. New tests measure signed body-outward knee displacement from the hip-to-ankle axis using the FINAL modifier callback pose.

Reproduced with identical real physics/Walk cycles on generated ramps: old maximum support-phase medial deviation was 23.44 mm flat, 74.21 mm at 12 degrees, 106.82 mm at 25 degrees, 116.33 mm at 35 degrees, and 113.87 mm at 40 degrees. Pole-only correction removes the large downhill amplification without changing ankle destinations, pelvis or solver weights. Foot torsion is not implicated: PreserveAnimatedAnkles already restores authored ankle world orientation after both IK solvers. No normal alignment or artificial yaw was being applied. Existing reach/partial-weight limits do leave slope contact error, but no larger pelvis budget or IK attenuation was required to stabilize the knees.

## Pole implementation and tuning

Retained runtime hierarchy `PlayerV2/FootIKController/{LeftKneePole,RightKneePole}` and all native bone chains. Ordering remains animation -> probes/confidence -> pelvis lowering -> target/pole placement -> left/right solvers -> authored ankle orientation -> diagnostics. Only ordinary grounded moving Walk/Loops receives new guidance; Idle, Run, Sprint, air, land/actions and reversals keep the previous pole path exactly.

Inspector category **Walk Knee Stabilization**:

- `walk_knee_stabilization_enabled=true` is the A/B switch.
- `knee_pole_forward_offset=0.40 m` along VisualRoot -Z.
- `knee_pole_outward_offset=0.10 m` from each hip: left -X, right +X.
- `knee_pole_vertical_offset=0.00 m` relative to bounded animated knee-height reference, not the foot.
- `knee_pole_smoothing_speed=15 /s`: exponential smoothing of the hip-relative reference in body space (knee-height/tuning changes). Body translation and yaw are applied immediately, so poles cannot lag behind the body or cross sides during turns. This intentionally does not world-space low-pass character yaw.
- `walk_downhill_knee_stabilization_angle=25 degrees`, with smooth 20–30 degree strengthening. Reads existing ground normals; positive dot of horizontal movement and normal identifies descending motion, including diagonals. No new probes or gameplay slope limit.

Preferred target is hip plus body-basis local forward/outward/knee-height offsets. Blend from authored pole by smoothstep(0.1, 0.65, support confidence) times 0.65 on flat/uphill, approaching 1.0 on steep downhill. Below 0.1 support there is no additional guidance, and existing IK/swing release is unchanged. Near-straight (<15 mm projected bend) supporting legs use the preferred reference at full support strength rather than normalizing a tiny animation bend. Native 99.5% reach clamp remains. Modest outward offset was tested against solved knee displacement; maximum supporting outward displacement across the Walk ramp fixtures is ~4.7 cm, not a forced wide stance.

Walk downhill IK multiplier: **1.0 (no attenuation)**; ordinary Walk weight remains **0.95**. Pelvis multiplier: **1.0 (no additional attenuation)**; ordinary pelvis weight/cap remain 0.8 / 0.20 m. Idle max drop remains **0.40 m**, with all prior Idle settings untouched. No new foot-rotation constraints; authored orientation restoration is unchanged.

## Debug and verification

**F9** independently toggles knee geometry and KNEE IK overlay: colored hip/knee/ankle/pole crosses, limb segments, knee-to-pole line and left/right outward arrows; per-leg pole validity, slope degrees, support, guidance and IK multiplier. F8 retains existing foot/pelvis display. Knee diagnostics capture actual final hip/knee positions, not the skeleton's restored animation pose.

New `test/test_knee_stability_v2.gd` builds a test-only ramp (no live lab/terrain edits), drives all three gaits on 0/12/25/35/40 degree slopes, uphill/diagonal/turning Walk at 25 degrees, then descends actual 15/20 cm lab stairs. Supports `-- --baseline` to disable the new guidance and `-- --render-knee` for a rendered 25-degree comparison saved under user://. Waits for modifier completion before comparing support and solved bones.

Final Walk maximum medial deviation: flat **6.39 mm**, gentle downhill **15.82 mm**, 25/35 degrees **0 mm**, 40 degrees **0.63 mm**. Uphill/diagonal 25-degree samples: 0 mm; turning: 0.14 mm. Supporting knee forward direction stays positive. Both stair descents complete with stable bend planes and preserved limb lengths (180/164 supporting samples). No degenerate poles or limb extension observed. Run/Sprint baseline versus enabled metrics are identical across every slope. Flat Walk adds only modest guidance; rendered 25-degree before/after poses were inspected without an obvious wide-legged posture, but still require player motion-quality review.

All 15 existing suites plus the new knee suite pass. This includes Idle contact through 40 cm, foot planting/lock release, Jump/Fall recovery, pivots, turn arcs, StepSolver and narrow steps. Main-scene smoke check passes aside from the environment's existing certificate-store warning.

Known limitations: support thresholds are unchanged and swing remains animation-driven; this is not a hard anatomical knee-angle constraint or proof against all authored poses. Steep Walk support samples still show maximum ankle contact errors ~15.7–17.7 cm, essentially identical to baseline, due to existing correction/reach/influence budgets. Those limits were not relaxed to hide the error. The pole smoothing setting smooths the local reference, not world-space yaw; full-speed visual playtesting remains recommended.

Modified: `Characters/Player/V2/player_foot_ik_v2.gd`, `Characters/Player/V2/player_debug_v2.gd`, new `test/test_knee_stability_v2.gd`, and this document. Motor/capsule, StepSolver, grounding probes, planting architecture, pelvis modifier, ankle orientation and reversal scripts are hash-identical to committed 6000e49. No commit/push performed for this pass.

# V2 — Authorized 40 cm Idle Pelvis Budget (2026-09-06)

Supersedes the reach limitation documented in the previous Idle refinement below. User authorized increasing the Idle pelvis cap from 20 to 40 cm and retrying those tests.

New `FootIKController.idle_max_pelvis_drop=0.40 m` is separate from the unchanged moving `max_pelvis_drop=0.20 m`. `pelvis_drop_limit()` selects the appropriate target budget; debug displays the selected value. Idle weight remains 1.0, with 10/s exponential pelvis smoothing. Movement input immediately selects the original moving budget; the current offset recovers smoothly rather than snapping from 40 to 20 cm. Jump/Fall and the shared landing-sink budget remain intact.

At the exact 40 cm boundary, applying the 40 cm FOOT correction cap to the original ankle before lowering Hips left a ~7.4 mm residual despite adequate reach. For forced Idle support only, that cap now applies to the remaining vertical correction from the pelvis-corrected ankle. It stays at 40 cm, and native chain reach still caps the result. Horizontal limits and moving-gait target calculations are unchanged.

Repeated the previous frozen split-curb tests with the body at upper-surface height: both feet contact within **0.01 mm** numerical error at 10, 20, **25, 35 and 40 cm**. Actual pelvis drops are approximately 10.74, 20.74, 25.74, 35.74 and 40.00 cm respectively. Limb-length/knee checks pass; no bone stretching, CharacterBody displacement or collision changes. The 45 cm invalid-foot and both-valid over-limit cases remain safely excluded from forced support.

All **15 V2 suites pass**. Added assertions for residual Idle correction <=40 cm, full contact through 40 cm, and smooth recovery plus lock release when starting to walk from a 40 cm split. The pelvis test's frozen-pose bound now checks the selected budget; moving traversal checks retain their original 20 cm bound. The 25 cm rendered pose was inspected: lower-foot hover is removed and the upper knee bends to accommodate the drop. Extreme terrain naturally produces a deeper crouch; manual playtesting of its appearance is still recommended.

Changed this pass: `player_foot_ik_v2.gd`, `player_pelvis_ik_v2.gd`, `test_idle_contact_v2.gd`, `test_pelvis_ik_v2.gd`, and this document. Other Idle settings remain weight 1.0, max terrain delta 40 cm, max remaining vertical correction 40 cm. Idle confidence ignores sway; locks still release on invalid support, movement, airborne/actions or unsafe reach. Walk/Run/Sprint thresholds, StepSolver, motor, collision, Jump/Fall and 180-turn logic remain untouched. No commit or push performed.

# V2 — Idle Foot Contact Refinement (2026-09-06)

Idle-only support strengthening; the requested no-hover result is achieved for reachable poses, but is **not fully achieved at 25–40 cm with the body at the upper surface and the existing 20 cm pelvis-drop bound**. Reach protection is retained rather than stretching legs or silently increasing the pelvis limit.

## Diagnosis

The moving-foot heuristic was also used at rest. At a frozen 25 cm split, the lower animated ankle was ~25.7 cm above its terrain target; after the 16 cm weighted pelvis allowance, the height metric was ~9.7 cm, almost the top of the 5–10 cm confidence falloff. Lower-foot confidence collapsed to **0.0079**, also starving pelvis support. Its terrain error was **25.14 cm**, despite a valid ray. Idle sway velocities could independently weaken contact/release locks. Partial 0.95 IK, a global 20 cm vertical cap, and 0.8 pelvis influence added conservatism. The original 60 cm ray (including 20 cm elevated origin) also missed lower terrain in 35/40 cm high-body poses.

## Idle settings and rules

New Inspector category on FootIKController, **Idle Foot Contact**:

- `idle_ik_override_enabled=true` (comparison/fallback switch).
- `idle_foot_ik_weight=1.00`.
- `idle_max_terrain_height_delta=0.40 m`.
- `idle_max_foot_vertical_correction=0.40 m`.

Idle detection uses physically grounded, not airborne/jump-start, movement input <=0.01, horizontal speed <=0.1 m/s, and ordinary Locomotion/Loops with no active reversal. The gameplay gait enum has Walk/Run/Sprint but no Idle; these rest conditions match the actual Idle semantics. First movement input disables the override immediately, without waiting for acceleration.

For each valid Idle foot, raw support is **1.0**, independent of height/sway-speed heuristics, provided both valid terrain ankle targets differ by <=0.40 m (1 mm numerical tolerance). With only one valid target, that valid foot remains eligible; an invalid foot is never forced. When two valid targets exceed the limit, normal support/correction bounds apply. Existing confidence and IK interpolation are retained, including smooth transition from weight 1.0 to the lower moving-gait weights.

Eligible Idle feet use the 40 cm vertical correction cap; moving feet retain 20 cm vertical and 15 cm horizontal caps. Ankle sole offset stays 8 cm. Native 99.5% chain reach and original limb lengths are untouched. Idle pelvis influence is 1.0 rather than 0.8 so it can use the **full existing 20 cm max drop**, still downward-only and exponentially smoothed at 10/s. Moving pelvis influence remains 0.8; landing sink budget and architecture are unchanged. Debug now shows effective pelvis weight.

FootGrounding uses the same two rays, but Idle-only length is max(normal distance, origin height + sole offset + idle max delta + 3 cm), **0.71 m** with defaults. Walk/Run/Sprint retain the original **0.60 m** distance and all normal/validity checks. No extra queries. Debug ray lines reflect the actual cast length.

Idle locks do not release merely for vertical/horizontal animation sway or low heuristic confidence. They still release on invalid/lost terrain, movement entry, Jump/Fall, higher-priority action, teleport, disabled IK, or safe correction/reach limits. Idle separation checks account for the existing pelvis offset; chain and horizontal limits still apply. Leaving Idle clears its anchor contribution immediately while ordinary confidence/influence resumes smoothly. No changes to moving plant thresholds or ordinary moving lock-acquisition/release rules.

F8 adds Idle IK Override, per-foot Idle Forced Support, actual IK/contact error, terrain height delta and max delta.

## Tests and measured limits

Frozen Idle pose, body positioned at the upper surface, identical animation/terrain for each measurement:

| Height difference | New lower-foot contact error | Result |
| --- | --- | --- |
| Flat / 10 cm | <0.01 mm | Contact |
| 20 cm | <0.01 mm (previous ~27.2 mm) | Contact |
| 25 cm | **36.47 mm** (previous ~251.44 mm) | Full support, pelvis at limit; remaining reach gap |
| 35 cm | **136.00 mm** (previous lower ray invalid) | Detected and fully supported, safely reach-clamped |
| 40 cm | **185.80 mm** (previous lower ray invalid) | Boundary detected, full support, safely reach-clamped |
| 45 cm | Low ray invalid at full body height | Invalid foot excluded; valid upper foot supported |

Upper-foot errors were below 0.01 mm in these frozen fixtures. Both-valid 45 cm split at a lower body position separately confirms that neither foot receives forced support beyond the delta limit. Full confidence does not manufacture additional leg length. Eliminating the remaining high-body 25/35/40 cm gaps requires a separately authorized larger Idle pelvis budget or another change outside the present constraints. No such change was made.

`test_idle_contact_v2.gd` covers all listed heights, safe limb length/knee behavior, unchanged body transform, first-input release from 25 cm split Idle, smooth weight decay, normal moving correction/probe limits and immediate Jump release. Before/after rendered 25 cm poses were inspected: the large hover is substantially reduced, but the residual gap remains visible. This is not a claim of full manual movement-quality testing.

All **15 V2 regression suites pass**. `test_foot_planting_v2.gd` now checks no interpolation overshoot from incoming Idle weight and the existing settled gait bound after 30 frames, rather than rejecting the explicitly requested smooth 1.0-to-moving-weight transition. `test_contact_refinement_v2.gd` disables the new override to continue isolating its original global-weight comparison; the new Idle suite covers the override. Other moving planting, Jump/Fall, turns, broad/narrow step, stair, motor and sensing tests remain intact.

Files: modified `player_foot_ik_v2.gd`, `player_foot_planting_v2.gd`, `player_pelvis_ik_v2.gd`, `player_foot_grounding_v2.gd`, the two compatibility tests above, and this document; added `test_idle_contact_v2.gd` plus generated UID. No scene/geometry, CharacterBody, collision, movement-physics, StepSolver, Jump/Fall or 180-turn edits. StepSolver hash remains `E2659D3D736C987FD427BA6446E9223B15D502E970814ACA7DE8778BC861E23B`; scene/capsule hash remains `03B0356D25F0F015ACEF90E1A57B96F93D490A34FA42C6060DDF6A43695EE337`. No commit or push performed.

# V2 Phase 3B.4 — Foot Planting (2026-09-06)

Animation-aware per-foot support and bounded temporary world anchors, layered on the existing IK/pelvis implementation. This phase name is distinct from the earlier Git tag `0.3B.4`, which remains the pre-planting stable feet/pelvis checkpoint. The preceding narrow-step/contact refinement remains intact and uncommitted.

## Files and ownership

New `Characters/Player/V2/player_foot_planting_v2.gd` is a per-leg RefCounted state object owned by FootIKController. `player_foot_ik_v2.gd` exposes settings, updates planting from pre-IK animation, reuses confidence as leg support relevance, applies target locking before existing caps/reach solving, and extends F8 diagnostics. `player_pelvis_ik_v2.gd` now uses a planted anchor's height when locked; its existing `leg.swing` support input carries planting confidence. No pelvis architecture changes. New `test/test_foot_planting_v2.gd` exercises support phases, locks, edge loss, anchor changes, jumps, reversals and stairs.

Order remains AnimationTree/authored pose -> existing presentation and foot probes -> per-foot confidence/anchor preparation -> pelvis modifier -> native left/right IK (with per-foot effective influence) -> authored ankle-basis preservation. Velocity history is sampled only from ANIMATED, pre-modifier feet. No solved-pose feedback or accumulated bone offsets.

## Support confidence and velocity conventions

Animated ankle position is transformed into VisualRoot-local meter coordinates; finite differences provide vertical and horizontal motion with CharacterBody translation, step lift, visual landing sink and root rotation removed. The raw horizontal speed is displayed. Actual stride measurements showed backward stance motion around 1.6 m/s in Walk, 4 m/s in Run and 5 m/s in Sprint, so testing raw speed against 0.4 m/s would incorrectly reject support feet.

For movement, the horizontal swing metric is max(forward component along actual movement direction, 0, lateral speed). Backward stance motion is allowed; forward swing/lateral sweep is rejected. At rest, use raw relative horizontal speed. This uses root-relative animation motion, not world velocity alone, and introduces no authored clip markers or gait phase tables.

Height metric = max(0, animated root-relative sole lift, world ankle-to-terrain gap minus available pelvis drop). The pelvis allowance is the existing max drop times pelvis weight (0.16 m by default), or zero when pelvis is disabled. It permits a still foot above the lower stair to remain support-worthy without mistaking an actual lifted stride foot for support. This is a heuristic, not measured mesh contact.

Raw confidence = valid grounded state * height factor * absolute vertical-speed factor * horizontal-swing factor. Each factor is 1 below its threshold and smoothly falls to 0 at twice that threshold (`1-smoothstep(threshold, 2*threshold, value)`). Jump/airborne/invalid terrain produces zero. Dedicated non-loop presentation (including Land, RunStop and turns) caps raw confidence at 0.25 and disallows locks.

| FootIKController / Foot Planting setting | Default |
| --- | --- |
| foot_planting_enabled | true (false restores prior heuristic for comparison) |
| foot_lock_enabled | true |
| plant_height_threshold | 0.05 m |
| plant_max_vertical_speed | 0.30 m/s |
| plant_max_horizontal_speed | 0.40 m/s, forward/lateral swing metric while moving |
| plant_confidence_rise_speed | 15/s |
| plant_confidence_fall_speed | 20/s |
| foot_lock_threshold | 0.80 |
| foot_unlock_threshold | 0.45 |
| max_foot_lock_distance | 0.25 m |

Confidence is exponentially smoothed with separate rise/fall rates. Desired per-foot IK influence = base gait weight * confidence when terrain/body state is usable, else zero. Existing 10/s in / 12/s out IK interpolation remains, so displayed final weight is smoothed rather than the instantaneous product. Target correction is also attenuated by support relevance, preserving animation dominance in swing. Gait ceilings remain Idle/Walk 0.95, Run 0.80, Sprint 0.65. No movement or gait rules changed.

## Temporary lock behavior and limits

Acquire only when both smoothed and raw confidence reach 0.80, there is no meaningful upward/forward swing, and presentation is ordinary Locomotion/Loops. Capture the terrain ankle target and collider transform once. Anchor X/Z stays fixed; Y also remains on the OLD surface if the animated probe starts seeing the next stair. Target approach/release uses exponential blend 15/20 per second; native IK influence/correction/reach caps still apply. A locked marker does NOT imply an exactly immobile solved foot at partial IK influence.

Unlock below confidence 0.45, on upward speed >0.30 m/s, forward/lateral swing >0.40 m/s, invalid terrain, Jump/Fall, non-loop actions, zero/disabled IK, lost anchor support, excessive separation or chain reach. Maximum separation is 0.25 m, additionally constrained by the unchanged 0.15 m horizontal correction cap and 99.5% limb-reach bound. A reach-limited foot releases rather than stretching. Only one acquisition per support phase: after release, raw confidence must fall below 0.2 before rearming. This prevents repeated locking against the distance limit during the same stance. Teleports >0.75 m reset history/anchors/confidence; toggling planting resets its state.

Existing foot probes follow the animated ankle and cannot prove whether the OLD anchor still has support. Therefore a single additional short downward ray is used per currently locked foot (at most two additional rays per pose), with the same terrain mask, self-exclusion and walkable-normal requirement. It verifies the old collider/height. No extra casts when unlocked. Removing the anchor's collision releases it even when the animated ray still sees valid terrain elsewhere. World locks are limited to stationary StaticBody3D terrain: moving transforms and AnimatableBody3D are not pinned. Moving-platform-relative planting is not implemented.

Invalid/airborne/action anchors stop supplying world-space target corrections immediately; existing IK influence/current-pose-relative release still fades smoothly. Land first rebuilds light confidence/IK without locks, then ordinary locomotion can reacquire naturally. Walk180/Run180 and stationary turns cannot fight a retained lock. Existing landing sink budget, turn timing/carry, physics and input remain untouched.

Pelvis uses the same confidence/effective-foot-weight relevance, and a locked foot contributes its old anchor height rather than the newly observed stair. Swing feet therefore contribute much less to pelvis height; there is no new pelvis solver or extra body transform layer.

## Debug and verification

F8 includes per-foot confidence, actual IK weight, lock/blend state, release reason, terrain height gap, vertical speed, raw root-relative horizontal speed and directional swing speed. Probe error measures the solved foot against the current animated-ray target; contact error uses the remembered anchor while locked. These intentionally differ when the source Idle sways or a probe crosses a stair edge. Runtime solver-error diagnostics remain available. Orange = raw terrain, cyan = smoothed terrain, white persistent cross = locked ankle target, green = solved ankle, magenta = pelvis correction.

All **14 V2 suites pass**, including the previous thirteen and the new planting suite. No existing test assertions were weakened. New coverage:

- Idle: both confidences 1.00, effective IK 0.95, one lock acquisition per foot over the initial settle/180-frame sample (no chatter).
- Walk: measured mean IK in high-support samples ~0.70 vs ~0.14 in clear swing samples; swing feet remain lifted. Across ten consecutive anchored sample intervals, authored world-horizontal travel 0.423 m vs solved 0.305 m (~28% reduction). This is a short-lock measurement, not a whole-stride skating guarantee.
- Run: ~0.28 support / 0.077 swing influence in the sampled dynamic sequence; only brief locks.
- Sprint: ~0.18 support / 0.056 swing; animation remains dominant and support windows are short. Some initial locked frames reflect the transition out of Idle.
- 15/20 cm stairs: physical traversal completes unchanged, with 25/16 locked foot-frames in the Walk fixture and stable knees/segment lengths. All existing stair/gait/ascent/descent regressions also pass.
- Split curb: upper foot plants; moving its animated probe onto another surface leaves the old supported anchor and its target height unchanged. Temporarily removing only that test surface's collision releases the anchor immediately, then the test restores collision.
- Walk off platform: 8 single-valid-foot frames and 26 airborne frames in the fixture; invalid feet and all airborne feet have no lock.
- Jump clears locks immediately, IK fades to zero, Land rebuilds support without instant anchoring. Both Walk180 and Run180 explicitly verified lock-free while active; gameplay pivot regressions pass.

Idle and Walk rendered poses/debug displays were inspected. These are not a claim of exhaustive manual motion-quality testing. Source Idle waist/pendulum sway remains unchanged. Partial IK and short horizontal/reach budgets deliberately leave some sliding and extreme split-curb reach error. Before 3B.5, playtest normal Walk and 15/20 cm stairs at these defaults; tune confidence timing/thresholds first if support feels late, and keep Run/Sprint conservative. Do not increase lock range or remove reach protection to hide source stride mismatch. Authored contact markers, stride warping, footstep events, toe roll, root motion and other IK systems remain deferred.

StepSolver SHA256 at start/end: `E2659D3D736C987FD427BA6446E9223B15D502E970814ACA7DE8778BC861E23B`. Motor: `25DF4FCC8BB900DA93961D3FFC2D795CA5C0A8A7DABF29741E189A74CCF19868`. Player scene/capsule: `03B0356D25F0F015ACEF90E1A57B96F93D490A34FA42C6060DDF6A43695EE337`. No edits to StepSolver, CharacterBody, collision, movement values, jump/fall controllers or traversal geometry in this phase. No commit/push requested or performed.

# V2 — IK Contact + Narrow Step Refinement (2026-09-06)

Targeted refinement after the stable Git/GitHub tag **0.3B.4**, not a redesign or a new foot-planting phase.

## Contact diagnosis and final settings

Compared identical frozen animation poses on flat ground and split 15/20 cm curbs with global foot weights 0.80, 0.95 and 1.00, and vertical caps 0.20/0.25 m. The reachable upper foot's residual error is mainly partial solver influence. The lower foot also hits the 99.5% chain-reach bound after the existing limited pelvis drop. Raising the vertical cap to 0.25 m changed the 20 cm curb's lower-foot error by less than 0.03 mm at weight 0.8; it is not the useful tuning lever here. Frozen results exclude temporal target-smoothing lag. No evidence justified changing the sole offset or pelvis range. Full 1.0 weight removed reachable-target error but could not remove reach-limited error; 0.95 was retained as the more modest adjustment.

`FootIKController.foot_ik_weight`: **0.95** for Idle/Walk, also the global ceiling. New exposed `run_foot_ik_weight=0.80`, `sprint_foot_ik_weight=0.65`, capped by that ceiling. All are further multiplied by existing swing relevance and blended with the UNCHANGED 10/s in, 12/s out rates. Invalid/airborne fade code, current-pose-relative target release, and swing attenuation at 4–18 cm animated sole lift are untouched. No locking or lateral dragging introduced. Pelvis architecture/settings are unchanged; its existing effective-foot-weight support ratio naturally gives reduced relevance to lower Run/Sprint influences.

UNCHANGED: vertical correction cap **0.20 m**, horizontal cap **0.15 m**, sole offset **0.08 m**, position smoothing **20/s**, normal smoothing **15/s**, pelvis max drop **0.20 m**, pelvis weight **0.80**, pelvis smoothing **10/s**, and native chain reach **99.5%**. Terrain-normal ankle rotation remains OFF, as before.

Final-pose diagnostics now record `leg.terrain_error` (solved ankle to the ORIGINAL valid terrain ankle target, not the reach-clamped solver destination) and `leg.solver_error` (solved ankle to solver destination). Invalid terrain error is NAN and displays N/A. F8 displays both, distinguishing reach/target limits from solver influence. Both are ankle-space distances; mesh sole contact still warrants visual inspection.

| Frozen fixture | Left terrain error: old -> new | Right terrain error: old -> new |
| --- | --- | --- |
| Flat idle | 0.34 -> 0.08 mm | 0.32 -> 0.08 mm |
| Split 15 cm curb | 29.88 -> 7.75 mm | 13.50 -> 11.33 mm |
| Split 20 cm curb | 39.35 -> 10.22 mm | 29.35 -> 27.17 mm |

Mean over these six foot samples: **18.79 -> 9.44 mm** (about 50% reduction). This is a frozen-fixture mean, NOT a promise of sub-centimeter contact throughout every gait. Rendered 15 cm split-curb before/after was inspected: upper-foot penetration decreases, lower foot remains near the floor, without additional pelvis movement. Remaining lower-foot gap on the extreme split fixture is deliberately bounded by reach; do not stretch the skeleton or bury the sole to eliminate it.

## Step diagnosis and detection

Old detector: one forward center ray and two lateral support rays aligned to the hit face. This made support classification approach-dependent: a 40 cm-wide ledge failed from the short side, diagonal corner entries failed, while a 15 cm-thin rail could incorrectly pass from its long side.

Retained the existing ray-based face/high/top validation instead of introducing a new shape-cast subsystem. Three horizontal origins: center, left and right **0.15 m** from center (0.30 m overall candidate footprint; exposed `candidate_lateral_offset`, capped relative to capsule radius). Direction is still actual horizontal movement, not facing. Center is preferred; its miss/rejection does not discard valid side candidates. Equal-offset side candidates have deterministic left/right tie order. A regression verifies RIGHT acquisition while CENTER is still rejected as APPROACHING.

Each candidate retains the same 0.35 m max height, minimum height, walkable normal, upper-obstruction ray, actual capsule overlap, vertical sweep and raised forward sweep checks. No obstacle-height increase. Destination stays on the movement centerline: no sideways relocation or steering toward a lateral ray.

Support validation is now two-dimensional: center ray plus 8 rays on an inner footprint circle of radius **0.6 * capsule radius = 0.27 m** (diameter 0.54 m). Center and at least **6/8** ring samples must have nearby walkable top support (25 mm above / 40 mm below candidate base). This is a lightweight support heuristic, not an exact mesh-area computation. It rejects the unsafe 15/25 cm rails in this lab. Capsule overlap and sweep validation still determine actual body clearance.

Try destination inset **0.45 * radius = 0.2025 m**, then **0.65 * radius = 0.2925 m** beyond the detected face. The first preserves clearance against the next 60 cm stair tread/riser; the fallback lets a narrow short-side approach acquire support beyond the leading corner. Both are validated, not blindly advanced. Existing active-lift timing, cached support recheck, finish/snap, collision-based lift, and movement ownership remain unchanged.

F4 shows per-sample HIT/MISS/rejection (NOT_TESTED when an earlier candidate wins), selected candidate, height and footprint support status. Existing ray visualization includes the new casts.

## Regression and playtest fixtures

New labeled east-wing fixtures in `test/step_traversal_zone_v2.gd`: supported 0.40 x 4 m curb at (100,18), diagonal 3 x 3 m corner at (110,18), unsafe 0.15 x 4 m rail at (120,18); all 0.20 m tall. Old lab geometry and coordinates are preserved.

`test_narrow_step_v2.gd` verifies actual grounded arrival on top, not just step activation. All Walk/Run/Sprint cases pass: short and long side of the supported ledge, mirrored diagonal corners, and rejection from both sides of the unsafe rail. Running the same fixtures against the 0.3B.4 solver confirmed the old short-side/corner failures and unsafe long-side acceptance. Side-candidate fallback has its own isolated regression.

`test_contact_refinement_v2.gd` verifies measured contact improvement, exact grounded gait influence, preserved limb lengths/knee stability, and lifted swing-foot release for all three gaits. All **13 V2 suites pass**, including the previous eleven suites. Broad curbs 5–35 cm still pass across all gaits; 40–50 cm fail. 10/15/20 cm staircases retain speed, bounded lift, no landing events and no Fall/Land flicker. Wall, low ceiling, steep top, and original unsafe narrow edge still reject. Existing 30/120 Hz traversal regressions pass.

Motor, jump/fall controller, grounded/gait controller, pelvis modifier and foot-grounding sensor hashes match 0.3B.4. No CharacterBody scene/capsule edits were made in this pass; existing editor-reserialized scene metadata was preserved (capsule remains radius 0.45 m, height 1.8 m, center Y 0.9 m). Live main-scene smoke check passed, apart from the environment's certificate-store warning. Editor-layout warnings about the old missing Character Test.glb remain unrelated. No claim of exhaustive manual playtesting; rendered contact comparison and automated physics/animation checks were performed. User playtesting of the new labeled ledge and corners is recommended before the next checkpoint. No commit or push performed for this refinement.

# V2 Phase 3B.3 — Pelvis Compensation (2026-09-05)

Adds `player_pelvis_ik_v2.gd`, a SkeletonModifier3D instantiated by FootIKController. Runtime verification: **mixamorig_Hips, index 0, parent -1 (skeleton root)**. Both UpLeg chains descend directly from this bone. Lookup uses the name, not a hard-coded index. Only world-vertical translation is converted through the inverse skeleton basis into bone-global pose space; no Hips/spine rotation, scale, CharacterBody, capsule, or VisualRoot writes.

## Ordering and targets

AnimationTree -> existing landing/pivot presentation -> existing animated-foot probes -> capture original ankle poses, capped world destinations and independent foot weights -> manual skeleton advance -> **PelvisCompensation** -> recalculate leg reach/poles from lowered chain origins -> LeftFootIK -> RightFootIK -> PreserveAnimatedAnkles -> final skeleton_updated diagnostics. Native transient modifiers start from restored animation output each frame. Frozen-pose tests check the final Hips transform equals the animation transform plus exactly one vertical offset, without drift. Ground targets and original ankle orientation remain fixed; no additional probes.

The only FootIK refactor separates per-frame sampling/weight updates from target placement. Reach remains limited to 99.5% of actual chain length and is now evaluated after Hips lowering. Existing ankle correction limits and native leg solvers are retained. Target caps/partial IK still permit residual floor gaps or penetration; this is not foot planting.

## Settings and support

Inspector: PlayerV2 / FootIKController / Pelvis Compensation. Defaults: `pelvis_enabled=true`, `max_pelvis_drop=0.20 m`, `pelvis_adjust_speed=10 /s`, `pelvis_ik_weight=0.80`. No positive raise (0 m); no separate recovery speed or gait settings.

Per-foot required offset = smoothed terrain ankle target Y minus ORIGINAL animated ankle Y. Valid grounded support = min(existing swing influence, effective leg weight / global foot weight); invalid, airborne, disabled, or jump-start support is zero. Desired pelvis offset = clamp(min(0, left_required*left_support, right_required*right_support), -max_drop, 0) * pelvis_weight. Thus the default maximum weighted lowering is 0.16 m. Exponential interpolation uses `1-exp(-10*delta)`; tiny residuals below 0.1 mm become zero.

Idle/Walk/Run/Sprint share the 0.8 global pelvis weight; moving feet use the existing 4–18 cm animated sole-lift swing attenuation, plus their smoothed IK influence. There is no unconditional Run/Sprint multiplier: dynamic tests did not justify extra gait tuning. Jump/Fall have zero target and smooth release; supported Land reacquires gradually. Unsupported ledge feet contribute nothing. This deliberately remains a support heuristic, not contact-phase detection or foot locking.

## Landing sink budget

Existing VisualRoot landing compression is untouched. It already contributes to measured world ankle positions. Applied Hips offset = min(0, smoothed_pelvis_offset - min(landing_sink, 0)). Consequently VisualRoot sink + applied Hips lowering equals the deeper of those two offsets, not their sum. A -0.25 m sink suppresses an additional -0.16 m pelvis drop instead of producing -0.41 m. This never positively raises Hips or weakens the existing landing profile. Both synthetic and actual jump/landing checks confirm the shared budget and neutral recovery.

## Verification

All eleven V2 suites pass: motor, grounded animation, landing compression, pivots, turn arc, animation recovery, StepSolver, idle/passive fall, foot grounding, foot IK, and new `test_pelvis_ik_v2.gd`. The existing foot IK test now verifies expected vertical Hips translation rather than the obsolete no-pelvis-change assertion; pelvis remains enabled throughout regression testing.

Frozen split-curb comparison uses identical authored pose and body position with pelvis disabled/enabled, both at normal 0.8 foot weight:

| Fixture | Pelvis drop | Lower-foot terrain error before -> after |
| --- | --- | --- |
| 15 cm curb, body Y 0.15 | 12.59 cm | 13.85 -> 1.35 cm |
| 20 cm curb, body Y 0.20 | 16.00 cm | 18.82 -> 2.93 cm |
| Flat floor | 0.68 cm | 0.15 -> 0.03 cm |
| Both feet on 20 cm curb | 0.68 cm | 0.15 -> 0.03 cm |
| Ramp standing | 4.31 cm | 3.45 -> 0.17 cm |

Split 15 cm curb rendered before/after was inspected: lower sole visibly approaches the floor, upper knee bends, torso settles. Frozen fixtures remain stable for an additional 180 frames. Ramp walking passes limb-length/knee checks. All 18 stair cases (10/15/20 cm, Walk/Run/Sprint, up/down) traverse with stable knee pole side and segment error <2 mm. Largest procedural offset frame change was approximately 2.2 cm at 60 Hz; no extra gait multipliers added. Physical/body camera transforms are untouched, but subjective real-time bobble/camera comfort still merits user playtesting. No claim of full manual playtesting of all scenarios.

Ledge fixture has left support 1 and right support 0; only the valid leg governs lowering. Airborne release is monotonic to neutral, with real jump/landing recovery also checked. Motor, landing controller and foot sensor hashes match the previous checkpoint. StepSolver SHA256 remains `34B96532FECE9BBE2E8F362CFD03262DDA7E4B6F875E15CEE30D776FA6C9B746`. No collision, geometry or scene changes.

F8 now includes PELVIS IK weight, max drop, required/support values, target/current/applied offset, and a magenta original-to-corrected pelvis line. Settings remain on FootIKController; no separate scene node needs configuring.

Before Phase 3B.4: playtest 0.8 weight / 0.20 m limit / speed 10 first. Tune only if a particular gait feels too low or bouncy. Partial foot influence and correction/reach limits intentionally leave residual error; raised feet may still penetrate slightly, and source idle sway is unchanged. Terrain-normal foot tilt remains OFF as in 3B.2 (authored ankle orientation preserved). Phase 3B.4 should address support-phase foot planting/locking and sliding, not increase pelvis drop to disguise those issues. No foot locking, gait markers, toe IK, torso tilt, spine compensation or root motion introduced.

# V2 Phase 3B.2 — Foot IK (2026-09-05)

Implemented with the installed engine's native **TwoBoneIK3D** modifiers, not custom CCD/FABRIK. Runtime ClassDB confirmed the available native classes/properties and rig chain indices; native method semantics were cross-checked against https://docs.godotengine.org/en/latest/classes/class_twoboneik3d.html and https://docs.godotengine.org/en/latest/classes/class_skeleton3d.html (latest docs are advisory; installed 4.7.1 API/runtime tests were authoritative).

## Ownership, chains and ordering

New `Characters/Player/V2/player_foot_ik_v2.gd` is attached at `PlayerV2/FootIKController`. It creates two native solvers directly beneath `VisualRoot/MasterRig/Base Armature and Mesh/Skeleton3D`: `LeftFootIK` and `RightFootIK`. Left chain: **mixamorig_LeftUpLeg (60) -> mixamorig_LeftLeg (61) -> mixamorig_LeftFoot (62)**. Right: **mixamorig_RightUpLeg (55) -> mixamorig_RightLeg (56) -> mixamorig_RightFoot (57)**. Runtime lookup and direct-parent validation avoid relying on fixed indices. Pelvis (index 0) is not part of either chain. ToeBase/Toe_End bones exist but are not IK endpoints or separately modified.

Data source remains `PlayerV2/FootGrounding.left/right`, equivalent to the existing `FootGrounding/LeftFootTarget` and `RightFootTarget` surface markers plus the existing 0.08 m sole offset. The ground sensor is UNCHANGED. Native solvers target controller-owned `FootIKController/LeftIKTarget` and `RightIKTarget` markers, which hold the LIMITED ankle destinations. This keeps clamping/airborne release from overwriting the 3B.1 terrain markers. No duplicate casts are performed.

`LeftKneePole` / `RightKneePole` are controller child Marker3Ds. Each pole is 0.6 m beyond the current animated knee along its projected bend direction. Nearly straight (<0.015 m bend) poses use character-forward projected perpendicular to the hip/ankle axis. This follows the authored knee plane instead of introducing an unrelated fixed world-space pole.

Pipeline: AnimationTree evaluates -> existing AnimationController applies pivot/landing presentation -> existing FootGrounding samples ANIMATED feet -> FootIKController updates destinations/influences -> calls Skeleton3D.advance in MANUAL modifier mode -> native left/right leg IK -> ankle-orientation preservation -> final skin pose. Connections are made deferred in that order. The engine's transient modifier processing leaves the base animation available for subsequent sensing, avoiding an IK/probe feedback loop. The controller restores prior modifier callback mode when removed. Final result diagnostics are captured from skeleton_updated, not from the restored base pose afterward.

`player_foot_ik_orientation_v2.gd` is a small final SkeletonModifier3D that preserves each ankle's authored world basis after parent leg rotations change. It does not solve leg positions. **Terrain-normal ankle tilt is OFF in this phase**, including on ramps. This deliberate position-first choice prevents incidental parent rotation from rolling the feet. The modifier touches only the two foot transforms (retaining their solved origins); no pelvis/spine, toe IK, CharacterBody transform, or collision writes occur.

## Inspector defaults and state behavior

| FootIKController setting | Default |
| --- | --- |
| enabled | true |
| foot_ik_weight | 0.80 |
| foot_ik_blend_in_speed | 10 /s |
| foot_ik_blend_out_speed | 12 /s |
| max_foot_ik_vertical_correction | 0.20 m |
| max_foot_ik_horizontal_correction | 0.15 m |
| foot_ik_debug | false; F8 toggles |

Each foot independently exponentially approaches global weight times supported validity and swing influence. No gait-specific Inspector weights were needed: downward correction fades with animated sole lift relative to body base from 0.04 to 0.18 m while movement is requested, keeping lifted swing feet from being pinned merely because the terrain ray still hits. This is not phase locking and does not preserve a world-space planted foot. Fading invalid/airborne feet releases BOTH influence and prior correction exponentially, expressed relative to the current animated pose, not a stale terrain point. Targets reacquire after supported contact; Land sink is included exactly once through world transforms, never added again or removed. Jump/Fall fade to zero; no step-down or gameplay control exists in IK.

Destination begins at the existing smoothed ankle suggestion, clamps vertical and horizontal delta, then limits reach to 99.5% of the current upper+lower segment lengths. If reach projection would exceed the correction bounds, it falls back to the animated position instead of stretching. Native IK rotates the two segments without extending their lengths. Partial weight plus capped reach intentionally leaves some residual error. Poles and reach caps do not reposition the pelvis.

F7 remains probe diagnostics. F8 adds global/per-foot weights, validity, vertical correction, clamp flag and swing influence. Optional geometry uses yellow animated-to-target lines, cyan target-to-solved lines, and green solved crosses. Runtime `legs` diagnostic dictionaries also report pole-side stability and limb-length error.

## Verification, observations and limitations

New `test/test_foot_ik_v2.gd` passes native solver binding, independent target improvement, correction caps, unchanged body and pelvis, edge-specific release, smooth jump fade, landing reacquisition, swing-foot release, and all nine gait/stair combinations. Solved knees remain on their intended pole side and limb lengths stay within 2 mm test tolerance. The original nine V2 suites also pass, including foot sensing, standing/moving Land compression, reversals, 20-drop recovery, passive suppression and full StepSolver matrix.

Measured frozen-pose results at weight 0.8:

* Flat floor: ankle target error reduces from ~8.5 mm to ~1.6 mm; both legs remain stable.
* 15 cm split-curb fixture: raised leg error to limited target reduces from 9.25 cm to 2.28 cm. The lower leg is reach-limited, as expected without pelvis adjustment.
* 20 cm split-curb fixture: independently adapts with the same ~2.28 cm raised-leg residual in the tested relative pose; no hyperextension.
* Ramp: limited target errors ~3.12/2.15 cm reduce to ~0.39/0.31 cm. Foot world orientation remains authored, not terrain-aligned.
* Walk/Run/Sprint: base animation is retained; tests observe swing-release samples in every gait (18/30/24 during the sampled runs). These are automatic bounds/pose checks, not a claim of completed subjective skating calibration.
* Jump/Fall: influences decay to zero without chasing fixed terrain; Land blends back while the original sink/profile tests remain passing. One unsupported edge foot fades independently while the supported foot stays near 0.8.

Rendered and inspected paired before/after 15 cm curb images in the task workspace (`work/foot_ik_before.png`, `work/foot_ik_after.png`): upper foot visibly rises out of the curb and knee bends while torso remains fixed. Some sole penetration/residual gap remains at partial influence, and the low leg may remain above ground because the pelvis is fixed. No claim of perfect contact or completed in-motion visual review. Manual review should focus on knee behavior during animated pivots, foot skating, and the Land-to-IK handoff. Keep 0.8 / 10 / 12 / 0.20 / 0.15 initially; lower global weight toward 0.6 if correction feels too assertive. Do not raise limits to compensate for missing pelvis motion. Phase 3B.3 should address shared pelvis reach while preserving the existing motor and landing presentation.

Byte comparisons confirm `player_v2.gd`, `player_animation_v2.gd`, `player_foot_grounding_v2.gd`, and `player_turn_180_v2.gd` unchanged from checkpoint b47d655. StepSolver remains SHA256 `34B96532FECE9BBE2E8F362CFD03262DDA7E4B6F875E15CEE30D776FA6C9B746`. Capsule/body settings and lab geometry unchanged. Changed files: reusable player scene, debug HUD, this document; new IK controller, ankle-preservation modifier, IK test and associated UIDs. No pelvis compensation, procedural locking, stride warping, root motion, hand/weapon IK, or source-GLB changes.

# V2 Phase 3B.1 — Foot Ground Detection (2026-09-05)

Observation only: new `Characters/Player/V2/player_foot_grounding_v2.gd` owns `PlayerV2/FootGrounding`, two child RayCast3D nodes `LeftFootProbe`/`RightFootProbe`, Marker3D helpers `LeftFootTarget`/`RightFootTarget`, and debug line geometry. Only the reusable player scene and debug HUD are connected to it. No movement, StepSolver, animation-controller, camera, collision, skeleton, pelvis, or bone-pose code is modified. No IK consumer, foot locking, pole/knee target, stride warp, or root motion exists.

## Rig access and timing

Exact skeleton path: `PlayerV2/VisualRoot/MasterRig/Base Armature and Mesh/Skeleton3D`. Runtime name lookup verifies `mixamorig_LeftFoot` index **62**, `mixamorig_RightFoot` index **57**. ToeBase indices are Left **63**, Right **58**; Toe_End indices Left **64**, Right **59**. Indices are looked up by name, not hardcoded in the component. A missing skeleton/bone reports a clear error and leaves validity false rather than using an unrelated bone.

World foot position = `skeleton.global_transform * skeleton.get_bone_global_pose(index).origin`. Imported scale/orientation, VisualRoot facing and landing offsets are thus included. A deferred bind registers the observer on AnimationTree.mixer_applied AFTER the existing AnimationController handler, so it reads the evaluated pose after existing presentation offsets. No independent render-loop bone polling, no bone setters, and no skeleton override calls are used. Automatic RayCast processing is disabled; each allowed evaluated pose forces exactly two fresh ray updates.

Rest-pose foot/ankle origin is approximately **0.0873 m** above the model's toe-level plane (toe origins near zero); idle sampling on the flat lab floor measured left ankle Y **0.08844 m**. Default sole offset 0.08 leaves an estimated idle sole gap around 0.00844 m. This is a bone/toe-plane measurement, NOT a skin-vertex sole calibration. Future IK must calibrate the actual sole and animated foot rotation before treating the offset as final.

## Defaults and data contract

| Setting | Value |
| --- | --- |
| enabled | true |
| foot_grounding_debug | false; F7 toggles (F3 HUD, F4 step diagnostics remain intact) |
| foot_probe_origin_height | 0.20 m above CURRENT animated ankle, world up |
| foot_probe_distance | 0.60 m TOTAL cast length from that elevated origin |
| ground_collision_mask | layer 1, intersected with the motor collision mask |
| foot_sole_offset | 0.08 m |
| foot_target_smoothing_speed | 20 /s |
| foot_normal_smoothing_speed | 15 /s |

Self is explicitly excluded. Areas are disabled. Only StaticBody3D (including AnimatableBody3D) hits are accepted; CharacterBody3D/enemy and RigidBody3D hits invalidate instead of becoming targets. World geometry must remain on the intended ground layer; future static weapon props on that same layer would need filtering/layer segregation. A disallowed body can occlude a ray and produce invalid data; the sensor does not cast repeatedly through actors. Existing capsule remains 0.45 m radius / 1.80 m height with 0.001 m safe margin, 0.30 m floor snap and 45-degree floor limit.

Consumers read `FootGrounding.left` / `.right` FootSample objects: `valid`, `hit`, `reason`, `bone_index`, `bone_position`, `raw_ground_position`, `smoothed_ground_position`, `raw_ground_normal`, normalized `ground_normal`, signed `distance`, `target_transform`, and `ankle_target_transform`. `distance` means animated ankle Y minus sole offset minus raw ground Y; positive means the estimated animated sole is above terrain. `target_transform` and Marker3D position are the SMOOTHED GROUND contact, with identity world basis. `ankle_target_transform` adds normal*sole_offset as a separate future ankle suggestion, avoiding an ambiguous offset in the ground hit itself. No helper is connected to SkeletonIK.

`foot_height_delta` is raw left terrain height minus right terrain height when both valid, otherwise NAN. `lowest_required_pelvis_offset` is min(0,-left.distance,-right.distance) only when both valid, otherwise NAN. It is an unweighted diagnostic hint, NOT a usable pelvis solver: swing feet/contact phase must be considered in Phase 3B.3.

## Validity and smoothing

Valid requires enabled sensing, the motor's supported-ground state (including validated step-up), no airborne/jump flag, an in-range hit on eligible terrain, and normal dot UP >=cos(existing floor_max_angle). Even a visually suppressed passive airborne stair frame invalidates foot targets; visual locomotion alone is not physical foot support. Grounded Land can reacquire immediately in the first evaluated contact pose. No-hit, non-terrain, steep, disabled, or airborne invalidates immediately. Last helper transform can remain stored but must not be consumed unless `valid` is true; no smoothed stale contact is promoted to validity.

Position filtering uses exponential height interpolation `1-exp(-20*dt)` and exact current hit X/Z, so Sprint does not drag a horizontally lagging target behind the animated foot. Normals use normalized interpolation with `1-exp(-15*dt)`. Reacquisition, collider change, or >0.08 m height discontinuity seeds directly from raw data, avoiding blending between separate stair treads. Setting a smoothing speed to zero bypasses that filter. Filtering small vertical changes can temporarily put the smoothed target off the exact surface; raw data remains available for later IK choices. Normal filtering never changes the RAW walkability decision.

F7 enables the existing HUD and debug geometry: left cyan / right magenta origins and cast columns, yellow raw crosses/normals, green smoothed targets, red invalid columns. The HUD shows validity/reason, signed distance, target Y, normal, and independent terrain height delta. Rendered split-curb verification is saved outside the project in the working task's `work/foot_grounding_debug.png`; it visibly reports 0.150/0.000 m targets and 0.150 m delta without moving either foot.

## Verification and Phase 3B.2 handoff

New `test/test_foot_grounding_v2.gd` passes flat idle stability/up normals, current-pose foot tracking, zero horizontal target lag, isolated 15 cm split-height case, ramp normals, one valid/one invalid platform edge, rejection of 55-degree tops, 10/15/20/30 cm curbs, all three stair sets, rotated diagonal curb, immediate jump invalidation and post-landing reacquisition. An explicit before/after snapshot confirms sensing/debug generation changes neither body transform/velocity nor ANY skeleton bone pose. Edge/slope fixtures reposition only the whole player in the test; the sensor never does so. Original eight V2 suites also pass with the observer enabled.

At default range, flat locomotion produced valid samples for Walk 120/120, Run 100/120, Sprint 93/120 across a 60-tick two-foot sample. Higher swing poses legitimately exceed the cast range and invalidate; validity is TERRAIN AVAILABILITY, not proof the foot is planted. Stair targets reacquire upper treads; discontinuities at true edges are expected and should not be hidden with stale contact. Thin geometry, moving-platform local-space anchoring, render interpolation, and more complex collision-layer setups still need future coverage. Keep 0.20 origin / 0.60 distance / 0.08 sole / 20 position / 15 normal initially; test 0.70–0.80 range only if additional swing reach is useful, without relaxing airborne invalidation. Do not use longer rays as a substitute for contact-phase weighting.

Phase 3B.2 may read the two valid target transforms/normals and add a separately blended IK consumer. Targets are not foot locks, and their identity basis is deliberate: no ankle orientation solving yet. No gameplay feel change is expected or observed in regressions; extended subjective play review remains useful. StepSolver SHA256 remains `34B96532FECE9BBE2E8F362CFD03262DDA7E4B6F875E15CEE30D776FA6C9B746`.

# V2 — Idle Facing Lock + Passive Fall Suppression (2026-09-05)

Idle orbit previously rotated the character because `player_v2.gd` substituted camera-forward for desired facing when movement was absent. That nonzero `facing_delta` triggered the grounded animation resource's stationary turn nodes. The motor now publishes zero facing delta without meaningful movement and only performs ordinary velocity-facing rotation with input magnitude >0.01. This threshold is applied after the existing Input.get_vector action deadzone; input configuration is unchanged. Camera code, idle playback, explicit pivot ownership, Walk180/Run180, and movement-relative arc logic are unchanged. On new input, the current camera basis still determines movement normally. Stationary turn clips remain available but camera orbit no longer requests them.

`AnimationController` adds `passive_fall_ground_grace_distance=0.30 m` and `passive_fall_min_air_time=0.12 s` under Passive Fall Presentation. Suggested manual ranges: 0.20–0.40 m and 0.08–0.18 s. The previous `fall_min_air_time` name remains a script compatibility alias to the same timer, not a second setting. Optional `debug_facing_and_passive_fall` defaults OFF and reports input, facing lock/update, actual physical floor contact, passive airtime, nearby ground/distance, committed Fall, and current presentation.

The previous V2 passive selector checked only airtime and downward speed, with no ground-proximity sensor. The new presentation-only sensor casts five downward rays (centre and +/-0.20 m world X/Z), from 0.02 m above the body base to max(0.65 m, twice grace+0.05 m) below it. It uses the body's mask, excludes the body RID, ignores hits more than 0.002 m above the base, and accepts normals only within the body's existing floor_max_angle. The minimum valid vertical distance is used. It does not reuse or modify StepSolver because that component's probes are upward-traversal candidates, not downward presentation support.

Exact passive rule: while uncommitted, nearby walkable ground at distance <=grace preserves locomotion regardless of timer. Without nearby ground, commit when vertical velocity <=the unchanged apex threshold (-0.5 m/s) AND any of: airtime >=passive minimum; ground is clearly far (>max(0.60 m, twice grace), including no valid probe hit); downward velocity <=-3.0 m/s. Nearby ground takes precedence over the passive timer/speed clauses so repeated stairs do not become a fall merely because the grace timer elapsed. This resolves the brief's competing OR examples in favor of its core nearby-ground stair rule. The grace distance measures CURRENT proximity, not maximum drop height.

Intentional Jump bypasses all proximity/time suppression and uses the existing immediate gait-aware Jump selection and unchanged apex transition. `fall_visual_committed` latches until ground contact; seeing close ground later cannot return a committed Fall to locomotion midair. Only a visible airborne episode qualifies for the existing contact Land, so suppressed stair floor losses create no landing events. No motor grounding, velocity, gait/buildup, jump/gravity, air control, floor snap, collision, or landing compression settings changed. Phase 3A StepSolver source is byte-for-byte unchanged (SHA256 `34B96532FECE9BBE2E8F362CFD03262DDA7E4B6F875E15CEE30D776FA6C9B746`); its tests remain intact.

New `test/test_idle_passive_fall_v2.gd` checks 360-degree idle orbit without yaw change, continuing idle clock, camera-behind movement/arc activation, Walk/Run/Sprint descent of all six 20 cm risers with the original 60 cm treads, a 3 m meaningful ledge drop with sticky Fall and exactly one Land, and immediate moving Jump from a stair tread. Descent observed 8/8/15 total physical-airborne frames for Walk/Run/Sprint respectively; every one saw nearby ground, with zero Fall commitments or landing events and no gait downgrade. Existing grounded tests now assert idle orbit lock instead of the superseded camera-turn behavior. Motor, grounded, landing compression, pivots, turn arc, 20-drop animation recovery, and Phase 3A step traversal suites also pass. Visual feel remains a manual play-test responsibility.

Files: player_v2.gd, player_animation_v2.gd, player_debug_v2.gd, test_grounded_animation_v2.gd, new test_idle_passive_fall_v2.gd (+UID), and this document. No step solver, lab geometry, camera script, animation source, or pivot-resource edits in this follow-up.

# V2 Phase 3A — Automatic Step Solver (2026-09-05)

This section describes the active V2 implementation and supersedes the historical prototype's no-step-solver policy below. Stable recovery point before this work: GitHub/main `3f7284e`. No prior movement, jump, landing, pivot, camera, floor-angle, capsule, or safe-margin tuning was changed.

## Lab and Inspector

The main scene remains `res://test/player_v2_lab.tscn`. Its new `StepTraversalZone` east wing is generated by `test/step_traversal_zone_v2.gd`. Walk east from spawn following the sign. Ten independent 3 m-wide, 8 m-deep platforms at X=38,44,...92 / Z=0 have heights 5,10,15,20,25,30,35,40,45,50 cm, with flat approach/exit runway. Six-riser staircases at X=42/52/62 start near Z=-22 and use 10/15/20 cm risers, **60 cm treads**, and upper landings. Existing lab geometry/coordinates are unchanged. The wing also contains a rotated 35-degree approach curb, 25 cm-wide narrow edge, 12-degree top, 55-degree top, 3 m wall, 20 cm curb under a 1.90 m ceiling, and shallow comparison ramp.

Select `PlayerV2/StepSolver`:

| Setting | Initial value |
| --- | --- |
| enabled | true (disable for original direct-slide behavior) |
| max_step_height | 0.35 m |
| min_step_height | 0.025 m |
| step_up_speed | 5.0 m/s maximum correction rate |
| minimum_lift_duration | 0.06 s |
| debug_steps | false; F4 toggles probes + text, F3 toggles HUD |

Keep max at 0.35 initially; try 0.30–0.40 only after boundary testing. Speed 4–6 m/s is a useful tuning range, but reducing it or increasing minimum duration can cause blocking on closely spaced stairs at Sprint. Do not increase height to bypass walls or shorten collision tests. The unchanged capsule is radius 0.45 m, total height 1.80 m, local centre (0,0.90,0); root origin is its foot/base. Floor max angle is engine default 45 degrees, snap 0.30 m, safe margin 0.001 m. Existing grounded slope behavior remains engine-owned.

## Component, probes, and exact decision

`Characters/Player/V2/player_step_solver_v2.gd` is an isolated Node3D at `PlayerV2/StepSolver`, with no animation or bone dependencies. There are no separate probe nodes: direct-space ray queries supply low/high/top/lateral support probes; full capsule overlap queries and `CharacterBody3D.test_move` supply footprint/clearance sweeps. Queries use the body's collision mask and exclude its RID. F4 draws all queried segments and cross markers at detected hits; green denotes an accepted candidate and red a rejection, with numerical height, walkability, clearance, active state, and reason in the HUD.

1. Initiation requires actual floor contact, movement intent and horizontal speed >=0.1, no accepted jump, ordinary locomotion, and no active 180 turn. The whole pivot is excluded, including its carry phase, so plant/reversal timing is untouched. Non-locomotion presentation uses the existing motor action gate.
2. Use resolved horizontal velocity direction (after existing intent/arc resolution), not visual facing. Low ray begins 0.025 m above the base. Reach is radius + speed*(maximum lift duration + two physics ticks) + 0.06 m. Ordinary walkable slope hits defer to normal movement.
3. High ray at max height +0.012 m must be clear to 0.065 m beyond the low hit. A wall/high obstacle produces UPPER_BLOCKED.
4. Cast down 0.065 m beyond the low hit from base+max+0.015 to base+min-0.005. Require a real top with measured rise in [min,max], allowing only 0.002 m numerical tolerance at the upper boundary. Top normal dot UP must be >= cos(body.floor_max_angle).
5. Delay distant candidates until their own height-dependent lead-in is reached. Require two lateral top samples +/-0.225 m along the obstacle-face tangent. Unsupported thin edges reject instead of balancing on one centre ray.
6. Target base is top+0.006 m. Require the actual capsule to fit at both the raised current location and the destination, a clear upward capsule sweep, and a clear raised forward capsule sweep. Failure rejects NO_BODY_CLEARANCE, including the low ceiling.
7. Commit only after all checks. Store a finite target, direction, and start height; every tick rechecks cached top support and raised-body clearance. Jump, released input, movement stop, >~37-degree direction change, action/turn, disabled component, lost support, blocked lift, or 0.6 s per-step timeout cancels support.

Other reasons include NO_LOW_HIT, NO_TOP_SURFACE, TOP_TOO_STEEP, TOO_TALL, TOO_SMALL, APPROACHING, NO_TOP_SUPPORT, AIRBORNE, AIRBORNE_OR_ACTION, NOT_MOVING, SUPPORT_LOST, and COMPLETE. These diagnostics distinguish an absent candidate from a rejected one.

## Motion and support ownership

The correction follows a smoothstep rise from captured start Y to target Y over max(0.06 s, 1.5*(rise+clearance)/5). The 1.5 factor bounds smoothstep's peak derivative. Each tick applies only the incremental rise, capped at step_up_speed*delta, using **collision-swept move_and_collide**. No body transform assignment, upward teleport, root motion, horizontal boost/restoration, or upward velocity accumulation exists. Horizontal movement still runs through the original acceleration/gait logic and move_and_slide; vertical gameplay velocity is zero during a valid lift. No camera compensation or camera-script changes were added.

Snap is temporarily suppressed only for the lift's slide and restored immediately afterward; otherwise it would undo the intentional rise. Once the centre reaches the verified top, existing apply_floor_snap hands back to actual floor contact. The target's 6 mm clearance produces a measured <=5.6 mm downward handoff, not a new step-down solver. Normal drops still use unchanged gravity, snap and short-drop presentation.

IMPORTANT: physical `is_on_floor()` can be false during the anticipatory lift. Motor `animation_state.is_grounded` deliberately represents **floor OR validated step support**, keeping full ground control and the same locomotion clock. This is a bounded, ground-initiated traversal state, not permission to start stepping in free fall. A completed lift may validate the next stair before the centre reaches the previous tread, chaining only independently checked tops with the same height/normal/body-clearance rules. This avoids stopping on repeated risers without accumulating upward velocity. Published `is_stepping_up`, `step_height`, and `step_target_y` are available for Phase 3B; no AnimationTree nodes, clips, timing, landing values, or animation-controller code changed. Future foot/pelvis grounding can consume these fields but must not change physical support ownership.

## Automated verification and limitations

`test/test_step_solver_v2.gd` passes:

| Curb height | Walk | Run | Sprint |
| --- | --- | --- | --- |
| 5 cm | pass | pass | pass |
| 10 cm | pass | pass | pass |
| 15 cm | pass | pass | pass |
| 20 cm | pass | pass | pass |
| 25 cm | pass | pass | pass |
| 30 cm | pass | pass | pass |
| 35 cm | pass | pass | pass |
| 40 cm | blocked | blocked | blocked |
| 45 cm | blocked | blocked | blocked |
| 50 cm | blocked | blocked | blocked |

All nine gait/stair combinations (10/15/20 cm risers, 60 cm treads) cross all six steps, with zero published airborne frames, zero landing events, continuously playing actual Loops, and no horizontal stop. Walk retains 4 m/s; Sprint retains 8 m/s; Run follows its unchanged buildup. Maximum measured stair rise per 60 Hz tick: ~0.0414/0.0611/0.0760 m for the three riser heights, with downward handoffs <=0.0056 m. These are measured motion bounds, **not a claim of visually proven camera smoothness**.

Wall, low ceiling, narrow edge and 55-degree top reject; diagonal approach traverses. Jump and released movement cancel the lift, jump retains its original impulse, disabling the solver restores 15 cm blocking, and the shallow ramp needs no lifts. The 15 cm Sprint case also passes at 30 and 120 physics Hz. All six existing suites (motor, grounded animation, landing compression, pivots, directional arc, and 20-drop animation recovery) pass with stepping enabled.

Known limits/manual follow-up: only static geometry and the documented capsule/foot-origin layout have been tested. Shorter-than-60 cm stair treads, moving obstacles/platforms, highly irregular meshes, near-parallel grazing approaches, slow analogue creeping, and abrupt speed/geometry changes need additional coverage; no claim that every residential staircase is solved. Capsule checks deliberately reject some narrow/sloped destinations even when a centre ray sees a walkable point. Anticipatory lift can visually float the feet before a curb; foot IK/pelvis work is deferred. Camera remains rigidly attached and inherits the eased body rise and small snap handoff; **manual camera/animation feel approval is still required**, particularly at Sprint. No IK, mantle, vault, climb, ledge grab, stair animation, or dedicated downward solver was introduced.

# Everdeep 0.0.3C — Grounded Movement Feel

## Implemented

- Camera-relative, smoothly accelerated WASD movement on `CharacterBody3D`.
- Smooth movement-facing rotation, hold-Shift sprint, grounded jumping, Left-Alt dodge burst, gravity, and stable floor contact.
- Airborne movement preserves takeoff momentum and supports separately tunable directional influence.
- Locomotion uses explicit `GROUNDED`, `AIRBORNE`, and `DODGING` states.
- Ordinary graybox stairs use simple ramp collision so stable `CharacterBody3D` locomotion traverses them naturally.
- Mouse orbit camera with independent yaw/pitch, pitch limits, and `SpringArm3D` collision.
- Movement derives its horizontal forward/right basis from the active player camera; only `VisualRoot` rotates, keeping camera orbit independent from character facing.
- Escape releases the mouse; clicking the game recaptures it.
- A lit graybox test arena with floor, walls, camera-collision obstacles, and an elevated block.
- A committed light attack with reusable hitbox, hurtbox, damage-packet, and health components.
- Two stationary target dummies for single-target and multi-target hit testing.
- The rigged humanoid from `res://Characters/Player/Models/Player_base.fbx` replaces the capsule placeholder while preserving the existing gameplay body and controller.
- Idle, Walk, and Run now blend from the player's actual horizontal physics velocity.

## Files

- `res://player/player.tscn` — reusable player scene.
- `res://player/player.gd` — movement, facing, gravity, sprint, and dodge.
- `res://player/player_animation_controller.gd` — animation-source loading, in-place cleanup, and locomotion blend updates.
- `res://Characters/Player/player_model.tscn` — presentation-only wrapper for the imported rigged player model.
- `res://player/player_camera.gd` — camera orbit and mouse capture.
- `res://test/test_arena.tscn` — main development scene.
- `res://combat/damage_packet.gd` — structured hit data.
- `res://combat/health.gd` — reusable health and damage signals.
- `res://combat/hurtbox.gd` — reusable damage receiver forwarding to Health.
- `res://combat/melee_hitbox.gd` — active-window damage and per-swing target tracking.
- `res://combat/player_combat_controller.gd` — attack timing, commitment, temporary swing, and localized hit stop.
- `res://combat/testing/target_dummy.tscn` — reusable stationary combat target.

## Controls

- **W/A/S/D:** move relative to camera yaw
- **Left Shift (hold):** sprint while moving
- **Space:** jump while grounded
- **Left Alt:** dodge in input direction, or facing direction when idle
- **Left Mouse Button:** light attack while grounded and mouse-captured
- **Mouse:** orbit camera
- **Escape / click:** release / recapture mouse

## Inspector tuning

Select the Player root for movement, jump, dodge, and gravity values. Select `CameraRig` for sensitivity, distance, pivot height, and pitch limits. Current tuned values are `walk_speed = 5.0`, `sprint_speed = 8.0`, `jump_velocity = 8.0`, `air_control = 0.4`, `rise_gravity_multiplier = 2.0`, and `fall_gravity_multiplier = 3.0`.

The experimental automatic step solver was removed. The player again uses the stable direct `move_and_slide()` locomotion path and default CharacterBody floor/snap settings. In the test arena, ordinary and shallow-wide stair blocks are visual graybox geometry only; each staircase has one hidden convex ramp collider aligned from the arena floor to its top platform. Discrete ledge blocks remain useful jump/blocking tests and are not automatically climbed.

## Locomotion states

- `GROUNDED` follows `CharacterBody3D.is_on_floor()` and handles walk/sprint acceleration and ground deceleration.
- `AIRBORNE` begins on jump or when floor contact is lost and handles reduced air steering without no-input braking.
- `DODGING` begins only from grounded input. When its timer finishes, the controller resolves to `GROUNDED` or `AIRBORNE` from actual floor contact.

Sprint remains a held movement modifier rather than an exclusive state. Jumping is represented by `AIRBORNE`; there is no duplicate `is_grounded`, `is_jumping`, or `is_dodging` flag. Enable `debug_locomotion_transitions` on the Player to log state changes only when they occur. Future traversal states can extend the enum and state dispatch, but none are implemented yet.

## Grounded movement feel — 0.03C

The previous grounded motor moved the complete horizontal velocity vector toward its target with one acceleration value. During a sharp turn, that single limited change budget had to remove old-direction momentum and build new-direction speed simultaneously, causing prolonged diagonal drift and slow braking.

Neutral grounded locomotion now separates current horizontal velocity into components parallel and perpendicular to the camera-relative desired direction. With no input, velocity moves toward zero using `ground_deceleration`. With aligned input, the parallel component approaches the 5.0/8.0 m/s target using `ground_acceleration`. As velocity/input alignment falls below `turn_alignment_threshold`, response blends toward `turn_acceleration`, while the obsolete perpendicular component independently decays toward zero using up to `lateral_damping`. A reversal retains a brief planted transition because its negative parallel speed moves deterministically through zero rather than snapping.

Default grounded tuning is `ground_acceleration = 28.0`, `ground_deceleration = 42.0`, `turn_acceleration = 70.0`, `lateral_damping = 85.0`, `turn_alignment_threshold = 0.7`, and `ground_rotation_speed = 16.0`. All rates are delta-based. Walk remains 5.0 and sprint remains 8.0. Grounded facing uses the faster dedicated rotation value; existing air, dodge, and attack-facing rotation retains `rotation_speed = 12.0`.

Attack motion still returns before the neutral grounded motor and remains owned by `CombatController`; dodge retains its state-owned velocity. Airborne acceleration, air control, jump velocity, gravity, and fall behavior are unchanged. The animation BlendSpace remains driven by actual horizontal velocity, so starts, turns, and braking visually track real motor speed rather than input state.

Remaining presentation limitations include forward locomotion cycles during strafing/reversals and no authored stop or pivot animations. Everdeep 0.03D should address jump/fall feel separately without folding those changes into this grounded motor.

## Jump / fall feel — 0.03D

The previous jump used one `gravity_multiplier = 1.5` for ascent, apex, and descent. The resulting symmetrical low-gravity arc spent too long rising and falling, making the apex and descent feel light. The current fixed-height action jump uses the project-tuned `jump_velocity = 8.0`, applies `rise_gravity_multiplier = 2.0` while vertical velocity is positive, and switches to `fall_gravity_multiplier = 3.0` at and below the apex. No separate apex rule or jump-cut behavior is needed because the stronger falling branch engages as soon as upward motion ends. Downward velocity is capped at `max_fall_speed = 35.0` for long-fall stability.

Horizontal air behavior retains the existing steering model: takeoff preserves current momentum, no-input air movement retains it, and input steers toward walk/sprint velocity using the existing `acceleration = 22.0` scaled by `air_control = 0.4`. A narrow takeoff-frame guard now prevents the still-valid pre-`move_and_slide()` floor contact from delegating a positive jump impulse back to the grounded braking motor. The 0.03C grounded velocity resolver and all six grounded tuning values are unchanged.

The Player now explicitly uses `floor_snap_length = 0.3`. Godot applies floor snap only while velocity is not moving upward, so the existing positive jump impulse leaves the floor cleanly while small descending terrain changes retain better adhesion. Ground contact still uses the existing `-0.5` downward hold and resolves landing without clearing horizontal momentum.

The locomotion AnimationTree is extended to a three-state `Locomotion → Jump → Fall → Locomotion` state machine. `Locomotion` remains the existing actual-horizontal-speed BlendSpace1D. Jump uses the non-looping `mixamo_com` clip from `Jump (1).fbx` (1.0 s); Fall uses the looping `mixamo_com` clip from `Falling Idle (1).fbx` (0.7 s). Physics locomotion state and vertical velocity drive short 0.08-second transitions. Runtime clip copies neutralize hips X/Z translation, including the Jump source's forward translation, so CharacterBody physics remains authoritative. Dodge intentionally stays on locomotion presentation until its own animation pass.

Known remaining 0.03D presentation issues were fixed use of one jump animation for standing/walking/sprinting takeoff, no landing recovery, and no dedicated ledge-fall transition pose. The following 0.03E section documents the first landing recovery and stabilized airborne transitions.

## Airborne animation stabilization — 0.03E

The 1.0-second Jump clip previously changed to Fall as soon as physics vertical velocity reached `-0.1 m/s`, roughly 0.35 seconds after takeoff. That correctly followed physics but truncated the authored launch/extension pose. Jump now plays at authored speed 1.0 for at least `jump_min_animation_time = 0.40` seconds and changes to Fall only when both that minimum has elapsed and vertical velocity is at or below `fall_transition_velocity = -0.5 m/s`. Ledge falls still enter Fall directly and never play Jump. Fall remains a looping 1.0-speed state.

Landing uses `res://Characters/Player/Animations/Falling To Landing (1).fbx`, imported clip `mixamo_com` (1.0667 s). The source reaches its impact/lowest hip position around 0.47 seconds, so Land begins with `land_clip_start_time = 0.30` at actual AIRBORNE-to-GROUNDED contact and exits after `land_exit_time = 0.65` seconds, around source time 0.95 when recovery is substantially complete. Land plays once at authored speed 1.0. Jump, Fall, and Land do not inherit locomotion speed scaling; no global playback scaling exists.

The visual state machine is `Locomotion → Jump → Fall → Land → Locomotion`, with direct `Locomotion → Fall` for ledges and `Jump → Land` for unusually short airtime. All transitions crossfade over `transition_blend_time = 0.15` seconds. Land never locks control; actual horizontal speed continues driving the preserved Idle/Walk/Run BlendSpace so return-to-locomotion selects the current physical speed naturally. The landing debug toggle logs physics edges, visual transitions, and accepted landing events only.

All airborne source clips are duplicated at runtime. Hips X/Z translation is pinned to the first key, removing forward/world presentation drift while retaining vertical skeletal compression and recovery. CharacterBody physics, 0.03D gravity/jump values, floor snap, air steering, and the full 0.03C grounded motor are unchanged.

Remaining visual checks include how the 0.30-second landing offset reads at different fall heights, whether the 0.45-second Jump hold fits standing and sprinting takeoffs equally, and blending from Land into sharp moving turns. Dedicated heavy landing, landing control locks, fall damage, dodge animation, and attack animation remain out of scope.

### Landing root-height stabilization

Timing changes alone could not remove a visible midair bounce because the imported airborne clips use incompatible absolute `mixamorig_Hips` position tracks: Fall sits near Y 0.94 while Falling To Landing ranges from about Y 1.55 through Y 0.61 before recovering. Crossfading those tracks vertically displaced the entire rendered humanoid even though CharacterBody physics had already landed correctly.

Runtime copies of Jump, Fall, and Land now pin the complete hips position track to the base skeleton rest position `(0.0, 1.042749, 0.015543)`. Limb, spine, and hip rotation remain animated, so takeoff/fall/impact posing is preserved while visual world height follows only the CharacterBody. Locomotion clips continue preserving their authored vertical bob and neutralizing only X/Z translation. Landing timing defaults use the measured clip window: clip start time 0.30 s, exit time 0.65 s, and crossfade 0.15 s. These presentation changes do not modify physics landing detection, floor snap, velocity, gravity, or player control.

### Deterministic one-shot landing (0.03F)

The previous landing selector treated `grounded AND (visual state is Jump or Fall)` as if it were a landing event. Grounded is a persistent condition, so any interruption or visual-state perturbation that put the controller back into Jump/Fall while floor contact remained true could qualify Land again. There was one transition owner—the animation-controller script—and no AnimationTree conditions or automatic advance expressions to remove; the runtime AnimationTree only contains immediate graph edges and crossfades. The duplicate risk was the script's persistent-state test, not competing transition systems.

`PlayerAnimationController` remains the sole authority that calls state-machine `travel()`. It now initializes one `_was_grounded` value, reads the post-move `CharacterBody3D.is_on_floor()` contact once per animation physics update, and fires Land only on `not _was_grounded and is_grounded`. This catches both Jump-to-Land short-airtime cases and Fall-to-Land cases without requiring Fall to be the current visual. `_landing_active` locks the one-shot until the deterministic Land exit or a valid higher-priority airborne/dodge interruption. Remaining grounded, changing horizontal speed, or returning to locomotion cannot restart Land. `landing_event_count` and the default-off `debug_landing_events` toggle expose one concise `Landing event fired` record per accepted contact, plus physics and animation transition events.

Land still uses the non-looping `mixamo_com` clip from `res://Characters/Player/Animations/Falling To Landing (1).fbx`. The clearly named `land_clip_start_time = 0.30` replaces the ambiguous `land_start_offset` name and has the same single meaning: skip the source clip's pre-impact lead-in. The only Land exit rule is a fixed `land_exit_time = 0.65` seconds after entry. Runtime state changes crossfade by the preserved live `transition_blend_time = 0.15` seconds. No minimum-airborne-time filter was added because the existing floor snap and shallow/ramp traversal did not demonstrate contact chatter; adding one without evidence could suppress legitimate very short landings.

Airborne hips translation remains locked to the skeleton rest position, so the clip cannot move the CharacterBody or add world-height bounce. Ordinary movement continues throughout Land and the current horizontal-speed BlendSpace resumes immediately on exit. Jump velocity, rise/fall gravity, air control, floor snap, grounded movement tuning, dodge, and combat are unchanged. Remaining visual tuning is limited to subjective evaluation of the 0.30-second trim and 0.15-second crossfade at different fall heights and sharp moving turns; state timing is now deterministic rather than offset-driven.

### Landing animation temporarily deactivated

The 0.03F landing implementation above is retained as historical reference but is no longer active. `Falling To Landing (1).fbx` remains in the project for a future redesign, but PlayerAnimationController does not load it, create a Land node, or transition through Land. The active visual flow is now `Locomotion → Jump → Fall → Locomotion`, with the existing direct `Locomotion → Fall` path for ledge drops. On physical ground contact, Jump or Fall returns directly to the actual-speed Idle/Walk/Run locomotion blend. Landing timers, edge tracking, event counters, debug controls, and Land transitions were removed from the workflow. Physics, movement tuning, jump/fall presentation, dodge, and combat remain unchanged.

## Exploration locomotion refinement — 0.04A

Exploration locomotion now separates three concerns without replacing the stable CharacterBody controller: `LocomotionState` still owns physical `GROUNDED/AIRBORNE/DODGING` authority, `GroundMovementPhase` exposes `IDLE/STARTING/MOVING/STOPPING`, and `Gait` selects `WALK/RUN/TRAVEL_SPRINT`. The existing normal movement value of 4.0 m/s is preserved as Run, the existing maximum of 8.0 m/s is preserved as Travel Sprint, and the new deliberate Walk is 2.5 m/s. Ground acceleration 28, deceleration 42, turn acceleration 70, lateral damping 85, turn threshold 0.7, and ground rotation 16 are unchanged.

Controls are configurable InputMap actions: WASD requests Run, Left Ctrl (`walk`) requests Walk, and Left Shift (`sprint`) requests Travel Sprint. Shift first produces Run and must remain held with meaningful grounded movement for `travel_sprint_activation_delay = 0.70` seconds before Travel Sprint begins. Releasing Shift immediately returns the gait target to Run, while actual velocity decelerates through the existing motor and therefore blends the animation naturally. The sprint timer resets on stopped input, Shift release, Walk override, jump/floor departure, dodge, or combat movement override.

A true idle input begins `STARTING` for `movement_start_delay = 0.06` seconds. The current input direction is refreshed throughout that window and the existing rotation system begins turning the body, so direction changes do not launch along stale intent. Releasing input cancels STARTING without a movement burst. The delay is used only below `true_idle_speed_threshold = 0.10`; retained momentum after landing or another interruption bypasses it. Normal direction changes and 180-degree reversals remain MOVING and continue using the 0.03C turn/lateral resolver without a stop/start cycle.

Releasing movement from MOVING enters `STOPPING`. `movement_stop_commitment = 0.12` labels a future stop-animation window but does not freeze input, zero velocity, or replace physical braking. The phase becomes IDLE only after that window and after actual speed reaches the idle threshold. Any new movement input cancels STOPPING immediately and resumes MOVING. Signals expose `movement_started`, `movement_stopping`, `movement_stopped`, `travel_sprint_started`, and `travel_sprint_ended` for later authored animations.

The actual-speed Locomotion BlendSpace1D now contains Idle at 0.0, `Walking (9).fbx` / `mixamo_com` at 2.5, `Running (3).fbx` / `mixamo_com` at 4.0, and `Fast Run.fbx` / `mixamo_com` at 8.0. All locomotion clips loop, retain authored vertical motion, and have horizontal hips translation neutralized. Jump and Fall remain separate script-owned visual states; the previously disabled landing animation remains outside the library and state graph.

Jump interrupts ground timing immediately without changing the 8.0 jump impulse, 2.0/3.0 rise/fall gravity multipliers, 0.4 air control, or retained horizontal momentum. Held movement with meaningful velocity resumes MOVING after landing without an idle start delay. Dodge and combat reset gait timing and retain their existing velocity authority. Combat's stationary steering fallback now references `run_speed` rather than the newly literal `walk_speed`, preserving its previous 4.0-based calculation exactly.

Known shortcomings are the continued use of forward clips for lateral/backward movement, visible foot sliding where authored clip cadence differs from gameplay speed, and no dedicated start, stop, or pivot presentation. Authored Start/Stop/Pivot animations are the intended next animation pass; the new phases and signals provide their hooks without adding animation commitment that can override ordinary player control.

## Gait persistence and Start stabilization — 0.04B

0.04B corrects the 0.04A input model and removes coupling between gait and physical state. Normal WASD now requests WALK at 2.5 m/s. Holding Left Shift with meaningful movement requests RUN at the preserved 4.0 m/s normal-traversal speed. Continuing to hold Shift and movement for `sprint_activation_delay = 4.0` seconds promotes the independent gait to SPRINT at the preserved 8.0 m/s maximum. Releasing Shift selects WALK immediately, while the existing motor and air-control acceleration change physical velocity gradually rather than snapping it.

The three layers remain separate: `LocomotionState` is physical `GROUNDED/AIRBORNE/DODGING`; `GroundMovementPhase` is `IDLE/STARTING/MOVING/STOPPING`; and `Gait` is `WALK/RUN/SPRINT`. Jump, fall, ledge departure, and ordinary ground contact never assign a gait or clear `_sprint_hold_time`. Consequently `SPRINT + AIRBORNE + FALL` and `RUN + AIRBORNE + JUMP` are valid combinations. With Shift and movement held, RUN buildup continues through the air and SPRINT remains SPRINT. Releasing Shift in air selects WALK and clears buildup, but the unchanged air motor preserves momentum and approaches the lower target only through its existing limited steering acceleration.

Sprint buildup accumulates only while Shift and meaningful movement are held and the active gait is RUN. Once eligible, SPRINT remains selected while that intent continues. It resets when Shift is released, the character completes a genuine physical stop, Walk is deliberately selected, dodge begins, or combat takes movement authority. A brief no-input STOPPING interval preserves the timer so renewed Shift movement resumes eligibility immediately; reaching true IDLE resets it. Airborne state alone never resets gait or eligibility.

The previous STARTING phase used only `movement_start_delay = 0.06`, had no authored Start state, and therefore advanced into the locomotion loop after only a few frames. The timer has been removed. STARTING now immediately enters the non-looping `mixamo_com` clip from `Idle To Sprint.fbx` (0.8 seconds) through the runtime `MovementStart` node. The animation controller reports normalized playback progress, and gameplay permits STARTING → MOVING only after `start_animation_min_progress = 0.65` while movement input remains active—about 0.52 seconds at authored speed. Releasing input first cancels directly to IDLE and cannot cause a delayed burst.

During STARTING, input direction remains live, normal responsive rotation continues, and physics moves toward only `start_movement_scale = 0.25` of the requested gait speed. This gives immediate physical intention without visually reaching full Walk or Run while the start pose is still reading. One generic Start is used temporarily for both WALK and RUN; the separated gait value allows later Walk Start and Run Start clips without changing gameplay architecture. Godot reserves the literal state-machine node name `Start`, so the runtime authored-animation node is named `MovementStart` while its conceptual phase remains STARTING.

The actual-speed locomotion BlendSpace mappings remain `Walking (9).fbx` / `mixamo_com` at 2.5, `Running (3).fbx` / `mixamo_com` at 4.0, and `Fast Run.fbx` / `mixamo_com` at 8.0, with Idle at zero. Acceleration produces the Run-to-Sprint and Sprint-to-Walk visual blends; gait enums never force animation cadence ahead of physical speed. Jump and Fall remain separate presentation states, and the explicitly deactivated landing animation remains absent from the active workflow.

The default-off `debug_gait_phase_changes` option logs only phase changes, gait changes, Sprint eligibility, and physical transitions with the retained gait. The 0.03C ground resolver and 0.03D jump/fall physics are unchanged. Remaining manual concerns are whether 0.65 progress and 0.25 movement scale give the generic start enough visual weight for both WALK and RUN, whether four seconds is the right traversal threshold, and clip cadence/foot sliding across the 2.5/4.0/8.0 blend points. Dedicated Walk/Run starts, stops, and pivots remain the next animation work.

## Gait-specific start/stop presentation — 0.04C

Ground presentation now derives distinct transition clips from the already-separated gait and movement phase. The runtime state machine adds `WalkStart`, `RunStart`, `WalkStop`, and `RunStop` around the existing actual-speed `Locomotion` BlendSpace. Physical `GROUNDED/AIRBORNE/DODGING`, gait `WALK/RUN/SPRINT`, and phase `IDLE/STARTING/MOVING/STOPPING` remain independent; no combined gait-phase enum was introduced.

Exact runtime mappings use imported `mixamo_com` clips: Walk Start is `res://Characters/Player/Animations/Start Walking.fbx` (2.9333 s), Walk Stop is `res://Characters/Player/Animations/Stop Walking.fbx` (3.0 s), Run Start remains the temporary `res://Characters/Player/Animations/Idle To Sprint.fbx` (0.8 s), and Run Stop is `res://Characters/Player/Animations/Run To Stop.fbx` (0.9 s). All four are forced non-looping. Their authored hips tracks contain approximately 1.99 m, 1.21 m, 1.67 m, and 0.81 m of horizontal displacement respectively, so runtime copies pin hips X/Z to the first key while preserving vertical and skeletal motion. CharacterBody physics remains the sole source of world movement.

The clips differ enough to justify four normalized exits: `walk_start_exit_progress = 0.25` (about 0.73 s), `run_start_exit_progress = 0.65` (about 0.52 s), `walk_stop_exit_progress = 0.25` (about 0.75 s), and `run_stop_exit_progress = 0.75` (about 0.68 s). STARTING completes only after its selected clip reaches the threshold while input remains active. STOPPING completes only after its selected clip reaches the threshold, the existing minimum stop commitment passes, and physical speed reaches the true-idle threshold. These animation gates label the existing motor; they do not replace acceleration or braking.

Normal WASD from true Idle selects WalkStart; Shift plus movement from true Idle selects RunStart. A gait change while already MOVING remains in the locomotion BlendSpace: Walk-to-Run never plays an idle start, and four-second Run-to-Sprint eligibility accelerates naturally into Fast Run without replaying Idle To Sprint. If gait intent changes during STARTING, the already-playing start is allowed to reach its useful exit instead of restarting each frame.

Releasing input during STARTING cancels directly toward Idle with no delayed burst. New input during WalkStop or RunStop cancels STOPPING immediately and returns to the actual-speed locomotion blend without replaying a start, because retained velocity means the character never became genuinely idle. Sharp reversals remain MOVING and trigger neither stop nor start. Sprint currently uses RunStop directly as its temporary stop presentation.

Jump/Fall retains higher visual priority and can interrupt any start or stop immediately; gait and Sprint eligibility remain independent and persistent. Ground contact returns to the correct actual-speed loop without replaying a start. The landing animation remains deliberately disabled from the active workflow per the earlier stabilization decision, despite historical Land documentation. Dodge and combat continue to outrank ordinary ground presentation.

Known visual tuning needs are the long source Walk Start/Stop clips and whether their 0.25 exits select the best authored pose, whether RunStop reads naturally when entered from full Sprint, and crossfade appearance when cancelling a stop at different physical speeds. Dedicated pivot, directional turn, Walk/Run-specific alternate starts, foot IK, and landing presentation remain future work.

## Reactive transition clip windows — 0.04D

The long imported transitions are now treated as source material rather than mandatory full-length gameplay clips. WalkStart, WalkStop, and RunStart each use a small runtime profile consisting of source-normalized start/exit points, playback speed, blend-in, and blend-out. AnimationNodeAnimation start offsets seek into the original runtime copy, nested AnimationNodeTimeScale nodes apply only that transition's speed, and script-owned source progress supplies the deterministic exit. RunStop remains the unchanged 0.04C reference behavior.

`Start Walking.fbx` / `mixamo_com` is 2.9333 seconds. WalkStart uses source window `0.12 → 0.32`, playback speed `1.15`, blend-in `0.08 s`, and blend-out `0.10 s`, for about 0.51 seconds of useful presentation. Its physical target ramps from `walk_start_initial_movement_scale = 0.30` to full Walk by local window progress `walk_start_full_movement_progress = 0.75`; input direction and rotation remain live throughout. Releasing input cancels immediately, and changing to Run while already moving returns through the actual-speed locomotion blend rather than forcing the rest of WalkStart.

`Stop Walking.fbx` / `mixamo_com` is 3.0 seconds. WalkStop skips anticipation and idle tail with window `0.55 → 0.78`, uses speed `1.10`, blend-in `0.06 s`, and blend-out `0.08 s`, producing about 0.63 seconds of foot-plant/settle presentation. `walk_stop_motion_carry_time = 0.06 s` preserves only the already-existing horizontal velocity for the first few grounded stop frames, after which the unchanged ground deceleration finishes braking. It never adds velocity, translates a transform, bypasses collision, or survives an airborne transition; Fall immediately takes visual priority at an edge. Renewed input cancels WalkStop and crossfades to actual-speed locomotion.

`Idle To Sprint.fbx` / `mixamo_com` is 0.8 seconds. Temporary RunStart uses window `0.12 → 0.70`, speed `1.15`, blend-in `0.06 s`, and blend-out `0.10 s`, for about 0.40 seconds of presentation. Its target movement ramps from `run_start_initial_movement_scale = 0.40` to full Run by local progress `run_start_full_movement_progress = 0.65`. Input release and Jump cancel immediately; ordinary Walk-to-Run and Run-to-Sprint changes remain in the locomotion blend and never invoke this idle-only transition.

`Run To Stop.fbx` / `mixamo_com` remains exactly as in 0.04C: 0.9-second source, start at `0.0`, exit at `0.75` (about 0.68 seconds), playback speed `1.0`, `0.15 s` entry/exit crossfades, no motion-carry grace, and unchanged ground braking. Sprint continues using RunStop temporarily. All transition clips remain non-looping with hips X/Z neutralized; CharacterBody physics owns world motion.

No gait speed, acceleration, deceleration, turn response, lateral damping, rotation, jump impulse, gravity multiplier, or air-control value changed. Remaining manual tuning is primarily pose selection inside the long WalkStart/WalkStop sources, whether the 0.06-second WalkStop carry best aligns the foot plant, and cancellation blends at very low versus near-gait speed. RunStop should be treated as locked unless a later explicit task reopens it.

## Canonical Blender/GLB Animation Pipeline Test

The canonical source `D:\Godot 4.7\Projects\Everdeep\Character Test.glb` was copied without deleting or modifying it to `res://Characters/Player/Models/Character Test.glb`. Godot imports one identity-transform scene root containing `Armature_006` at uniform scale `0.01`, one 65-bone skeleton at `Armature_006/Skeleton3D`, two visible and skinned mesh surfaces (`Beta_Joints` and `Beta_Surface`), and one `AnimationPlayer` at the scene root. Rendered midpoint checks and finite-transform sampling show normal deformation, sensible approximately 1.81 m scale, upright orientation, and no missing-track or exploding-limb errors.

The empty/default AnimationLibrary contains 11 clips: `Idle` (8.3667 s), `Jump` (1.7000 s), `Run Forward` (0.7333 s), `Strafe Run Left` (0.7000 s), `Strafe Run Right` (0.7000 s), `Strafe Walk Left` (0.9333 s), `Strafe Walk Right` (0.9667 s), `T_Pose` (0.0667 s), `Turn Left` (1.2000 s), `Turn Right` (1.2000 s), and `Walk Forward` (1.0000 s). All imported with `Animation.LOOP_NONE`; expected cyclic clips therefore require loop metadata correction in Blender/export or deliberate production import settings.

Every clip has a keyed `mixamorig_Hips` position track. Idle, Jump, and both Strafe Run clips have negligible end-to-end translation. At Blender-space scale, Run Forward changes about `(0, 3.408, 0.044)`, Walk Forward about `(0, 2.093, 0.027)`, Strafe Walk Left about `(0, -1.348, 0.036)`, Strafe Walk Right about `(0, 0, -2.384)`, Turn Left about `(1.084, 0, -2.028)`, and Turn Right about `(-2.034, 0, -1.077)`; the imported armature's 0.01 scale makes these residuals centimeters in Godot. Forward Walk/Run remain effectively in-place horizontally and do not move the preview wrapper, but their retained hips motion and the larger strafe/turn residuals should be reviewed in Blender before production integration.

`res://test/animation_lab.tscn` and `res://test/animation_lab.gd` provide an isolated Node3D preview with graybox floor, neutral environment, fixed camera, runtime clip discovery, diagnostics, direct selection, 0.15-second optional crossfade, pause/replay, 0.25x–2.0x speed inspection, runtime-only loop overrides, and wrapper reset. It does not depend on or modify production Player, movement, combat, camera, or animation code. The Blender-to-GLB pipeline is validated for a single shared mesh/skeleton with multiple readable named clips. Known gaps are absent Fall and dedicated Idle/Walk/Run naming conventions from the example set, missing loop flags, and residual hips translation; individual visual loop seams still need hands-on review after loop metadata is corrected.

## Canonical Locomotion Lab

Open `res://test/canonical_locomotion_lab.tscn` and press F6 to run the isolated playable canonical-character test. It instances only `res://Characters/Player/Models/Character Test.glb`; production Player, camera, combat, movement, animation controller, AnimationTree, and the configured `res://test/test_arena.tscn` main scene are not dependencies. Controls are camera-relative WASD, Shift for Run, Space for grounded Jump, captured-mouse orbit, Escape to release the mouse, and left click to recapture it.

`PlayerTest` is a simple CharacterBody3D with a 0.34 m-radius, 1.8 m-tall capsule centered 0.9 m above its origin. Initial test tuning is Walk 3.0 m/s, Run 5.0 m/s, ground acceleration 22.0 m/s², ground deceleration 30.0 m/s², visual rotation response 12.0, Jump velocity 7.0 m/s, gravity multiplier 2.0, and air control 0.35. The fixed orbit camera uses a 4.5 m spring arm, 52-degree FOV, -55/+35-degree pitch limits, and 0.003 mouse sensitivity. The arena provides a large flat floor, two shallow box ramps, and two low platforms/drop edges; no stair solver or production movement feature is involved.

At runtime the lab builds one AnimationTree state machine using the canonical GLB's own AnimationPlayer: `Locomotion ↔ Jump`. Locomotion is a BlendSpace1D driven by actual horizontal velocity, with `Idle` at 0.0, `Walk Forward` at 3.0, and `Run Forward` at 5.0. All clips use fixed authored playback rates; velocity changes only the blend weight and never seek, replay, or time-scale a loop. `Idle`, `Walk Forward`, and `Run Forward` are switched to `LOOP_LINEAR` only on the instantiated runtime resources, leaving GLB import metadata untouched. `Jump` remains non-looping, is entered once for an intentional grounded Space press, preserves horizontal movement, and returns once after floor contact.

Because the exported character faces +Z, the lab rotates `VisualRoot` so its +Z basis follows the camera-relative travel direction; physics math remains conventional and the GLB hierarchy is unchanged. Walking off an edge without pressing Jump leaves the current Locomotion blend visible until landing, which is the deliberately minimal fallback until a canonical Fall clip exists. Forward animation is also reused for backward and lateral travel in this phase.

Automated playable checks confirm continuous runtime loops, actual-speed Walk/Run blending, 3.0/5.0 target speeds, stable Run selection, grounded-only Jump, airborne horizontal preservation, and clean landing return without state re-entry errors. In the lab this shared skeleton/library is substantially simpler and more predictable than dynamically copying animations from separate FBX scenes: every node targets the same 65-bone skeleton directly, with no compatibility copy, root-neutralization copy, or per-source loading step. Remaining hands-on judgments are loop seam quality, fixed-cadence foot sliding between exact blend points, the Idle/Walk/Run blended poses during rapid acceleration, and the temporary lack of directional and Fall clips.

## Combat prototype 0.02A

The Player contains `CombatController` and `VisualRoot/WeaponSocket`, with a placeholder weapon and child melee `Hitbox`. Combat uses `NEUTRAL` and `LIGHT_ATTACK`, with phases `STARTUP`, `ACTIVE`, and `RECOVERY`. Defaults are 0.18 s startup, 0.12 s active, and 0.30 s recovery. The hitbox is enabled only during Active and deals 20 damage.

The Light Attack uses an `INHERIT_MOMENTUM` motion profile rather than a global movement multiplier. Attack start captures horizontal velocity, direction, and speed; retains 85% of that velocity; and applies deliberate linear decay rather than repeatedly targeting a near-zero walk speed. Defaults are `attack_momentum_retention = 0.85`, `attack_momentum_decay = 3.0 m/s²`, `attack_steering_strength = 0.20`, and `attack_rotation_multiplier = 0.30`.

Startup uses half decay and limited steering, Active uses full decay and half steering, and Recovery uses moderate decay with stronger steering so ordinary control blends back naturally. Steering changes the inherited motion gradually and cannot instantly reverse it. Facing is captured at entry, accepts only a small correction during Startup, and remains committed afterward. Stationary attacks inherit zero movement and do not add a procedural lunge. Sprinting Light Attack still selects the normal Light Attack, but its higher entry momentum is retained within the same bounded profile. Future attacks may define other profiles such as authored forward steps or lunges; none are implemented yet. Extra attack inputs are ignored. Attacks begin only while grounded, cannot begin during dodge, and cannot be interrupted by dodge or jump.

`DamagePacket` carries damage, source, hit position, and hit direction. `MeleeHitbox` clears its target-ID set at attack start, so each Health component can be damaged only once per swing while different targets can each be hit. `Hurtbox` contains no entity-specific behavior and forwards packets to its assigned `HealthComponent`. Health exposes maximum/current health and emits `damaged`, `health_depleted`, and `health_reset` signals.

Each target dummy has 100 health, flashes and tilts on damage, compresses on depletion, and resets after 1 second. Hit stop is localized: a confirmed hit pauses the attack timeline, inherited attack motion, and weapon swing for 0.05 s. It does not erase the stored momentum, change `Engine.time_scale`, pause the SceneTree, or interrupt camera/input processing.

Combat collision separation:

- Layer 1: existing world and physical bodies
- Layer 3 (`4`): melee hitboxes
- Layer 4 (`8`): hurtboxes

Weapon hitboxes mask only hurtboxes and do not collide with world geometry. Enable `debug_combat_events` on `CombatController` or `debug_hits` on `Hitbox` for concise event logging; both default off.

## Known limitations

The imported presentation model keeps its original 65-bone Mixamo skeleton, two skinned meshes, and materials. `PlayerModel` uses scale 1, a local Y offset of `-0.9` to place its feet at the CharacterBody origin, and a 180-degree Y rotation to convert the asset's +Z presentation facing to Everdeep's -Z gameplay facing. The existing camera pivot remains unchanged because the approximately 1.81 m model matches the 1.8 m collision capsule.

The base skeleton is `VisualRoot/PlayerModel/RiggedHumanoid/Skeleton3D`. Locomotion uses the imported `mixamo_com` clips from `Idle (6).fbx` (8.3333 s), `Walking (9).fbx` (0.9667 s), and `Running (3).fbx` (0.7 s). All sources have the same 65 Mixamo bone names and `Skeleton3D` track paths, so direct animation reuse is reliable and no BoneMap, SkeletonProfileHumanoid, or retargeting layer is required. `Running (3)` was selected over the shorter, faster-cadence `Fast Run` for the current 8.0 m/s sprint.

`AnimationTree` contains a runtime-built `BlendSpace1D` named `Locomotion`, with Idle at speed 0.0, Walk at 5.0, and Run at 8.0. `PlayerAnimationController` drives it from `Vector2(velocity.x, velocity.z).length()`. Clips loop linearly. Their duplicated hip-position tracks retain vertical motion but pin X/Z to the first key, preventing animation translation from affecting presentation while `CharacterBody3D` remains authoritative. No playback-speed scaling is applied in this foundation pass; minor foot sliding, backward/strafe use of the forward cycle, and airborne reuse of locomotion are expected.

Jump/fall/land animation is the next planned animation pass. Dodge and attack animation remain unwired. The existing prototype `WeaponSocket` remains under `VisualRoot`, not a hand bone, so the placeholder weapon is expected to float beside the rig until a later skeleton-socket pass. The weapon-socket arc is temporary prototype visualization, not the future animation system. Combat has one light attack only: no combos, buffering, stamina, lock-on, player health, enemy attacks, armor, poise, or final VFX/audio. Jump has no buffering, coyote time, variable height, or extra jumps. There is no automatic step-up, mantle, or ledge-climb behavior; traversable architectural stairs should use ramp or sufficiently shallow collision. Mouse/keyboard is the only configured input scheme. Camera collision uses the spring arm's default shape.
## Canonical master-rig production integration (2026-09-05)

- Production `Player` now instances `res://Characters/Player/Models/Blender Master Rig.glb` directly. The legacy `player_model.tscn`, standalone animation FBXs, and animation labs remain in the project as non-production reference assets.
- The canonical GLB contains one 65-bone `Skeleton3D`, two visible skinned meshes (`Beta_Joints` and `Beta_Surface`), one `AnimationPlayer`, and 846 imported actions. Its internal armature conversion/scale is retained; the existing production visual offset and 180-degree facing correction remain on the scene instance.
- Core actions selected from the master file: Idle `IDL_IDLE_A`, Walk `LOC_WALKING`, Run `LOC_RUNNING_FOWARD_A`, Sprint `LOC_SPRINT_FORWARD`, Jump `AIR_STANDING_JUMP_(2)`, Fall `AIR_FALLING_IDLE`, and Land `AIR_FALLING_TO_LANDING`.
- The source naming typo in `LOC_RUNNING_FOWARD_A` is intentional and must remain exact. Useful alternatives left available include `IDL_IDLE_B/C/D`, `IDL_IDL_E`, `LOC_STANDARD_RUN`, and 259 `_RAW` actions.
- Idle/Walk/Run/Sprint/Fall loop; Jump and Land are one-shots. Locomotion presentation is gait-driven so the Run action remains stable while Run is selected. Start/stop/pivot clips are deliberately excluded from the production state machine for this pass.
- Imported hip translation is normalized at runtime on duplicated core actions. Horizontal motion remains owned by `CharacterBody3D`; Jump/Fall/Land also have vertical hip translation pinned to the Idle reference to prevent visual displacement from fighting physics.
- The legacy movement-phase callbacks are fulfilled immediately because start/stop presentation is omitted. This preserves the existing locomotion state contract without changing tuned movement, camera, collision, input, or combat scripts.
- The normal playable arena (`res://test/test_arena.tscn`) is restored as the project main scene.
- Repository note: no `.git` metadata was present in the project directory during this integration, so a Git-history backup could not be created. Legacy assets were preserved, and no source assets were deleted.

## Everdeep 0.05A — airborne locomotion pass (2026-09-05)

- Canonical actions remain `AIR_STANDING_JUMP_(2)` for Jump, looping `AIR_FALLING_IDLE` for Fall, and `AIR_FALLING_TO_LANDING` for ordinary Land. Jump and Land remain one-shots; no hard-landing action is active.
- Initial airborne tuning: Jump source start `0.12`, minimum Jump presentation `0.28 s`, Jump playback `1.0x`, Fall entry at vertical velocity `<= -0.5 m/s`, Jump blend-in `0.10 s`, and Jump-to-Fall blend `0.12 s`. Fall uses its authored fixed playback rate.
- Current manually tuned ordinary-Land values: Land source start `0.90`, source-normalized exit `1.00`, playback `1.50x`, blend-in `0.08 s`, and blend-out `0.50 s`. These supersede the initial 0.05A defaults and retain only the final plant/settle portion while using the longer blend-out to soften the return to locomotion.
- A positive vertical launch on the grounded-to-airborne edge selects Jump. Jump remains committed until both its minimum visual time has elapsed and physical velocity has descended to the Fall threshold. A floor-loss edge with non-positive/downward velocity selects Fall directly and never plays Jump.
- Land is driven only by a recorded physical `AIRBORNE -> GROUNDED` transition. A per-airborne-cycle arm is consumed at contact, and cannot arm again until another genuine airborne entry; `landing_trigger_count` is available for optional debug verification. Initial spawn floor acquisition is explicitly excluded, preventing a false startup Land.
- Airborne debug output is Inspector-controlled and defaults off. It reports physical state, animation state, vertical velocity, Jump elapsed time, and landing trigger count on relevant state changes.
- Gait remains an independent Player value throughout Jump/Fall/Land. The locomotion blend continues tracking Walk/Run/Sprint underneath the airborne override, so Land exits to the currently valid gait or Idle without forcing an Idle reset.
- Animation state changes do not write velocity. Existing horizontal momentum, air control, jump velocity, rise/fall gravity, and sprint logic are unchanged. Ordinary Land is presentation-only and does not lock movement.
- Hard land, long-fall recovery, fall-to-roll, fall damage, IK, traversal, combat animation, pivots, and start/stop refinement remain deferred.
- Recommended hands-on tuning order: adjust `land_clip_start` in 0.02 increments to place the visual impact on floor contact; then adjust `land_exit_progress` for recovery length. If Jump reads too briefly near the apex, try `jump_min_animation_time` between `0.28–0.34 s`; retain the physical Fall threshold near `-0.5 m/s` unless a clear visual pop remains.

## Everdeep 0.05A.2 — gait-aware Jump selection (2026-09-05)

- Intentional takeoff now chooses exactly once between `AIR_STANDING_JUMP_(2)` and `AIR_RUNNING_JUMP`. The choice is stored as `JumpType.STANDING` or `JumpType.MOVING` until Fall; changing horizontal speed or direction in midair cannot morph or restart the selected clip.
- `standing_jump_speed_threshold = 0.30 m/s` uses actual horizontal velocity at the grounded-to-airborne launch edge. Speeds at or below the threshold select StandingJump, allowing small stopping/deceleration residue to retain standing body language. Any meaningful Walk, Run, or Sprint takeoff selects MovingJump.
- StandingJump preserves the current hands-on tuning: source start `0.50`, minimum visual time `0.28 s`, and playback `1.0x`. MovingJump begins at source start `0.00`, uses minimum visual time `0.32 s`, and playback `1.0x`; these are independent Inspector settings because the source actions are `0.8667 s` and `0.9333 s` respectively.
- Both Jump actions are one-shots with hips translation fully normalized on runtime duplicates. `AIR_RUNNING_JUMP` contains substantial authored translation, but it cannot affect the CharacterBody or visual world position after normalization.
- The shared physical transition remains unchanged: the selected Jump can enter looping `AIR_FALLING_IDLE` only after its own minimum presentation time and vertical velocity `<= -0.5 m/s`. The current user-tuned Jump-to-Fall crossfade remains `0.50 s`.
- Edge falls still bypass both Jump states: a new airborne edge without positive launch velocity enters Fall directly. Land remains the single ordinary `AIR_FALLING_TO_LANDING` state with the existing one-trigger-per-airborne-cycle guard and current manual tuning.
- Walk Jump uses MovingJump while retaining Walk gait and momentum. Run Jump and Sprint Jump also use MovingJump while preserving their logical gait, horizontal momentum, Sprint eligibility, and existing air control. A dedicated Sprint Jump and directional forward/back/side variants remain deferred.
- No Player physics, jump impulse, gravity, acceleration, air control, momentum, camera, collision, combat, Land selection, or root-motion behavior changed in 0.05A.2.
- Manual review should focus first on MovingJump takeoff timing. If its first pose contains too much running lead-in, try `moving_jump_clip_start = 0.05–0.12`; if it falls too early visually, try `moving_jump_min_animation_time = 0.32–0.38 s`. StandingJump retains the user-tuned `0.50` source start unless reopened deliberately.

## Contact-triggered interruptible landing rewrite (2026-09-05)

- Ordinary Land continues using the canonical `AIR_FALLING_TO_LANDING` one-shot. The source is `1.10 s`; runtime presentation seeks directly to normalized `land_clip_start = 0.90`, exits at `land_clip_exit = 1.00`, and plays at `1.50x`. This retains the current impact-pose selection while avoiding its pre-contact falling section.
- The landing event is the animation controller's observed physical `AIRBORNE -> GROUNDED` edge. Because `EverdeepPlayer` calls `move_and_slide()` and resolves its locomotion state afterward, the controller sees the edge only after the physics step establishes real floor contact. Contact immediately interrupts Jump/Fall and travels to Land; no Fall timer, Fall-loop completion, velocity prediction, or animation completion triggers it.
- Each real airborne episode arms one landing opportunity. Contact consumes that arm before entering Land, and remaining grounded cannot retrigger it. Initial spawn floor acquisition is excluded. `minimum_land_air_time = 0.06 s` filters brief ramp/stair floor noise; shorter episodes return directly to Locomotion without incrementing `landing_trigger_count`.
- Land has a presentation-only `land_min_impact_time = 0.08 s`. Player input, acceleration, braking, air control, and horizontal velocity continue normally throughout; this timer controls only when the animation may blend away.
- Land-to-Locomotion uses `land_blend_out = 0.12 s`. Fall/Jump-to-Land uses `land_blend_in = 0.04 s`, keeping the first impact frames close to the physical contact instant. These responsive values supersede the earlier manually experimented `0.50 s` Land blend-out.
- With movement input held or pressed during Land, the animation exits immediately after the 0.08-second impact window. The existing gait-owned Locomotion BlendSpace is already targeting Walk, Run, or Sprint, so the blend destination is the current gait rather than a forced Walk/Idle state.
- Without movement input, Land remains until both the minimum impact time and `land_clip_exit` are reached, then blends to Locomotion; actual horizontal speed determines whether that blend resolves visually to retained motion or Idle. No separate idle/moving Land actions were added.
- A valid new Jump creates a fresh airborne edge with positive vertical velocity, immediately selects StandingJump or MovingJump, and cancels Land. Dodge continues to cancel ordinary presentation. Land is never restarted on grounded frames.
- Optional debug output now includes airborne-episode activity, air time, ground-contact visibility decision, animation state, vertical velocity, Jump/Land elapsed time, trigger count, and current gait. Debug remains off by default.
- No jump velocity, rise/fall gravity, air control, Walk/Run/Sprint speed, Sprint buildup, ground acceleration, braking, turn response, collision, camera, combat, root motion, or gait-aware Jump selection changed.
- Suggested hands-on range: `land_clip_start = 0.86–0.92`, `land_min_impact_time = 0.06–0.10 s`, `land_blend_in = 0.02–0.05 s`, and `land_blend_out = 0.08–0.15 s`. Tune clip start first against the exact contact pose, then impact time, then blend-out responsiveness.

## Predictive landing animation sensor (2026-09-05)

- Production Player now contains `Player/LandingProbe`, an enabled `ShapeCast3D` positioned locally at `(0, 0.12, 0)` near the feet. It uses a `SphereShape3D` with radius `0.20 m`, casts straight down `0.40 m`, uses collision mask `1` for world/ground bodies, ignores areas, and excludes its parent CharacterBody.
- `landing_probe_distance = 0.40 m` is Inspector-tunable under Landing Anticipation. The controller updates the cast target and forces a current sensor query only while processing Fall/LandPrep presentation; it never changes CharacterBody grounding or motion.
- `landing_imminent` is true only while the physical locomotion state is AIRBORNE, vertical velocity is negative, and LandingProbe reports valid ground. It becomes false on contact, probe miss, ascent, dodge/incompatible presentation, or return to ordinary states. It is animation information, never a grounded flag.
- The AnimationTree adds an explicit `LandPrep` state driven by the same canonical `AIR_FALLING_TO_LANDING` action. LandPrep uses the pre-impact window `0.72 -> 0.88`, playback `0.75x`, and a `0.06 s` Fall-to-Prep blend. If it reaches `0.88` before contact, its time scale pauses so it cannot visually play the impact while the CharacterBody is still airborne.
- Descending Fall enters LandPrep when the probe hits. Losing the probe cancels LandPrep back to looping Fall; unexpected ascent cancels toward the already-selected StandingJump or MovingJump. No control, velocity, gait, air-control, or collision response is changed by either transition.
- Real post-physics `AIRBORNE -> GROUNDED` contact remains authoritative. It interrupts either Fall or LandPrep immediately and enters the existing Land impact state at normalized `0.90`; LandPrep never needs to finish. If the probe never fires, contact still travels directly from Fall to Land using the same one-shot/air-time guards.
- The probe's modest 0.20 m radius is smaller than the player's 0.45 m capsule radius to reduce side-of-ledge false positives. Slopes and collision-layer-1 moving platforms can be detected, but surface-normal alignment and platform motion compensation are deliberately deferred.
- Existing contact Land behavior remains: minimum meaningful air time `0.06 s`, minimum impact read `0.08 s`, Land playback `1.50x`, blend-in `0.04 s`, blend-out `0.12 s`, moving-input interruption, gait-aware locomotion return, and exactly one trigger per airborne episode.
- Optional airborne debug output reports airborne/descending state, probe hit/miss through `landing_imminent`, configured distance, current animation state, air/Land elapsed time, contact decision, landing count, and gait. ShapeCast visibility remains available through Godot's collision-shape debugging.
- No jump/fall physics, momentum, Walk/Run/Sprint values, Sprint buildup, ground motor, camera, combat, root motion, snapping, IK, hard landing, or traversal behavior changed.
- Recommended manual ranges: `landing_probe_distance = 0.30–0.50 m`, `land_prep_clip_start = 0.68–0.76`, `land_prep_clip_exit = 0.84–0.90`, and `land_prep_blend = 0.03–0.07 s`. Tune probe distance first on normal and sprint falls, then verify edge misses before adjusting the clip window.

## Short-drop / trivial-airborne suppression (2026-09-05)

- Passive floor loss now begins as a presentation-only airborne hold: the CharacterBody is physically AIRBORNE while the existing Locomotion BlendSpace continues its current Walk, Run, or Sprint loop. `trivial_drop_distance = 0.30 m` is measured from the player origin to the closest LandingProbe collision point; the live, user-tuned `landing_probe_distance = 1.40 m` remains unchanged.
- The Player increments `jump_sequence` only when a valid jump input applies the existing impulse. The animation controller snapshots that marker, so intentional jumps immediately select StandingJump/MovingJump and completely bypass passive-drop suppression. A positive vertical launch remains a compatibility fallback for externally initiated/test launches; passive floor loss is descending and does not qualify. This marker does not alter movement state or physics.
- A passive fall commits only when the probe does not report ground within the trivial distance and either `fall_animation_min_air_time = 0.12 s` has elapsed or downward speed reaches `fall_animation_min_downward_speed = 1.0 m/s`. Nearby ground keeps locomotion presentation for the entire brief episode. If that ground disappears or becomes farther away, the same deterministic rule commits Fall.
- `fall_visual_committed` is one-way for each airborne episode. Once true, Fall/LandPrep remains authoritative until real contact, preventing Locomotion/Fall flicker even if probe results change near edges.
- Contact after an uncommitted passive trivial drop returns directly to Locomotion and does not play Land or increment `landing_trigger_count`. Contact after an intentional Jump or a committed Fall retains the existing minimum-air-time guard, predictive LandPrep, physical-contact Land trigger, interruption behavior, and tuned Land presentation.
- LandingProbe is sampled once per airborne animation update. It provides `probe_ground_detected`, closest vertical `probe_ground_distance`, `trivial_drop`, and the existing `landing_imminent`; no second sensor or competing grounded test was added. Collision mask `1`, sphere radius `0.20 m`, parent exclusion, and moving-platform-compatible body detection remain unchanged.
- Default-off airborne debug output includes physical grounded state, intentional-jump flag, airborne time, probe ground distance, trivial-drop result, Fall commitment, landing-imminent result, animation state, vertical velocity, and gait.
- Walk/Run/Sprint values, Sprint buildup, gait selection, horizontal momentum, acceleration, braking, air control, jump velocity, gravity, floor snap, collision response, camera, combat, and root-motion policy are unchanged.
- Recommended manual ranges: `trivial_drop_distance = 0.20–0.40 m`, `fall_animation_min_air_time = 0.08–0.20 s`, and `fall_animation_min_downward_speed = 0.5–1.5 m/s`. Tune distance against curbs/stairs first, then air time for seam noise, and use downward speed only to control how promptly a clearly larger drop commits.

## Player Controller V2 — Phase 1 (2026-09-05)

V2 is the active architecture for new controller development. The main scene is now `res://test/player_v2_lab.tscn`: press F5 to launch the V2 player and lab, or open that scene and press F6. The reusable player is `res://Characters/Player/V2/player_v2.tscn`. Following Phase 1, the user requested this main-scene switch; `res://test/test_arena.tscn` remains available as the previous prototype arena.

### Archive and isolation

`res://legacy/preliminary_controller/` contains a verbatim snapshot of prototype player scripts/scenes, combat dependencies, previous tests/scenes, and the previous DEV_NOTES. Its README explains restoration and `.gdignore` prevents duplicate global classes and UIDs from being scanned. Original prototype paths remain available solely to keep the existing main scene functional. V2 has no script or scene dependencies on that prototype or archive.

### Canonical rig and actions

The sole visual is `res://Characters/Player/Models/Blender Master Rig.glb`, using its `Base Armature and Mesh/Skeleton3D` and `AnimationPlayer`. Runtime import inspection verified these exact action names:

| Purpose | Imported action |
| --- | --- |
| Idle | `IDL_IDLE_B` |
| Walk | `LOC_WALKING` |
| Run | `LOC_RUNNING_FOWARD_A` |
| Sprint | `LOC_SPRINT_FORWARD` |
| Standing Jump | `AIR_STANDING_JUMP_(2)` |
| Moving Jump | `AIR_RUNNING_JUMP` |
| Fall | `AIR_FALLING_IDLE` |
| Land | `AIR_FALLING_TO_LANDING` |

The master uses `FOWARD` (source spelling) and an underscore before `(2)`; these are the actual requested actions, not alternative clips. The animation layer duplicates the canonical library per player instance before setting loop modes and normalizing hips translation, so imported resources and the prototype remain untouched. For this Blender rig local X/Y are horizontal and local Z is vertical: grounded clips retain authored Z bob; airborne clips pin all hips translation to the Idle B reference. No clips are exported into FBX resources and no root motion drives gameplay.

### Movement and state interface

`player_v2.gd` owns input, gait, velocity, gravity, rotation, and `move_and_slide()`. It has no animation playback calls. A `player_animation_state.gd` RefCounted object is written after each physics step and read by `player_animation_v2.gd`. Processing priorities are motor 0, animation controller 10, AnimationTree 20.

Published fields: `horizontal_speed`, `vertical_velocity`, `is_grounded`, `was_grounded`, `is_airborne`, `is_falling`, `jump_started`, `takeoff_speed`, `move_input_magnitude`, `gait`, `run_buildup_ratio`, `air_time`, and `move_direction_world`. `jump_started` describes an accepted grounded jump for one physics frame. `was_grounded` describes the previous published physics frame. Animation never modifies these facts or the CharacterBody.

WASD without Shift requests Walk at 4 m/s. Shift plus movement requests Run with a target interpolated from 4 to 6 m/s over `sprint_buildup_duration = 4.0 s`; at the threshold, Sprint targets 8 m/s. Gait remains Run throughout buildup and the animation plays at fixed authored speed. Releasing Shift selects Walk; reaching a real grounded stop resets buildup, while airborne/no-input intervals retain it. Holding movement and Shift continues buildup in the air. No start/stop clips or movement delays are present.

Ground acceleration 28 m/s², braking 36 m/s², turn acceleration 65 m/s², lateral damping 80 m/s², facing response 16/s. Jump velocity 8 m/s, rise gravity 19.6 m/s², fall gravity 29.4 m/s², air control 0.4, terminal descent 35 m/s, floor snap 0.3 m. The grounded motor resolves forward and lateral velocity separately; the airborne motor retains momentum with no-input and preserves takeoff horizontal velocity. Camera yaw/pitch lives in `player_camera_v2.gd`, with sensitivity 0.12 degrees/pixel, pitch limits -55/+65 degrees, 4.5 m spring arm, and player collision exclusion.

### AnimationTree

A script-created state machine contains `Locomotion`, `JumpStanding`, `JumpMoving`, `Fall`, and `Land`. Locomotion is a synchronized BlendSpace1D: Idle=0, Walk=1, Run=2, Sprint=3. All four gait loops advance at fixed speed; only the gait blend changes. The target is selected by logical gait with input/speed used only to distinguish idle. Build-up speed never controls Run playback or introduces Sprint early. State travel occurs only when the requested discrete state changes; no repeated play/seek calls or dynamic speed scaling exist.

Independent durations per adjacent gait interval: Idle→Walk 0.15 s, Walk→Run 0.18 s, Run→Sprint 0.20 s, Sprint→Run 0.18 s, Run→Walk 0.18 s, Walk→Idle 0.20 s. A direct Sprint→Walk request crosses both intervals, taking about 0.36 s. Jump blend-in 0.08 s, Jump/Fall blend 0.12 s, Land blend-in 0.04 s, Land blend-out 0.12 s. These animation exports build the runtime graph when the scene starts; restart F6 after changing transition/clip-window defaults.

### Airborne presentation

At accepted takeoff, actual horizontal speed below `standing_jump_speed_threshold = 0.30 m/s` chooses StandingJump; speed at or above it chooses MovingJump. Selection happens once. Both begin at the authored start with fixed playback speed. Jump changes to Fall at vertical velocity <= -0.5 m/s; no clip-completion or visual-minimum timer alters the apex.

Passive floor loss keeps Locomotion until descending at <= -0.5 m/s and `fall_min_air_time = 0.12 s` has elapsed. Once Fall starts it remains until contact. There are no predictive or short-drop sensors.

Land triggers only on the published airborne→grounded contact edge, after a Jump/Fall was visibly presented and the player previously acquired ground. This excludes initial spawn and trivial floor loss. Each physical contact edge occurs for one frame; remaining grounded cannot repeat Land. Movement continues through Land. `land_clip_start = 0.50`, `land_exit_progress = 0.90`, `land_min_impact_time = 0.08 s`. Movement input exits after the impact interval; without input the source-window exit also must be reached. A new accepted Jump immediately interrupts Land. Gait/buildup are independent of this animation state.

### Lab, validation, and limitations

The lab provides a 64×90 m floor, a marked 70 m lane, a 15 cm curb, a 0.6 m low platform, and a 3 m platform with simple convex ramp collisions. Geometry is built by `test/player_v2_lab.gd` on launch. F3 toggles the optional overlay; Esc releases the mouse and click recaptures it.

`res://test/test_player_v2.gd` tests the actual motor against lab collisions: gait speeds/buildup, no premature Sprint blend, jump selection and momentum, Fall, contact Land count, no repeat Land, tiny-drop suppression, edge falls, ramp traversal, canonical action/library isolation, and unchanged main-scene setting. Run with Godot `--headless --path <project> --script res://test/test_player_v2.gd`.

Phase 1 intentionally omits combat, dodge, starts/stops, pivots, strafing, IK, prediction, and traversal. Authored fixed-rate loops may slide at the new Walk/Run speeds; tune movement speed or source selection in a later animation pass. Full-source jumps and contact Land may need manual pose timing review. Start with gait blends 0.10–0.25 s, fall minimum 0.08–0.15 s, and Land source start/exit against visible impact. Headless coverage validates behavior, not subjective animation feel or several minutes of human play.

## V2 landing visual compression (2026-09-05)

- Offset target: `PlayerV2/VisualRoot`, above the canonical `MasterRig` instance. Its base local position remains `(0, 0, 0)`. It has only a Y-facing rotation; local negative Y moves toward the floor independently of the imported skeleton's axes. No base correction was necessary: a rendered Idle B inspection measured the skinned mesh bottoms at approximately 0.00023–0.00027 m above the flat floor, with CharacterBody Y approximately 0.00047 m.
- AnimationController exposes `land_visual_sink_amount = 0.04 m`, `land_visual_sink_in_time = 0.05 s`, and `land_visual_recover_time = 0.12 s` under Landing Visual Compression. Amount 0 disables the effect; zero-duration settings are supported without division by zero.
- Compression reuses the existing Land source-window elapsed time (`_impact_time`) at fixed authored playback. It starts only when the existing actual-contact event enters Land. A smoothstep envelope reaches -0.04 m after 0.05 s, remains at peak through `max(sink_in_time, land_min_impact_time)` (0.08 s by default), then smoothly returns to neutral over 0.12 s. It is a brief impact envelope, not a full-clip sink.
- The permanent neutral position is captured once in `_ready()` as `visual_root_base_position`. Every frame assigns base plus the absolute vertical offset; no incremental position subtraction occurs. Rotation, scale, bones, GLB transform, and the collider are untouched. Completed recovery returns exactly to base, and removing the animation controller restores it.
- Moving Land exits retain the current depth and recover smoothly over the configured duration while locomotion and movement continue. A new Jump or Fall restores the base immediately to prevent a sunken airborne pose. Future non-airborne state interruptions use the same smooth recovery path. Tiny drops that do not enter Land never start compression.
- Existing live user tuning was preserved: `land_clip_start = 0.70`, `land_exit_progress = 0.90`, `land_blend_in = 0.10 s`, `land_blend_out = 0.12 s`, and `land_min_impact_time = 0.08 s`. Contact detection, short-drop filtering, gait, buildup, all movement/jump/gravity values, and camera code are unchanged. Capsule remains radius 0.45 m / height 1.8 m with local center `(0, 0.9, 0)`.
- `debug_land_visual_compression` defaults OFF on AnimationController. When enabled, the existing F3 overlay adds Land Visual Offset, VisualRoot Base Y, and VisualRoot Current Y.
- `test/test_land_visual_compression_v2.gd` passes standing/Run/Sprint contacts, repeated landings without drift, re-jump cancellation, smooth movement cancellation, a real ramp landing, tiny-drop suppression, and disabled/zero-duration settings. It checks that animation updates do not change the CharacterBody transform or velocity, collider transform/dimensions, or visual basis. Existing V2 integration coverage is retained.
- Rendered comparison of the same early Land pose with and without the effect confirmed downward translation at unchanged physical contact. The pose's feet still visibly float during the early crossfade; 4 cm only partially reduces that gap. This pass does not claim to eliminate the double-hop impression or alter the authored pose/hips normalization. Manual review of the existing clip window and blend may still be necessary in a later pass.
- Start manual tuning at 0.04 m / 0.05 s / 0.12 s; practical ranges are amount 0.02–0.06 m (up to 0.10 exposed), sink-in 0.02–0.08 s, recovery 0.08–0.18 s. Larger values can visibly bury feet, particularly on ramps; no ground-normal alignment or IK is applied. For the moving Land impact interval of 0.08 s, keep sink-in at or below that interval to reach full depth before the early locomotion exit.

## V2 landing visual calibration (2026-09-05)

This calibration supersedes the timed sink profile above. The base VisualRoot remains `(0, 0, 0)`; neutral alignment, CharacterBody, capsule, motor, camera, gaits, and short-drop/contact detection are unchanged.

### Diagnosis and measured source anchors

The main bug was in the prior AnimationNodeAnimation setup: `start_offset` was assigned but `use_custom_timeline` remained false. Godot therefore ignored the configured source offset and displayed the airborne lead-in, while the script's calculated source progress incorrectly assumed it started at 0.70. Runtime inspection confirmed the disabled flag and full 1.10-second node timeline. Godot documents that start_offset applies only when custom timeline is enabled: https://docs.godotengine.org/en/latest/classes/class_animationnodeanimation.html#class-animationnodeanimation-property-start-offset . The 0.10-second Fall-to-Land blend and a sink that took 0.05 seconds to develop further delayed visual contact.

Frozen sampling of the actual normalized V2 clip (skinned mesh vertices transformed into world space) found first near-contact at source progress about 0.24 (lowest sole roughly 0.014 m above the zero-height test floor). The deepest crouch is around 0.46–0.48: because V2 pins airborne hips translation to Idle height, its bent-leg pose lifts the soles about 0.41 m. That region cannot be grounded with the permitted subtle 0.03–0.08 m sink. At source 0.70, the gap is about 0.115 m; at 0.78 it is 0.062 m; at 0.80 it is 0.057 m. The later recovery/contact pose is consequently used as the visual anchor instead of the deep crouch. No bone-track or root-motion policy was changed.

### Final values and actual animation progress

- `land_clip_start = 0.80`; `land_exit_progress = 0.90` retained.
- `land_blend_in = 0.01 s`; existing 0.12-second blend-out and 0.08-second minimum impact interval retained.
- `land_visual_sink_amount = 0.05 m`, Inspector limit 0.08 m.
- `land_sink_entry_fraction = 0.85` (4.25 cm of offset immediately at contact).
- `land_sink_peak_progress = 0.20`; `land_sink_recover_progress = 0.75`.
- Progress is normalized over the remaining source clip from selected start to source end: `(source_progress - start) / (1 - start)`. Thus peak is at source 0.84, approximately 0.044 seconds into this Land window, and complete recovery would be at source 0.95, approximately 0.165 seconds into it. If Land exits earlier, cancellation recovery takes over smoothly from current depth.

Land now enables custom timeline, disables timeline stretching, and sets timeline length to the remaining source duration. Playback stays at authored speed. `land_source_progress` reads the evaluated state-machine position plus the node's actual offset; Land exit uses this real source progress. `land_window_progress` drives a smoothstep sink/recover profile in `AnimationTree.mixer_applied`, after pose evaluation. AnimationTree explicitly evaluates on the physics clock, matching the existing motor/controller/tree priorities and keeping interruption recovery independent of render frame rate; this changes presentation scheduling only. It no longer guesses sink progress from a separate time envelope. The previous `land_visual_sink_in_time` export is removed. `land_visual_recover_time = 0.12 s` remains only for interruption/blend-out recovery. A fresh jump restores the exact base immediately; repeated contacts cannot accumulate translation.

### Comparison, diagnostics, and verification

The presentation-only matrix compared source starts 0.70/0.74/0.78/0.80/0.82, blends 0.01/0.02/0.04/0.06 seconds, and sink amounts 0.03/0.04/0.05/0.06 m (80 combinations), followed by refinement of the entry fraction and progress domain. 0.06 m began penetrating the floor in later candidate poses, while 0.03–0.04 m left larger gaps. The 0.05 m choice preserves a small positive gap near impact.

Rendered real standing-jump contact with final settings measured lowest sole height about 0.0157 m on the first effective Land-pose sample, 0.0112 m on the next, and 0.0062 m near peak. The initial transition sample still contains the outgoing Fall pose (about 0.336 m in this capture); at 60 Hz it lasts roughly one physics frame before the short blend resolves. These are lowest skinned-sole measurements on flat ground, not proof that both feet are planted on every terrain surface. The resulting captured Land pose is visibly near the floor rather than the former tucked airborne pose. It uses a shallow recovery pose rather than the source's deep crouch; one transitional frame and exact foot placement remain manual-review limitations.

Optional `debug_land_visual_compression` remains OFF. The overlay adds source/window progress, contact frame, and both foot-bone world Y values. Debug logging captures entry/peak samples with contact time/frame, pose frame, offset, and `mixamorig_LeftFoot` / `mixamorig_RightFoot` positions. A debug-only downward ray estimates ankle height above ground; bone origins are ankles, not soles, and none of these queries drive motion or presentation.

Compression regression covers standing/Walk/Run/Sprint, evaluated early foot poses, frozen animation-progress behavior, repeated contacts, cancellation, real slope contact, zero settings, tiny-drop suppression, and unchanged collider/body/scale. Manual tuning should start near clip start 0.78–0.82, blend-in 0.01–0.02 s, amount 0.04–0.06 m, peak 0.15–0.25, recovery 0.65–0.85, and entry fraction 0.65–0.85. Restart the scene after editing graph timing defaults; test sink depth against flat ground and ramps before raising it.

## Standing-jump landing refinement (2026-09-05)

The user has since tuned the shared moving Land to source start 0.50, source exit 1.00, blend-in 0.10 s, and sink amount 0.25 m, and reports Walk/Run/Sprint jumps and landings feel good. Those live values are preserved exactly. They supersede the shared defaults in the previous calibration section. Standing contact with that profile measured a lowest-sole gap around 0.153 m on the first effective Land sample and 0.112 m two frames later despite the large sink; the deep crouch/longer stationary recovery makes that contact mismatch more apparent at rest.

A standing-only presentation profile now applies when a jump selected StandingJump at takeoff and contact occurs with horizontal speed below the existing 0.30 m/s threshold and no movement input. It is selected once at actual contact, using the same Land node/action and sink implementation. Passive falls and all moving takeoffs keep the shared profile. A standing takeoff that moves before contact also uses the shared profile. Starting to move after contact still interrupts Land through its original impact/exit rules. No physics, jump impulse, airborne timing, takeoff selection, gait, or camera values changed.

Inspector settings under Standing Jump Landing: `standing_land_clip_start = 0.80`, `standing_land_exit_progress = 0.95`, `standing_land_blend_in = 0.01 s`, `standing_land_sink_amount = 0.05 m`, `standing_land_sink_peak_progress = 0.20`, `standing_land_sink_recover_progress = 1.00`, and `standing_land_sink_entry_fraction = 0.85`. Progress remains relative to the remaining source clip. The later pose avoids the unsupported deep crouch; recovery spans more of the pose, then continues smoothly through the existing 0.12-second blend-out when the 0.95 exit is reached. Profiles are snapshotted at contact, without changing the shared exported values.

Rendered standing contact measured lowest sole gaps of approximately 0.0157, 0.0112, and 0.0062 m on successive effective Land samples. One initial outgoing-Fall blend sample remains; no claim is made that both feet are perfectly planted on all slopes. Neutral base remains `(0, 0, 0)` and jump/collider/body physics are unchanged.

The compression suite passes, including standing and all three moving gaits, actual early foot pose, exact return to base, cancellation, and slope contact. An additional comparison against the captured pre-change controller produced identical animation state, source progress, sink offset, gait blend, and Land count for 100 frames each of Walk/Run/Sprint jump/landing sequences. Thus the user's moving landing presentation was preserved rather than retuned. Debug samples now identify the selected standing profile.

For manual standing-only adjustment, start with source start 0.78–0.82 and sink amount 0.04–0.06 m; use recover progress 0.90–1.00 to soften the return to Idle. The Standing Jump Landing exports affect only this case. The shared Contact Land and Landing Visual Compression settings remain the moving/fall profile.

## Standing landing with fixed 0.40 source start (2026-09-05)

The user requires `standing_land_clip_start = 0.40`; it remains exactly 0.40. Their current standing exit 0.80 and blend-in 0.25 s are also preserved. This profile supersedes the later-pose recommendations above. Shared moving Land settings are unchanged.

Full rendered sampling of the blended standing pose showed the old sink peaked much too late: peak window progress 0.40 corresponds to source 0.64, well after the crouch begins recovering. `standing_land_sink_recover_progress = 1.5` was silently clamped to 1.0 by the implementation. The old profile left an initial 8 cm gap, then put the lowest sole approximately 21 cm below the floor during recovery.

Final standing sink settings: amount 0.36 m (previously 0.35), entry fraction 1.00, peak window progress 0.13, recover window progress 0.66, and new `standing_land_sink_tail_amount = 0.05 m`. Peak corresponds to source 0.478; recovery reaches the tail offset around source 0.796, just before the preserved 0.80 Land exit. The existing 0.12-second interruption/blend-out recovery then returns the tail offset exactly to the neutral base. Only standing Land uses the nonzero tail; moving Land retains its original zero-tail equation and values.

The relatively large standing translation is necessary for the specifically requested source 0.40 crouch under the existing fixed-height hips normalization: the evaluated pose's sole is about 0.36–0.38 m above the body origin before this offset. This is a correction for that pose, not a permanent model adjustment or collider change. The standing amount Inspector range now includes the actually used values (0–0.50 m). Changing to a substantially different source window would require recalibration; do not apply these values to moving Land.

Post-change rendered samples measured lowest sole Y from about -0.004 to +0.019 m across contact, Land, and return to Idle; most samples were within about 1 cm of the floor. At source 0.445 the gap was about 0.0006 m, and at source 0.779 about 0.0106 m. These are flat-floor lowest-sole measurements, not a claim of exact bilateral foot planting on every slope. The 5 cm tail avoids a second upward correction before the Idle crossfade.

Compression regression passes repeated standing contacts, profile selection, cancellation, zero-amount settings, slope contact, and unchanged body/collider/visual scale. The captured pre-change moving controller and revised controller produced identical 100-frame state/progress/sink/gait/contact-count sequences for Walk, Run, and Sprint. No movement, jump, camera, collision, or base-transform values changed. Tune standing amount near 0.35–0.36 m, peak near 0.12–0.15, recover near 0.64–0.68, and tail near 0.045–0.055 m while keeping source start 0.40.

## V2 Phase 2: grounded locomotion coverage (2026-09-05)

### Persistent T-pose / nested AnimationTree recovery (2026-09-05)

**Reproduced root cause:** the outer state machine re-entered Locomotion and reset its nested machine to `Start`. That nested machine had no `Start -> Loops` transition. The controller queued child `start(Loops)` before the parent had evaluated its re-entry; parent reset displaced the child to Start afterward. Logical `current_state = Locomotion`, grounded `_active = true`, and `transition = Loops` then caused ordinary equality guards to skip further travel. Actual child playback remained `Start`, playing=true, position=0, with no weighted animation source. Parent Locomotion and AnimationTree active=true looked valid in the old overlay while the mesh blended permanently into rest pose.

On the actual 0.6m platform, a Run reproduction left the floor at sample 23, selected Fall at sample 30, landed, then reached outer Locomotion / inner Start by sample 40. Inner Start remained at position 0 and the left-arm quaternion converged to its rest rotation through sample 95. Thus this particular reproduction did briefly commit Fall under the existing 0.12-second threshold; it was not a purely suppressed fall. A separate genuine 0.08m suppressed-drop reproduction showed a second bug: floor loss cleared grounded `_active` even while its presentation remained selected, then contact unnecessarily restarted the loop at time zero. Both paths are fixed without changing thresholds.

The nested graph now has an automatic, zero-crossfade `Start -> Loops` edge so every parent reset immediately resolves to a real pose source. The pre-parent-reset child start() call is removed. The grounded resource now relinquishes presentation only when the outer controller actually selects Jump/Fall/Land or another higher-priority owner. Passive floor loss alone keeps Loops, its gait/directional blend inputs, and its playback clock active. Physically grounded-only pivots/turns are cancelled back to Loops when necessary, without disabling the tree. On suppressed contact, loops continue with no restart or Land; released input reaches Idle through existing braking and gait blending.

A lightweight pre-transition consistency guard checks actual root playback, active flag, actual nested node and pending travel paths. It only repairs a stopped/empty/Start/End or displaced expected playback, not every frame; legitimate pending transitions and higher-priority Jump/Fall/Land are respected. A correct suppressed drop needs no recovery calls. This guard complements the graph-coverage fix rather than replacing it with repeated resets. There are no OneShot nodes or manually zeroed blend weights in this graph, and production floor handling did not deactivate AnimationTree. Existing `_episode_visible` represents an intentionally shown Jump/Fall episode; there is no separate `fall_visual_committed` field.

Enable `debug_tree_playback` on AnimationController (default OFF) to show logical presentation, actual parent and child nodes/playing flags, AnimationTree active, gait blend, visible airborne-episode flag and recovery count. This exposes both levels of playback instead of relying on the logical gait label. The old restored mesh condition now reads outer Locomotion / inner Loops with advancing position and changing bone poses.

New `test_animation_recovery_v2.gd` runs 20 real 0.6m platform drops alternating Walk/Run, including release in the air; every evaluated pose is checked against rest-arm rotations and nested empty states. It also verifies genuine suppressed-drop clock continuity/no Land/no recovery spam, pivot floor-loss handoff, meaningful higher-platform Fall, stopped child recovery, displaced root recovery, and a disabled-tree recovery. No new gameplay state was added. Movement, camera, gravity, jump, Fall threshold/airtime, landing calibration, and 180 tuning are unchanged.

### Run/Sprint entry-step carry-through (2026-09-05)

Run180 now retains its captured incoming horizontal velocity for the opening `run_180_carry_end_progress = 0.20` of the source, then pauses horizontally for the remaining turn and restores opposite-direction momentum on completion. At the correct 0.70-second Action and 1.0x, this is about 0.14 seconds of forward carry (plus normal entry scheduling). Animation starts immediately; only the horizontal plant is delayed. Incoming direction remains captured rather than following reverse input or rotating facing. This is a simple carry/plant switch, not another multi-phase speed curve. Tune the new setting under AnimationController > Grounded > Turn 180 near 0.15–0.25; zero restores the immediate pause. Walking profiles, rotation tuning, playback rate, gait/buildup restoration and Jump/release behavior remain unchanged. Tests check forward carry at stored speed, subsequent zero translation, and exact reverse-speed restoration.

### Correct Run180 Action selected (2026-09-05)

The intended Run/Sprint Action is **`LOC_RUNNING_TURN_180`**, verified in the canonical GLB at **0.70 seconds** (21 frames at 30 FPS). RunPivot now uses this exact non-RAW Action instead of the different 2.20-second `LOC_RUNNING_CHANGE_DIRECTION_180`. This resolves the source discrepancy described in the historical notes below; no replacement GLB, source trimming, or playback acceleration is required.

The simplified behavior is retained: moving Run/Sprint reversals at >=150 degrees pause only horizontal translation while the full source plays at default 1.0x, progressively rotate over normalized progress 0.15–0.90 (about 0.105–0.630 seconds), then restore captured target-direction speed and gait/buildup at source completion. The pause now naturally follows this 0.70-second clip, plus normal state-entry scheduling. Input release finishes without restoring momentum; Jump immediately cancels into MovingJump. Idle opposite requests remain arcs. Walking 180, all landing profiles, and motor tuning are unchanged. Regression tests now assert the exact Action name and 0.70-second source duration as well as pause/restoration behavior.

### Current: Run/Sprint 180 simplification (2026-09-05)

This supersedes the animation-led Run movement curve and idle pivots below. Dedicated turns now require horizontal speed > `moving_turn_min_speed = 0.30 m/s`. Idle opposite starts use the existing directional arc throughout, without escalating into a dedicated turn as they accelerate. Existing moving Walk180 source, 1.0x playback, stop/resume 0.30/0.55 movement profile and authored rotation curve are retained. WalkStart/WalkStop remain absent.

Run/Sprint use `LOC_RUNNING_CHANGE_DIRECTION_180`, with separate `run_180_trigger_angle = 150` degrees. On entry the coordinator captures source gait, entry speed, buildup, target direction and start facing once. While Run180 is active the motor explicitly sets only horizontal velocity to zero; gravity, floor checks, rotation and animation continue. The generic arc cannot fight the turn. The old `run_180_stop_progress` / `run_180_resume_progress` settings are removed; Run no longer uses a movement multiplier curve, arbitrary 0.1-second pause, or phased acceleration.

At evaluated clip end, if movement is still requested, horizontal velocity is restored exactly to captured target direction times captured entry speed for the completion tick. Normal acceleration/steering resumes afterward. Run/Sprint gait and buildup remain frozen at the entry state while Shift supports that gait; Sprint does not rebuild. If Shift is released, normal Walk selection applies and restored speed is capped at Walk speed. Released movement lets the turn finish visually but restores no momentum, exiting idle. Very different input does not continuously retarget or cancel an active Run180: the captured destination remains authoritative through the clip, then normal input resumes. Walking retains its existing more permissive release/retarget cancellation.

Jump cancels Run180 before horizontal/airborne processing. The stored speed is restored along current visual facing and reported as takeoff speed so the existing MovingJump selection applies; no stale freeze remains. Floor loss/non-locomotion suppression also cancel. These are explicit interruption paths, not delayed clip-end actions.

Playback defaults to **1.0x**, with `run_180_playback_speed` exposed only for manual 0.9–1.1 adjustment. At default, the source timeline is unmodified. A non-default manual rate uses a constant source-length/rate timeline, never an independently chosen pause duration. Rotation uses evaluated normalized progress with smoothstep over `run_180_rotation_start_progress = 0.15` through `run_180_rotation_end_progress = 0.90`; it begins and ends at the captured facings without a 180-degree start/end snap. Runtime hips yaw removal prevents double rotation. Walk's authored rotation curve is unchanged.

**Source discrepancy:** the brief describes a roughly 21-frame Run180, but the current imported canonical GLB Action still reports **2.200 seconds**, with its full turn spread across that duration. No 21-frame crop was guessed and the source was not sped up. Consequently the current default horizontal pause lasts that 2.2-second clip (plus ordinary state-entry scheduling), not ~0.7 seconds. A corrected shorter Action at the same path/name will automatically determine the pause length. Walk remains approximately 1.033 seconds. Use a corrected source if the expected 21-frame version is intended, rather than compressing this Action.

Settings live at AnimationController > Grounded > Turn 180. Keep playback at 1.0 initially; tune rotation start/end near 0.10–0.20 / 0.85–0.95 if needed. Debug defaults OFF and now includes Run180 active, stored entry speed, captured target, horizontal-pause status, progress and source/target gait. Movement multiplier display only describes the retained Walk profile.

Updated pivot tests cover uninterrupted full-clip horizontal pause, exact entry-speed restoration, frozen Run/Sprint buildup, natural duration, Walk profile preservation, no dedicated idle turns even after acceleration, release-to-idle, locked target under changed input, MovingJump cancellation, and 120/170-degree requests. The arc fixture explicitly cancels old turns between cases because released Run turns now intentionally finish instead of cancelling. Main V2 scene, camera-relative input, movement tuning and landing calibration remain unchanged.

### Current: animation-led 180-degree reversal rework (2026-09-05)

This supersedes the timer-driven moving pivots described below. The arbitrary 0.70-second Run timeline, 0.10-second hard velocity pause, motor pivot elapsed/duration flags and smoothstep motor-facing timer have been removed. WalkStart/WalkStop remain absent. No source GLB edits, new clips, root motion, motion warping or IK were introduced.

Explicit WalkPivot / RunPivot states still use `LOC_WALKING_TURN_180` / `LOC_RUNNING_CHANGE_DIRECTION_180`. Both play the full source at fixed **1.0x**: approximately **1.033 s** Walk and **2.200 s** Run. Their AnimationNodeAnimation nodes do not enable custom timelines or stretch playback. No playback-speed control is exposed in this pass. State-entry crossfade has its ordinary reset frame; sustained playback advances at authored seconds per second.

Coordination is centralized in new `player_turn_180_v2.gd`, a Resource under **AnimationController > Grounded > Turn 180**. Movement asks it to evaluate a request before acceleration, then consumes a target velocity using existing acceleration/deceleration limits. Animation alone publishes normalized evaluated source progress in `AnimationTree.mixer_applied`, and applies visual yaw from the source curve. The motor no longer advances any turn clock or owns source duration. Pausing AnimationTree evaluation freezes progress/facing; velocity may still converge to the unchanged target through physics. Animation does not write the CharacterBody transform or velocity.

Defaults: trigger angle **150 degrees**, idle speed threshold **0.30 m/s**, Walk stop/resume **0.30 / 0.55**, Run stop/resume **0.35 / 0.65**. A grounded, valid locomotion request at >=150 degrees from CURRENT visual facing triggers, whether idle or moving. Below 150 the existing steering/arc rules apply (including idle 120-degree arcs). Dedicated turns suppress the generic arc while active. The idle threshold classifies whether entry velocity is zero; it does not exclude moving reversals. Targets are captured once, with source gait, current target gait, turn type, progress and multiplier in the same coordinator.

Movement response is progress-driven: entry smoothly scales captured incoming velocity from 1 to 0 by stop progress; plant holds target velocity zero through resume progress; exit smoothly scales target-direction locomotion speed from 0 to 1 through source end. Each ramp uses smoothstep. Existing acceleration 28 / deceleration 36 m/s² limit actual velocity response, so there is no hard zero snap or full-speed reverse assignment. Walk plant spans about 0.310–0.568 s; Run about 0.770–1.430 s at 1.0x. Idle-origin entry velocity is zero, letting the turn establish itself before exit acceleration. The running source visibly crouches/plants around its middle; the shorter walking source uses a briefer stop. These are initial independently tunable profiles, not precision foot locking.

Facing follows the sampled authored hips-yaw curve rather than a generic elapsed-time ease. Curve angles are unwrapped across +/-180 (important because Run overshoots past 180), then normalized to the captured target angle. Hips yaw is removed only in instance-owned runtime turn copies to avoid applying rotation twice; tilt and body pose remain. Walk reaches about 107 degrees at source 0.50; Run about 112 degrees at 0.50 and 159 degrees at 0.60. Source overshoot is clamped to the destination, which is exact at completion. No additional rotation-window controls were needed. Exact 180-degree ambiguity uses the source-compatible side: Walk left, Run right; other requests use their signed shortest target angle.

Idle→Walk opposite uses WalkPivot; Idle→Shift opposite uses RunPivot, without granting Sprint early. Moving Walk uses WalkPivot, moving Run/Sprint use RunPivot. All physically brake/plant/reaccelerate as the source progresses. Original gait selection and buildup rules remain active: holding Shift/input preserves Sprint and its buildup during the plant, while releasing Shift intentionally selects Walk. The selected clip is stable for the current turn; target gait can change and determines exit speed. Source gait is captured before the request's gait update. An idle Run turn lasts less than the existing 4-second Sprint buildup and exits in Run under default settings.

Input within 60 degrees of the captured destination does not retarget it; release or a clearly incompatible request cancels and blends back to loops. Jump cancels before movement processing, then selects the existing appropriate airborne presentation. Floor loss or the non-locomotion suppression boundary also cancels. There is no forced completion after cancellation; existing acceleration blends velocity toward current intent. Future high-priority actions may use the same suppression/cancel boundary. Completion waits for evaluated source end, sets exact destination facing, and returns to loops on the next motor tick. Held intent cannot repeatedly retrigger a completed turn.

Optional `debug_180` defaults OFF on Turn 180. The F3 overlay can show active/type/progress, captured target angle, movement multiplier and source/target gait. Existing gait, landing and arc debug preferences remain separate.

Verification: rewritten `test_pivots_v2.gd` covers the five idle/moving gait cases, explicit actions, natural source duration and steady 1.0x playback, near-zero plant speed, opposite exit, source-progress-only advancement, locked target under jitter, Jump/release/incompatible-input cancellation, and 120/165-degree selection. Grounded/arc tests were updated to wait for full-source turns rather than expecting old compressed reversals. Baseline motor and landing coverage are retained. A rendered Run plant at source progress 0.455 measured horizontal speed 0.0 m/s and facing about -101 degrees, with the crouched source pose visibly near the floor in the actual lab. This confirms one representative pose, not sustained subjective feel or perfect foot placement on every slope.

Manual starting ranges: Walk stop 0.25–0.35, resume 0.50–0.65; Run stop 0.30–0.40, resume 0.60–0.75. Keep stop <= resume. Earlier stop brakes sooner; later resume holds the plant longer. Restart play after editing source/profile defaults. Test idle S, idle Shift+S, walking reversal, Run reversal, fully built Sprint reversal, 120/165-degree requests, and Jump/input release during the plant. Both clips remain natural 1.0x; tune movement timing first rather than speeding up the source again. V2 lab remains the unchanged active scene; all airborne and landing values, including standing source start 0.40, are untouched.

### Moving 180-degree pivots (2026-09-05)

Requested moving reversals now use `LOC_WALKING_TURN_180` (WalkPivot) and `LOC_RUNNING_CHANGE_DIRECTION_180` (RunPivot for both Run and Sprint). This supersedes the earlier decision to defer running pivots. WalkStart/WalkStop remain removed and all source GLB Actions remain intact.

PlayerV2 / Moving 180 Pivots defaults: threshold 150 degrees, minimum incoming speed 1 m/s, walking duration 1.03 s, running duration 0.70 s, running pause 0.10 s. Trigger requires grounded normal locomotion and an opposite change from the previous nonzero desired direction, not merely velocity still pointing backward. Holding the new direction cannot repeatedly trigger. A short neutral input during W-to-S handover retains the previous direction while still moving. Standard opposing-key cancellation remains: holding W and S together yields zero input; release W to request S.

Walk continues translating through a facing-led turn using the existing acceleration system. Run/Sprint plant horizontal velocity at zero for the requested 0.10 s, then resume toward the new input through normal acceleration, retaining gait, speed targets, and sprint buildup. This preserves the momentum/gait *state*, not uninterrupted physical velocity during the explicit pause. Releasing Shift still selects Walk normally. Gravity, jump impulse, collisions and landing parameters are unchanged. Jump, floor loss, non-locomotion presentation, input release, or input retargeting by more than 45 degrees cancel a pivot.

The physical pivot owns a smooth facing rotation and its duration; the animation layer reads that state and stretches its one-shot timeline to the same duration. Runtime-only hips yaw removal prevents doubling the authored and wrapper rotations, while retaining the source body pose and tilt. Walk source is 1.033 s, Run source 2.20 s; the default 0.70-second Run pivot therefore plays faster than authored. This is an initial responsive timing choice, not a claim of finished visual calibration. Raise running duration toward 0.85–1.0 s if it looks rushed; tune the 0.10-second plant separately. Exactly opposite requests choose the source-compatible deterministic side (Walk left, Run right). No additional turn-side assets were fabricated.

Moving pivots take priority over the prior directional arc; idle large-angle starts still use that arc and stationary camera turns remain separate. RunStop is preserved. New `test_pivots_v2.gd` checks both selected actions, all three gaits, walking without a pause, Run/Sprint planting, buildup preservation, complete opposite travel, no repeated trigger on held input, subsequent pivots and jump cancellation. Earlier reversal tests now account for the newly requested pivot behavior. Manually test W-to-S in Walk, Run and fully built Sprint, adjust the two duration exports, and inspect foot sliding during the accelerated running source before treating these defaults as final animation polish.

### Directional Turn Arc follow-up (2026-09-05)

The motor now separates original camera-relative `move_direction_world` intent from `allowed_move_direction_world`. The latter feeds the same existing parallel/lateral acceleration model; actual velocity still drives `move_local` for animation. No velocity snap, new animation state, root motion, IK, or pivot clip is involved. WalkStart/WalkStop remain removed; Idle/Walk still blend directly. RunStop and stationary turns remain.

PlayerV2 Inspector / Directional Turn Arc defaults: `large_turn_threshold_degrees = 90`, `max_move_angle_from_forward = 60`, `large_turn_rotation_speed = 360` degrees/sec, `turn_arc_release_angle = 35`, `large_turn_activation_speed = 0.3` m/s. No speed multiplier was introduced: existing acceleration already ramps from rest, with all gait speeds and acceleration/deceleration values preserved. `debug_turn_arc` defaults OFF and adds requested/pre-turn angle, arc status/limit, current facing delta, allowed target angle, and turn side to the F3 overlay.

Activation requires physical ground, no accepted jump, ordinary locomotion presentation, a nonzero camera-relative request more than 90 degrees from visual forward (0.001-degree numerical tolerance), and either (a) a fresh input edge at speed <=0.3 m/s, or (b) Sprint gait. The fresh-edge rule deliberately prevents heavy idle commitment from activating halfway through an already-moving Walk/Run reversal as speed crosses zero. Once active, it persists as the player accelerates. Existing moving Walk/Run turning is unchanged; Sprint retains Sprint and buildup but receives the same forward-constrained reversal instead of an instant pivot.

Each active tick clamps the acceleration target to +/-60 degrees around pre-tick facing, while visual facing turns toward ORIGINAL input at at most 360 degrees/sec. Velocity follows through existing acceleration, so direction changes over multiple frames and movement begins immediately. At default 60 Hz, facing changes by at most 6 degrees per active tick. The allowed target already equals desired once the gap is <=60 degrees; arc mode releases at <=35 degrees on a subsequent tick, avoiding a target-direction discontinuity on release. Loss of input, jump, floor loss, or the non-locomotion gate cancels the arc. Air steering still uses original desired input and unchanged airborne equations.

Within one degree of an exactly opposite request, reuse `last_large_turn_sign`; initial fallback is positive yaw (left). Outside that ambiguity band use the signed shortest angle, recording its sign while active. Input/camera changes are recomputed every tick rather than locking a destination. Movement input prevents TurnInPlace from overriding arc rotation. The animation layer only publishes `turn_arc_suppressed` for non-Locomotion states, keeping clip timing out of the motor; Land retains its existing behavior and values, including standing source start 0.40. Future action systems can extend this gate for lock-on/actions without adding such systems now.

`test/test_turn_arc_v2.gd` exercises 45/90/135/180 and negative-angle starts, immediate acceleration, direction constraints/convergence, opposite-side fallback, camera-behind W, input/jump cancellation, presentation suppression, moving Run, and Sprint reversal. Existing grounded, motor, and landing suites are also retained. Automated checks establish changing physical target direction and bounded rotation, not subjective animation feel. Manual review should begin with idle backward diagonals/direct reverse, then Sprint reversal and alternating requests. For a heavier/wider arc lower rotation speed toward 240 degrees/sec; for a tighter/faster response raise toward 480. Keep release below the movement cone (suggested 25–45 vs 60 degrees). Existing open V2 lab and main scene are unchanged.

**Follow-up simplification:** WalkStart and WalkStop have been removed from the active workflow at the user's request. Their mappings, graph nodes, entry/exit logic, and Inspector controls are gone; the original Actions remain in the canonical GLB for reference. Walking now stays in Loops and blends directly between Idle and directional Walk using the existing gait crossfade settings. RunStop and stationary turns remain unchanged. The former shared `walk_start_blend_out` setting is renamed `locomotion_return_blend`, retaining 0.15 s for RunStop/turn returns. Updated grounded tests assert the removed nodes are absent and Walk starts/stops directly through loops. The Phase 2 implementation history below describes the original version; this note supersedes its WalkStart/WalkStop details. No movement or landing tuning changed.

This section supersedes Phase 1's forward-only grounded graph. No motor tuning, collision, camera behavior, jump/fall/contact rules, or landing profiles were changed. In particular, standing Land start remains 0.40, exit 0.80, blend 0.25, sink 0.36, peak 0.13, recovery 0.66, entry 1.0, tail 0.05. Shared moving Land values remain untouched. The main scene remains `res://test/player_v2_lab.tscn`; its existing open floor is sufficient and no scene/terrain changes were needed.

### Ownership and graph

`player_v2.gd` only adds publication after move_and_slide: normalized `move_local` from actual horizontal velocity in VisualRoot space (+X right, +Y forward), and signed `facing_delta` in radians. Desired facing is movement direction with input, camera-forward at rest. The existing moving rotation toward velocity is unchanged, so backward/lateral clips appear during reorientation, not as permanent lock-on strafing. Animation never writes CharacterBody velocity/transform or delays input.

New `player_grounded_animation_v2.gd` is a Resource owned/duplicated by AnimationController. Expand **Grounded** on AnimationController in the Inspector for its settings. It owns clip selection, start/stop/turn timing and the nested graph. Top-level states remain Locomotion / JumpStanding / JumpMoving / Fall / Land. Inside Locomotion, a smaller state machine contains Loops / WalkStart / WalkStop / RunStop / TurnLeft / TurnRight. Loops is the existing 0..3 gait BlendSpace1D, now containing Idle, a four-point Walk BlendSpace2D, a three-point Run BlendSpace2D, and forward-only Sprint. Idle remains the zero point rather than a separate redundant state. All one-shots have direct interrupt edges; loop direction changes do not call play/seek/restart.

### Exact canonical Actions

| Purpose | Imported Action |
| --- | --- |
| Idle | `IDL_IDLE_B` |
| Walk forward/back | `LOC_WALKING` / `LOC_WALKING_BACKWARDS` |
| Walk left/right | `LOC_LEFT_STRAFE_WALKING` / `LOC_RIGHT_STRAFE_WALKING` |
| Run forward | `LOC_RUNNING_FOWARD_A` (actual imported spelling) |
| Run left/right | `LOC_RUNNING_STRAFE_LEFT` / `LOC_RUNNING_STRAFE_RIGHT` |
| Sprint | `LOC_SPRINT_FORWARD` |
| WalkStart | `LOC_IDLE_TO_WALKING` |
| WalkStop | `LOC_STOP_WALKING` |
| RunStop, including Sprint release | `LOC_RUN_TO_STOP` |
| Stationary left/right | `LOC_LEFT_TURN_90` / `LOC_RIGHT_TURN_90` |

Walk points are forward (0,1), back (0,-1), left (-1,0), right (1,0); automatic triangulation interpolates intermediate directions without inventing diagonal sources. Run has forward/left/right only. Its backward half-plane is clamped toward the lateral edge until the unchanged motor turns the visual forward; no backward-run clip is claimed. Sprint has no directional space.

### Audition, synchronization, and source limitations

Standalone canonical poses were rendered at four source phases before selection, and all seven selected directional loops were sampled over 120 intervals independently of the controller. Maximum rotation discontinuity across each loop seam was 0–0.056 degrees; largest within-interval bone rotation was 3.3–7.6 degrees. These checks found no gross rotational seam, but are not proof of perfect foot contact or absence of subtle source jitter. Walk's authored hips vertical endpoint differs by roughly 2.2 cm in world scale; backward Walk by roughly 1.1 cm. This source bob/seam was retained, not hidden with a motor or IK correction. Lateral poses are angled, neutral unarmed movement rather than weapon-held combat strafes.

The Walk/Run BlendSpace2Ds use `SYNC_MODE_CYCLIC_MUTABLE`: different-length cardinal clips share normalized cycle phase while a solo source retains authored speed. Walk forward/laterals are ~1.067 s, backward ~1.533 s; Run forward ~0.733 s and laterals ~0.700 s. The outer gait BlendSpace1D remains `SYNC_MODE_INDEPENDENT` (old sync=true behavior), since it contains nested spaces and Idle's much longer cycle. No time-seeking, speed-based animation scaling, or controller-side phase offsets were introduced. Cyclic phase aligns time, not necessarily each authored foot contact; blended diagonals still require human play review. API behavior was checked against the installed engine and https://docs.godotengine.org/en/4.7/classes/class_animationnodeblendspace2d.html .

Rejected/deferred: `LOC_START_WALKING_FORWARD` is redundant with chosen IdleToWalking (same duration, sampled rotations within 0.36 degrees). `LOC_RUN_TO_WALK` likewise closely matches RunToStop, including braking body language; retain ordinary gait blending on Shift release. `LOC_IDLE_TO_SPRINT` has a pronounced launch/crouch and is deferred as a normal Run entry; Run still enters through its existing gait blend. `LOC_RUNNING_BACKWARDS_RIGHT` is asymmetric and changes hips orientation across its seam, so no backward Run/diagonal Run is added. StandingTurningLeft/Right span about 180 degrees over 1.667 s; the shorter 1.2-second 90-degree sources are a better bounded stationary turn. No running pivots or redundant generic strafe variants were added.

### Transitions and defaults

WalkStart is only for a new Walk input edge from near-idle (<0.8 m/s on that first acceleration frame) and roughly forward facing (<45 degrees). Source start 0.10, exit 0.28, blend-in 0.10 s, blend-out 0.15 s. This gives about 0.53 seconds of the 2.967-second walking source, with immediate physical acceleration. Run/Sprint, releasing input, or a >60-degree reversal cancels it. WalkStop starts on a released-input edge after walking and uses source 0.70 onward to omit the long walking lead-in; exit 0.95, blend-in 0.15 s. RunStop starts on release from Run/Sprint, source start 0, exit 0.90, blend-in 0.15 s. Stop exit uses actual evaluated source progress, and renewed input immediately blends back to Loops. Transition returns to Loops use `walk_start_blend_out` (0.15 s) as the shared grounded return blend.

Turn threshold is 60 degrees, blend 0.15 s. Camera orbit while physically stationary (<0.1 m/s, no movement input) triggers a bounded turn of at most 90 degrees. A 180-degree change can resolve through two stationary turns; 45 degrees does not trigger. The source hips yaw is removed from the instance-owned runtime turn clips while preserving tilt. Its normalized authored yaw curve rotates only VisualRoot, once, toward the captured desired facing. This is presentation rotation, not root motion: body, collider, translation, and the motor's moving facing remain unchanged. Renewed movement cancels before the turn layer can overwrite moving-facing rotation. No turn logic runs during Jump/Fall/Land.

Accepted Jump / airborne has priority over every grounded transition; the existing top-level airborne graph remains authoritative. On return, the grounded machine resets to its loops instead of resuming an old stop/turn. Short passive floor loss cannot run a stationary turn. Future high-priority actions should suppress grounded.update in the same manner, rather than adding action timing to the motor.

Grounded debug defaults OFF (`grounded.debug_grounded`). If enabled, the existing F3 overlay adds local direction, dominant cardinal label, transition, and facing angle. Existing general overlay preference is retained.

### Verification and manual follow-up

`test/test_player_v2.gd`, `test/test_land_visual_compression_v2.gd`, and new `test/test_grounded_animation_v2.gd` cover motor/gait/airborne regressions, unchanged landing profiles, start/stop source exits, actual direction publication, transient backward travel, free-facing recovery, cardinal/diagonal movement, forward-only Sprint, turn threshold/completion, no turn-induced physical displacement, movement cancellation, and Jump cancellation. A rendered stationary-turn sample in the real V2 lab also confirms the runtime pose renders near the floor. No claim is made that automated checks replace a sustained human feel test.

Play-test F6 in the V2 lab: tap/hold/release Walk; reverse and make diagonals; hold Shift through buildup, release Shift while moving, release movement from Run/Sprint; orbit camera at rest through 45/90/180 degrees; resume movement and jump during transitions. Watch foot phase, WalkStart duration, and stop-to-idle pose blending. No root motion, IK, lock-on, combat, traversal, or 180-degree running pivots were introduced. A replacement master GLB at the same path uses the same Action mapping; missing required actions report explicit errors rather than silently substituting unrelated clips.
## Traversal Phase 1B.4 — Edge Landing + Exit Blend

Changed only player_mantle_v2.gd, test_mantle_v2.gd and this document. The detector, its depth checks, collider, frame landmarks, .88 playback, 140-degree cone, minimum height, camera architecture, source action and lock rules are unchanged.

Old detector endpoint: edge + inward * max(mantle_top_setback=.50, radius+.03), independent of obstacle depth. Current capsule radius is .45m, so the old .50m endpoint was already near its full-footprint minimum. New Mantle Exit setting mantle_landing_edge_setback requests .15m, but clamps to radius + existing .03m safety allowance = **.48m effective setback**. This is only **2cm closer**, not a substantial visible reduction. Reaching .15m with full capsule footprint support is impossible under the unchanged .45m radius; no collider shrink or unsupported landing was introduced to force it.

The mantle profile derives the ledge edge from the validated face position and top plane, then computes edge + inward * safe setback, projecting Y onto that plane with the existing .015m standing clearance. It checks nine footprint rays against the same obstacle and retains the existing standing capsule sweep along the trajectory. Original detector top-depth validation remains intact and separate. Validated active_data target/landing fields are updated to the final profile endpoint, so debug/ownership consumers agree. Debug shows requested/effective/minimum setback, previous/new landing and edge; footprint ring and arc remain visible.

The same cubic hoist construction and frame 25–50 window now target the .48m endpoint. Only endpoint-dependent coordinates change; no arc timing/control formula or additional post-arc correction was introduced. Frames 40–50 settle to the new endpoint; frame 50 finishes physical traversal, frame 51 releases normal movement authority. Movement held afterward is ordinary locomotion, not extra mantle travel. No-input tests confirm no horizontal displacement during or after the fade.

Reference inspection: current moving standing/crouch modifier blends are .15s each; successful crouch idle-to-move and move-to-idle blends are .30s. Those state transitions use AnimationTree xfade_time with no custom xfade_curve. Mantle exit now uses **.30s**, Inspector .18–.35, through its existing AnimationTree transition—not a new easing system. Tests confirm Mantle is still the fading-from node after .12s. Normal input-aware Idle/Walk/Run selection is unchanged; there is no idle intermediary for held movement.

Foot/pelvis suppression and existing exponential reacquisition are unchanged, with no IK redesign or added delay. Both settled foot positions retain support over the ledge in the no-input 1.75/2.0/2.2m tests. This confirms support, not subjective absence of every transient visual yank. Camera consumes the revised landing automatically; existing continuity/yaw/return checks remain in the mantle suite.

Automated mantle suite passes: all supported heights, deeper 6m platforms using the same .48m setback, stationary edge stability, supported settled feet, moving exit, longer actual crossfade, camera return, diagonal entries, collision rejection and frame-51 handoff. Recommended settings: requested setback .15m (effective .48m under this collider), exit blend .30s. Manually compare the softened idle/walk pose fade. A substantially closer physical center would require a separate explicit collider/support-policy decision and is not part of this pass.

## Traversal Phase 1B.3 — Mantle Feel Polish (historical defaults)

Mantle-only changes: player_mantle_v2.gd, player_camera_v2.gd, test_mantle_v2.gd and this document. Action remains TRV_SPRINT_TO_WALL_CLIMB_02; source GLB and all unrelated movement settings are untouched.

Default playback is .88 (Inspector .80–1.00). Source frame clock, idle frame 10, moving frame 1 and exit frame 51 are unchanged. At .88 the complete source duration is about 2.083333s; active time to handoff is about 1.553030s from idle frame 10 or 1.893939s from moving frame 1, plus alignment. No separate world-time trajectory timer was added.

Frames 25–50 now use one cubic Bezier evaluated with smoothstep progress, replacing BOTH old trajectory curves in that interval. Arc starts at the pre-hoist frame-25 position. First control is directly above that position at landing Y + .40m; second is .50 of horizontal distance toward landing at the same control height. End is the validated landing position. Inspector exposes start/end frames, height and forward bias. This keeps forward motion conservative near the wall but rising and forward components overlap during the main swing. Controls may be above the final standing point; endpoint does not overshoot. Frames 45–50 ease down/forward into the top, reaching the endpoint at 50.

Before frame 25, prior frame 12/17 behavior is retained. Frame-25 vertical fraction is .50 instead of .40, providing clearance for the standing capsule's rounded lower section as forward transfer begins. Default pre-hoist forward remains zero because alignment leaves only 5cm of wall clearance; the pre-hoist forward curve is still editable, but unsafe edits reject. There is no collision disable, temporary collider shrink or visual-only substitute. Runtime vertical translation compensation uses the SAME arc with a 2.54m reference rise, rather than stacking the old curve on the new arc. Source limb animation remains authored.

Camera: a temporary WORLD-SPACE anchor begins at normal camera anchor on ENTRY. Frame-based smoothstep from 12 to 50 guides its target toward landing plus normal anchor height plus .40m top offset. An exponential filter (follow speed 5) moves the anchor independently of capsule Y. EXIT or abort retargets the ordinary player anchor with return speed 6; it stays active after traversal ends until error is below 2mm. Free yaw/pitch, mouse orbit, distance settings and SpringArm collision remain unchanged. Top offset is additional to the normal standing camera anchor height, not camera distance. This is framing only, not camera rotation or a cinematic mode.

Debug shows playback/frame/HOIST_ARC, arc start/two controls/end, eased progress, height/bias, camera mode/target/error. Existing trajectory lines now show the cubic arc; crosses include both control points and camera target. Enable Mantle Debug on TraversalController/Mantle.

Automated tests pass for 1.75/2.0/2.2m completion, simultaneous upward-forward tangent during frames 33–39, camera continuity and return, preserved camera yaw, frame-51 handoff, idle/moving starts, diagonal entries, input/E spam, corner/thin-top/low-ceiling rejection, and source disappearance cleanup. Actual evaluated source-pose synchronization remains tested at .85 and 1.15 (the latter is a programmatic stress test outside the new recommended Inspector range). Geometry/Phase0, crouch continuity, run-roll handoff and environmental-hand isolation regressions pass. IK eligibility suppression is unchanged.

Recommended initial tuning: speed .88, arc height .40m, forward bias .50, camera follow 5, return 6, top offset .40m. The 2.2m maximum is still provisional. Physical/mathematical checks do not establish subjective animation or camera feel: manually inspect frames 25–40 and 40–50 in the lab before tuning further. Low arc heights or stronger early forward bias can legitimately fail the unchanged capsule preflight; do not bypass collision to force them. No traversal contact IK, root motion, alternate clip or additional traversal type was introduced.

Additional camera verification: test_camera_distance_v2 passes. All camera assertions in test_lock_tuning_v2 pass, but its unrelated "diagonal interpolates speeds without adding" assertion fails. Re-running the current test with the saved pre-polish camera script substituted through ResourceLoader reproduces that identical assertion and camera output. No diagonal-speed tuning was changed in this pass.

## Traversal Phase 1B.2 — Mantle Frame Synchronization (historical defaults)

Supersedes the Phase 1B action/timing defaults below. The user clarified that the Blender landmarks belong to **TRV_SPRINT_TO_WALL_CLIMB_02**, now the active mantle action in both the animation map and physical profile. The source GLB remains untouched.

Verified GLB timestamps: 55 samples at 30 FPS, starting at 1/30 and ending at 55/30 seconds; Godot imported duration 1.833333373s, step 0.033333335s. Godot adds a t=0 initial hold; optimized key count is not frame count. Consequently use source frame / 30, NOT (frame-1)/30. Normalization divides this timestamp by imported duration (approximately frame/55).

| Frame | Source seconds | Normalized |
| --- | --- | --- |
| 1 | 0.033333333 | 0.018181818 |
| 10 | 0.333333333 | 0.181818182 |
| 12 | 0.400000000 | 0.218181818 |
| 17 | 0.566666667 | 0.309090909 |
| 25 | 0.833333333 | 0.454545455 |
| 50 | 1.666666667 | 0.909090909 |
| 51 | 1.700000000 | 0.927272727 |

Stationary entry starts at frame 10; actual pre-traversal horizontal speed >=0.75m/s selects moving frame 1. This intentionally does not treat pushing against a wall at zero speed as momentum. Both are Inspector settings. Playback starts only after .12s collision-safe alignment reaches .05m/5-degree tolerances (duration range now .10–.25s). No free velocity carries into ACTIVE.

Godot custom timeline stretching scales its start offset too. Mantle node timeline length = full clip length / speed; node start offset = chosen source timestamp / speed. Source clock = (evaluated play position + node offset) * speed. Automated tests compare the evaluated hips pose to direct source-track interpolation, not just the body clock, at .85 and 1.15 playback speed.

Editable curves are normalized POSITION, not velocity. Vertical frame/value defaults: 0/0, 11/0, 12/.015, 17/.15, 25/.40, 38/1.04, 45/1.04, 50/1, 55/1. Forward: 0/0, 25/0, 38/0, 45/.8, 50/1, 55/1. APPROACH has no early lift; INITIAL_LIFT begins at 12; WALL_REACH at 17; HOIST at 25; EXIT at 51. The existing standing capsule requires delaying wall crossing until lift clears the ledge at frame 38. This conservative collision constraint takes priority over starting physical forward transfer immediately at 25. The validated endpoint is reached at 50. Runtime horizontal translation is canceled (source _02 hips travel about 3.316m); the existing 254cm reference vertical compensation follows the new curve, retaining authored limb motion. No traversal IK was added.

At 51, floor support is confirmed and EXIT immediately yields to the normal motor with current movement/Shift/crouch request. The .12s animation crossfade continues while movement is already available, with no forced idle or recovery tail. CTRL remains toggle; presses during committed ACTIVE remain ignored, while normal crouch toggle handling is available in EXIT. No special forced crouch destination. Lock clears on entry and is never automatically reacquired. Foot/pelvis eligibility remains suppressed during ENTRY/ACTIVE and recovers during EXIT; environmental hands stay suppressed until traversal releases.

Minimum is now 1.75m. Maximum remains provisional, Inspector-tunable 2.2m. Mantle-only total cone is 140 degrees (±70). Deterministic forward fan probes discover diagonal walls, check face-normal relevance and project the contact to the face normal so alignment does not jump sideways. Existing context priority, distance/facing score and .15 switching hysteresis are preserved; generic interaction cone is unchanged. Back-facing and side-on walls reject. Source existence, standing clearance, trajectory sweeps, actual collision and final floor checks are retained.

Lab rear row now includes 1.50, 1.65, 1.75, 2.00, 2.10, 2.20, 2.25, 2.40 and 2.60m; earlier fixtures and visual-only ground offsets remain. Automated mantle tests pass: 1.50/1.65 reject, 1.75–2.20 complete, 2.25+ reject under current maximum; 0/45/-60/69/-70 degree entries complete, 90/180 reject; idle/moving starts, no approach lift, frame-51 handoff, E-spam rejection, source-loss recovery, crouch/lock release, low ceiling/thin top/corner rejection, and source-pose timing at varied speeds. Regression tests retain their historical geometry ranges explicitly.

Visual contact fit at frames 17 and 25 is still a manual polish criterion, not established by physics tests. Recommended next step: compare wall foot at 17, ledge hands at 25, and top feet at 50/51 in the lab, then tune the exposed curves before considering contact IK or a higher maximum. These are future IK contact landmarks only; no airborne grab/hang or other traversal features were added.

## Traversal Phase 1B — Prompted Mantle (historical defaults)

Uses user-approved `TRV_SPRINT_TO_WALL_CLIMB` (2.266667 seconds), not the `_02` or airborne-hang clips. Full 41-action inventory, durations, loop flags, approximate start/end poses and hips spans: `TRV_ACTION_INVENTORY.md`. Inventory interpretations are skeletal-sample based, not a complete visual review. The chosen action begins in a running stride and ends crouched on top; its source hips rise approximately 2.095m and feet end near 2.63m. Source GLB is untouched. Only the private runtime animation copy has horizontal hips travel canceled and a 254cm vertical reference trajectory subtracted, retaining the authored limb poses and top-out compression.

Production detector range: 2.0–2.2m, conservative pending visual reach/pose tuning. Existing standing capsule is retained throughout. Crouched activation checks standing clearance, yields crouch, and restores standing on completion. Lock-on clears and is not reacquired. Normal gait, jump, roll, crouch mappings and camera values are unchanged.

TraversalController owns ENTRY/ACTIVE/EXIT through its new Mantle child. ENTRY collision-sweeps a short alignment (maximum .35m) over .12s, with .05m/5-degree tolerances. Animation entry crossfade is .15s. ACTIVE reads AnimationTree playback position divided by current length; playback speed .85–1.15 changes the timeline without desynchronizing body progress. No independent movement timer or unrestricted root motion. EXIT blends to input-selected locomotion over .30s, avoiding an idle bridge for held movement.

Inspector-editable normalized positional curves on Mantle: vertical (0,0), (.15,.05), (.30,.28), (.50,.70), (.65,1.04), (.85,1.04), (1,1); forward (0,0), (.65,0), (.85,.8), (1,1). Lift precedes crossing the ledge so the standing capsule clears it. Vertical overshoot allows a short settle. Defaults use Curve interpolation. The runtime reference compensation uses the same vertical curve; height adaptation is limited to the supported range.

Validation sweeps the standing capsule along 80 trajectory segments before taking ownership; actual motion uses move_and_collide, followed by floor snap at top-out. Destination volume is checked each tick. Missing/moved source, blocked movement, blocked destination, absent final floor or stalled animation release ownership safely; collision is never disabled. Static geometry only; moving platforms and deforming ledges are not supported.

ENTRY/ACTIVE fade existing foot and pelvis grounding out, invalidate normal planting eligibility, and suppress environmental hands. EXIT permits the existing foot/pelvis recovery; hands remain suppressed until ownership releases. ENTRY accepts Dodge, Jump and Damage requests through existing hooks; ACTIVE/EXIT are committed and reject these requests. No combat reactions or airborne grab were added.

Lab: retains older fixtures, adds a rear row at 1.50, 1.75, 2.00, 2.10, 2.20, 2.40 and 2.60m. Automated test_mantle_v2 confirms low fixtures reject, 2.00/2.10/2.20 complete on top, 2.40/2.60 reject; corner, thin-top and low-ceiling rejection; ENTRY cancellation; E spam; source loss; crouch-to-standing and lock-to-Free exits; and synchronized trajectory at .85/1.15 speed. Historical geometry tests explicitly retain their older thresholds for detector regression, not production use. Phase0, geometry, crouch continuity/modifier, run-roll handoff and environmental-hand isolation regressions pass. Existing Windows root-certificate warning remains unrelated.

Known limitation: automated physics/animation-state checks do not establish visual quality of palm contact, body-to-wall pose or top-out blending. Please visually play-test this first physical profile before widening height range. Next phase should follow manual acceptance; automatic airborne ledge-grab remains unimplemented.
