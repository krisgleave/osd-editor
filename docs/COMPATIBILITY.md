# Compatibility and validation

## v1.0 release

- **Executable:** ARM64 / Apple Silicon only.
- **Minimum macOS:** 27.0. Intel and earlier macOS versions are not qualified.
- **Development hardware:** M4 Pro MacBook Pro.
- **Media used:** supplied BETAFPV P1 / Artlynk MP4 recordings with matching SRT and a compatible Nexus PNG font. This is sample-based testing, not exhaustive hardware/firmware certification.

| Recording source | Status |
|---|---|
| BETAFPV P1 / supported Artlynk H.264 MP4 data | Verified with development samples |
| Compatible `.osd` sidecars | Reader implemented; genuine Walksnail recordings not yet verified |
| Other Walksnail versions/modes | Community samples required |
| DJI / HDZero editable graphical OSD | Not implemented/verified |
| Burned-in analogue or digital OSD | Cannot be separated from the video picture |
| Ordinary decodable video | May open, but opening does not establish editable OSD support |

## Checks performed

- SRT parsing/timestamp lookup; settings and preset round-trips.
- Aspect-specific preset identity, filtering, rename/delete, launch defaults and legacy migration.
- Direct selection, whole-group box selection, movement, group movement and Undo/Redo.
- Visual individual/group sizing and hidden preview/export behaviour; custom-label editing and persistence.
- Font import/registration and fixed status-bar height checks.
- Actual short P1 exports including OSD, telemetry, optional visuals and custom Nexus text.
- Development fixtures comparing decoded frame timestamps at 60 and 30000/1001 fps; selected outputs matched input timestamps without added/dropped display frames.
- 4:3 picture crop, all-recording group/telemetry fitting, 2K geometry and full 4K HEVC geometry on selected samples.
- Batch duplicate names, failure continuation and cancellation checks during development.

These are development checks, not a guarantee for all files. The included automated tests can exercise parts of the editor without private media; media tests require user-supplied fixtures and fonts. Native dialogues and visual layout also require manual checking.

## Known limits

- The supported embedded parser targets the observed Artlynk/H.264 layout. Other codec/metadata layouts can fail.
- Recorded OSD groups are not semantically named elements. Layout presets use original grid cells and may not fit a different drone.
- The grouping heuristic can merge or split items; provide expected screenshots with reports.
- Browser, Intel and Windows ports are possible future work, not part of this release.
- H.264’s tested system export path can reduce large 4:3 dimensions; the app offers HEVC for that case. Actual codec capability varies by device.
- Matching written telemetry depends on the keys present in each SRT. New field formats need parser/UI work.
- Battery raw-voltage defaults are not appropriate to every power system. Graph/card colours are editorial display settings.
- After aspect-ratio changes, inspect optional cards and custom labels; the fit routine primarily handles recorded OSD and the written line.

## Requesting a compatibility test

Open a compatibility report with the system, goggles/VRX, firmware, flight-controller firmware, recording mode, computer/OS, file types and expected display. Describe whether original footage already contains burned-in OSD. Avoid posting GPS coordinates, private footage, serial numbers or restricted font files in public issues. Discuss a suitable sample first.
