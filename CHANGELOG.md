## v1.4

- Added macOS PKG installer and automatic installer packaging.
- Updated application version and installation documentation.
- Retained portable ZIP distribution and existing editing features.

# Changelog

## 1.3.0

- Independent additional SRT sources, source management, offsets and per-layer styling.
- Individual telemetry field colours, marquee and modified-click selection; independent OSD selection outlines.
- Preset persistence for primary and additional telemetry designs.
- Three-column alpha export picker; combined or individual layer MOVs; Finder reveal after success.
- New session and I/O trim shortcuts.
- Voltage parsing fixes (decimal comma/point, low readings, whitespace, units and adjacent empty fields); improved zero-duration non-DJI cue handling.
- Updated documentation and release packaging.

## 1.2 — 2026-11-16

- Added DJI camera-metadata SRT import, with ISO, shutter, EV, CT, colour profile, aperture and further recorded camera fields available in the telemetry line.
- Added elapsed recording time as a DJI telemetry field.
- Added automatic multi-file DJI SRT combining through Import SRT Files. The combined SRT is saved beside the opened video with its matching filename.
- Added transparent ProRes 4444 alpha exports with selectable Telemetry, recorded OSD and Visuals layers, available as one combined movie or separate movies.
- Added alpha-export progress in the main status bar.
- Updated the DJI import workspace and documentation.

## 1.1 — 2026-11-06

- Made the blue icon background opaque and full-bleed to avoid a second pale tile in the Dock.
- Retained the approved OSD Editor artwork. Editing and export behaviour are unchanged.

## 1.0 — 2026-11-06

First public OSD Editor release, by Kris Gleave (KrisTalksTech).

- Native Apple Silicon macOS application for supported P1/Artlynk OSD and SRT editing.
- Movable/resizable OSD groups, telemetry line, optional visual cards and custom OSD-font text.
- Selection toolbar, alignment, grid snapping, centre guides and supported Undo/Redo.
- Presets, font library, video/SRT information, playback and In/Out trim.
- Aspect conversion, Original/2K/4K H.264/HEVC export and sequential batch workflow.
- New OSD Editor name/icon, legacy P1 OSD Studio library migration and old preset import support.
- Official font-site link with an import dialogue that remains open when opening the website.
- Preset save-on-close prompt only when a video is loaded and its layout has changes.

Tested on M4 Pro MacBook Pro with supplied BETAFPV P1 / Artlynk recordings. Other systems need validation. Source, build scripts, notices and licences accompany the release; no third-party OSD fonts or personal presets are bundled.
