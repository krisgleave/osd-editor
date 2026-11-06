# OSD Editor v1.0

Created by Kris Gleave — KrisTalksTech.

OSD Editor is a desktop video editor for reconstructing recorded FPV OSD and adding telemetry overlays to exported videos. Development and sample-based testing focus on the BETAFPV P1 / Artlynk system. Release version: 1.0.

It edits recordings already copied to your computer. It does not connect to a receiver or download recordings over USB. P1 Transfer is a separate project.

## Tested compatibility

- BETAFPV P1 MP4 recordings containing the supported embedded Artlynk OSD data, with matching SRT telemetry.
- Tested during development on an Apple Silicon M4 Pro MacBook Pro, using supplied P1 sample recordings. This is not certification of all P1 firmware, recording modes or Mac configurations.
- The current downloadable executable is ARM64 only. Its bundle currently specifies macOS 27.0 or later; older macOS releases have not yet been qualified.
- A compatible sidecar `.osd` reader exists, but real Walksnail recordings have not yet been verified. Do not advertise general Walksnail support yet.
- DJI and HDZero editable OSD extraction are not currently supported. Burned-in analogue or digital OSD cannot be independently moved or removed by this tool.
- A compatible video may open without supported editable OSD. That alone does not establish support for its recording system.

## How it works

1. Copy your recording and any matching sidecar files to the computer.
2. Open the video. A same-name SRT in the same folder loads automatically; Choose SRT allows manual selection. The file area identifies the loaded files and shows video and SRT information.
3. Import a compatible OSD image-font PNG through the Fonts menu if prompted. The app copies imported fonts into its managed library. No third-party OSD font is bundled.
4. Reposition and style OSD, choose the telemetry fields and optional visuals, and set the export range and format.
5. Export a new MP4. Original media remains unchanged.

The app reads recorded character codes and grid positions, rather than recognising text from the video picture. OSD grouping uses recording drawing runs, with proximity grouping as a fallback. It does not semantically identify every item as GPS, battery, altitude, etc. Different layouts and recordings may group differently.

## Editing features

- Directly drag OSD groups; begin a selection rectangle in empty space to select whole intersecting groups.
- Resize, tint, align and hide selected OSD. Hidden items are dimmed and selectable in preview and excluded from export.
- A saved logical size value: 20 represents the original OSD size. Size controls use whole numbers from 4 to 50.
- Selection-relative or frame-relative alignment, including horizontal and vertical alignment.
- Snap grid with 32, 48, 64 and 96 columns.
- Ruler toggle for yellow horizontal and vertical centre guides. Grid and guides are preview-only.
- Undo and Redo for supported layout movements. This is not a full unlimited editing history.
- Native window controls, full-screen mode and light/dark/system appearance.

## Written telemetry

A single movable, resizable and colourable bottom line, with independently selectable fields:

- Flight time
- SBat and GBat
- Video signal
- Channel
- Bitrate
- Distance
- STYMode

The line supports text-font selection and alignment. Text fonts and OSD image fonts are different formats. The font library supports importing, renaming and deleting OSD PNGs and text TTF/OTF files.

## Optional telemetry visuals

Individually enable SBat, GBat, signal bars, a bitrate value with a ten-second history graph, and distance with a map-pin route icon.

Select a card to use the top toolbar for size, alignment and visibility. Draw a box around cards, or use VIS, to select several. Group dragging preserves spacing and supports grid snapping. Individual sizing remains available; cards match dimensions when assigned equal sizes.

Signal colours: 1 red, 2–3 amber, 4 green. Battery and bitrate colour thresholds are editable. Defaults are battery red below 3.50 V and green from 3.75 V, and bitrate red below 4 Mbps and green from 12 Mbps. Values between the boundaries are amber.

Battery thresholds currently apply to the raw displayed voltage, without cell-count conversion. Battery fill is a simple voltage graphic, not a measured state-of-charge percentage. These default voltage bands are not appropriate for every supply, especially multi-cell GBat readings. SBat/GBat cards show the recorded supply readings; regulated power may not track flight-battery discharge. Missing readings appear grey with a dash. No map or GPS route is inferred from the distance value.

## Custom OSD text

Add a custom label, such as a drone name, using the selected OSD PNG font. Enable Custom OSD text, enter the label, and press Return to apply. Input is uppercased and restricted to supported ASCII positions from space through Z, up to 32 characters; other characters are removed. Appearance depends on the imported font’s glyph mapping.

The label supports selection, movement, resizing, tint, hide/show, alignment and grid snapping. Its settings save with presets.

## Playback, framing and export

