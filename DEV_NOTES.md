# Everdeep 0.0.3 — Animation Foundation

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

Select the Player root for movement, jump, and dodge values. Select `CameraRig` for sensitivity, distance, pivot height, and pitch limits. Current tuned values remain `walk_speed = 5.0`, `sprint_speed = 8.0`, `jump_velocity = 7.0`, `air_control = 0.4`, and `gravity_multiplier = 1.5`.

The experimental automatic step solver was removed. The player again uses the stable direct `move_and_slide()` locomotion path and default CharacterBody floor/snap settings. In the test arena, ordinary and shallow-wide stair blocks are visual graybox geometry only; each staircase has one hidden convex ramp collider aligned from the arena floor to its top platform. Discrete ledge blocks remain useful jump/blocking tests and are not automatically climbed.

## Locomotion states

- `GROUNDED` follows `CharacterBody3D.is_on_floor()` and handles walk/sprint acceleration and ground deceleration.
- `AIRBORNE` begins on jump or when floor contact is lost and handles reduced air steering without no-input braking.
- `DODGING` begins only from grounded input. When its timer finishes, the controller resolves to `GROUNDED` or `AIRBORNE` from actual floor contact.

Sprint remains a held movement modifier rather than an exclusive state. Jumping is represented by `AIRBORNE`; there is no duplicate `is_grounded`, `is_jumping`, or `is_dodging` flag. Enable `debug_locomotion_transitions` on the Player to log state changes only when they occur. Future traversal states can extend the enum and state dispatch, but none are implemented yet.

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
