# Cline Continuation Pack (Simple-Model Friendly)

## Goal
Continue this repo from the current state without re-discovery work.

## Current Verified Status
- App rename to GardenerGrid is partially complete.
- Almanac feature is implemented and routed.
- Plant ID feature is implemented (camera/gallery + descriptor scoring).
- Encyclopedia is implemented with offline cache/search and detail pages.
- AI assistant is implemented with manual online/offline toggle.
- Offline mode exists for knowledge and AI, but automatic connectivity failover is not implemented.

## Most Important Open Work
1. Complete rename consistency from SoilSmart to GardenerGrid across docs and platform metadata.
2. Add automatic connectivity-based fallback for AI mode.
3. Decide whether Plant ID must use true image ML inference (currently heuristic descriptor matching).
4. Keep docs aligned with actual implemented features.

## Work Order For A Simple Model
1. Do rename consistency pass first.
2. Run analyzer and fix only rename-related breakages.
3. Add connectivity-aware AI fallback with minimal code changes.
4. Update docs last.

## File Targets
- Rename consistency targets:
  - README.md
  - SETUP.md
  - DEPLOYMENT.md
  - PROJECT_COMPLETE.md
  - QUICK_REFERENCE.txt
  - docs/API.md
  - package.json
  - package-lock.json
  - windows/CMakeLists.txt
  - windows/runner/main.cpp
  - windows/runner/Runner.rc
  - linux/CMakeLists.txt
  - linux/runner/my_application.cc
  - ios/Runner.xcodeproj/project.pbxproj
  - macos/Runner.xcodeproj/project.pbxproj
  - android/app/src/main/kotlin/com/soilsmart/soilsmart/MainActivity.kt

- AI offline/online fallback targets:
  - lib/providers/ai_assistant_provider.dart
  - lib/screens/ai/ai_assistant_screen.dart
  - lib/services/online_ai_service.dart

## Guardrails
- Preserve behavior unless changing one of the explicit open items.
- Keep edits surgical; avoid broad refactors.
- Keep ASCII in new content.
- Prefer updating docs after code changes are stable.

## Suggested Continuation Prompt For Cline
Use this prompt as-is:

Continue implementation from CLINE_CONTINUATION.md.

Required outcomes:
1) Finish rename consistency to GardenerGrid across docs and platform metadata.
2) Add automatic connectivity-based AI fallback (online when reachable, offline when not), while keeping manual override option.
3) Update docs to match actual feature state.
4) Run analyzer and report remaining issues.

Constraints:
- Minimal, targeted diffs.
- Do not refactor unrelated areas.
- Preserve existing routes and provider wiring.

## Verification Commands
- flutter pub get
- flutter analyze
- flutter test

## Notes
- cline_mcp_settings.json has been reset to valid JSON so Cline can load settings cleanly.
- Existing workspace path/folder name can stay SoilSmart; app name is GardenerGrid.
