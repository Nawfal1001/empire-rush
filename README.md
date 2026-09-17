# Empire Rush

An offline-first mobile strategy game for Android.

## Current direction
Empire Rush is being developed as a standalone Godot project with original gameplay/UI code and no upstream runtime dependencies. The current build is designed to be playable offline; online connectivity is reserved for optional monetization and service features.

## Development status
Standalone MVP vertical slice is implemented. Android CI is being used to validate the project and produce an installable debug APK.

## Licensing
The current standalone build avoids bundling upstream Civ2025 runtime assets. Any future third-party assets will be audited individually and their licenses retained.

See `GAME_PLAN.md` for the product and monetization direction.

<!-- CI trigger: Android export preset key correction -->
