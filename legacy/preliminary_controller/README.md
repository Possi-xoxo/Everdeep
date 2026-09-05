# Preliminary controller reference

This folder contains preliminary controller/animation experiments retained for reference. V2 is the active controller architecture for new development.

The `player/`, `combat/`, `test/`, and `DEV_NOTES.md` snapshot is preserved verbatim from the prototype. `.gdignore` excludes the archive from Godot scanning so its global script classes and UIDs cannot conflict with the original files. Restore files to their original paths in an isolated project if you want to run this snapshot.

The original prototype paths remain available for the existing production main scene, which Phase 1 intentionally does not replace. The archive is never instanced by V2. Open `res://test/player_v2_lab.tscn` and press F6 to test the new architecture.
