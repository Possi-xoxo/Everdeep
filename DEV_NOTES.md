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
