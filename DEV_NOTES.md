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