- Preview playback, timeline scrubbing and space-bar play/pause.
- In/Out range with timeline handles, marking buttons and hh:mm:ss fields. Playback respects the selected range.
- 16:9, 4:3 and source framing. Aspect conversion uses a centred crop. Supported overlay fitting can move/shrink recorded OSD and the written telemetry line to fit, with a warning where needed. Check optional visual cards and custom labels after changing aspect ratio.
- Stable black-padding detection for supported samples when converting aspect ratio.
- Original, 2K and 4K output. Upscaling uses Lanczos resampling, not AI detail reconstruction.
- H.264 and HEVC via Apple’s video engine. High-quality export profiles choose output bitrate; it is not forced to equal source bitrate.
- Source frame timing is retained; no selectable output FPS or frame interpolation. Development checks included exact decoded timestamp comparisons on selected 60 and 29.97 fps fixtures.
- Full 4K 4:3 output offers HEVC where the tested H.264 path would reduce dimensions.
- Sequential batch export using each recording’s own matching SRT and supported OSD, with one common layout. Batch exports use full clips; individual trimming is disabled.
- Progress percentage, cancellation and a batch report. Completed batch files remain if a later job fails or is cancelled.
- Output names include the source name and compact export details. Numeric suffixes prevent overwriting existing exports.

## Presets

Save, Save as, rename, delete, import and export layout presets. Choose a startup default with Make Default. Presets are separated internally by aspect ratio; the picker lists matching presets plus Default. Deleting an active preset restores Default. Unsaved changes prompt for Save, Discard or Cancel when appropriate.

Preset files contain settings, not font files. Recipients must have matching fonts. Recorded OSD adjustments attach to grid positions, not named semantic elements; a preset made for one drone’s OSD layout may not suit another.

## Community testing wanted

We would welcome representative recordings from more P1 users, firmware versions, drone layouts and Mac configurations, and samples from other FPV systems to investigate future support.

Useful submissions include the untouched MP4, same-name SRT and OSD files if present, recording-system and goggles models, firmware version, recording mode, Mac model/macOS version, and a screenshot showing the expected OSD. Share only material you are comfortable distributing; telemetry can contain sensitive location information. Font files should only be shared where their licence permits it.

Additional systems should be listed as experimental until tested with genuine samples. A font styled after DJI or another system does not add support for that system’s recording format.

## Distribution and source

The current app is locally ad-hoc signed, not Developer ID signed or notarized. It uses Apple’s built-in frameworks and does not require Homebrew or FFmpeg. Users supply their own compatible OSD font.

Source is distributed under GPL-3.0-or-later, with OSD format/parser attribution to ksielick/walksnail-osd-tool and its upstream work. Preserve the source licence and notices. Font licences are separate.

## Other platform options

**Intel Macs:** the most direct extension. Build an x86_64 version, audit API availability and lower the current macOS deployment requirement, then test on actual Intel hardware and supported older macOS versions. A universal Mac download can contain both ARM64 and x86_64 versions. Export performance and codec availability need separate checks. No Intel build has yet been produced or tested.

**Windows:** possible, but a substantial port. The current interface, video decoding/encoding, compositing and font handling use Apple frameworks. Reuse the format knowledge, algorithms and preset design while replacing the platform-specific implementation. Swift support on Windows does not supply AppKit, AVFoundation or Core Image.

**Web browser:** also possible as a separate implementation. Local file selection, OSD/SRT parsing, PNG-font rendering, editing and presets could work without uploading recordings. A production export engine needs reliable MP4 parsing/writing, audio handling and per-frame timing, plus codec capability checks. WebCodecs is a promising route to accelerated video processing, but available codecs and limits vary by browser/device. Large files, long batches and 4K need careful memory and performance testing. A browser proof of concept should start with one P1 clip, local processing, H.264 export, preserved source timestamps and audio synchronisation checks.

Platform references:
- Apple universal binaries: https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary
- Swift for Windows: https://www.swift.org/install/windows/
- Chrome WebCodecs guide: https://developer.chrome.com/docs/web-platform/best-practices/webcodecs
- WebCodecs standard: https://www.w3.org/TR/webcodecs/

## Getting an OSD font
The Fonts panel and missing-font prompt include Get OSD fonts…, which opens
https://sites.google.com/view/sneaky-fpv/home in your browser. Nexus is the font
used with the tested P1/Betaflight sample. Choose the Walksnail Betaflight pack,
extract it and import its _36.png for 1080p footage. Font licensing is separate;
no Sneaky FPV font is bundled or automatically downloaded.

## Upgrade from P1 OSD Studio
On first launch, OSD Editor copies the existing settings and Fonts directory from
the previous app into its own Application Support/OSD Editor folder. The previous
library is left unchanged. Existing shared presets can still be imported. New
exports use the OSDEditorPreset identifier. Close the previous version before
upgrading so its latest saved changes are included.

## Build from source
Requires a compatible macOS SDK and Swift compiler. Current distribution is ARM64
with a macOS 27 minimum; Intel and older macOS support are not claimed.

```sh
xcrun swiftc -swift-version 5 -O main.swift OSD.swift Timeline.swift Library.swift Managers.swift CompactUI.swift Batch.swift Aspect.swift PresetIdentity.swift Visuals.swift -o OSDEditor -framework Cocoa -framework AVFoundation -framework CoreImage -framework QuartzCore -framework CoreText
```
