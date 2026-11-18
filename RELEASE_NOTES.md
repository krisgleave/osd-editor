# OSD Editor v1.3.0 — by KrisTalksTech

A major workflow update for editing FPV OSD and multiple telemetry sources on your Mac.

## What's new and how to use it

### Independent telemetry layers

Open a video with a matching SRT (T1), or import the primary SRT manually. Click **Add telemetry** to add separate SRT files as T2, T3 and so on. Even the same SRT can be used twice for different overlay designs. Select a layer in the toolbar or **Sources** menu to set its position, font, size, colour and visible fields. Drag a line to move the entire layer. Use Sources to enable, disable, remove or adjust the time offset of an additional layer; positive seconds delay its telemetry. Source timing must match the video. To concatenate DJI chapters instead of adding independent layers, use Sources → Replace primary / join DJI chapters (or Import SRT Files before a primary source is loaded). Independent sources are intended for single-video editing, not batch jobs.

### Colour individual telemetry fields and OSD groups

Click a telemetry field, or start dragging a rectangle in empty preview space around the fields you want. Ctrl-click or Cmd-click toggles individual fields in the same layer. The selected fields have individual outlines. Use the colour control to tint just those fields; reset tint restores their inherited colour. Drag directly on the line to move it instead. To style the whole line, select its T1/T2/etc. toolbar target. Field selection operates within one layer at a time. OSD groups also support modified-click multi-selection, with individual outlines instead of a single enclosing outline.

### Presets now remember additional telemetry

Arrange and style the primary and additional lines, then save or overwrite a preset. Reapply it to another recording and import additional SRTs in the same layer order to restore the designs. Positions, font, size, alignment, field visibility and individual colours travel with the layout. Presets are not project files: they do not embed recordings, source paths, timing offsets or font files. Source enable/disable state is session-specific. Older presets can be loaded but cannot restore additional styles that were never saved.

### Flexible transparent exports

Choose **Export telemetry alpha only**. The new dialog groups available layers into OSD, TELEMETRY and VISUALS. Tick the layers you want, using category selection or select-all controls as needed. **Export Combined** makes one transparent MOV; **Export Individual Files** makes one MOV per selected layer, including separate T1/T2/etc. files. Visuals remain one grouped export. The silent ProRes 4444 overlays use the full recording timeline (not the video In/Out range); align them with the original footage in your editor. Normal video export bakes overlays into the MP4. Finder reveals successful single-video or alpha outputs automatically, once all selected alpha files have finished.

### Faster editing

Press I or O to mark the current playback position as In or Out when trimming is enabled; Space toggles playback. Shortcuts do not intercept text editing. **New session** (Cmd+N) clears loaded media and sources without quitting the app.

## Fixes

- Improved parsing of SBat/GBat readings, including decimal points and commas, whitespace and voltage units. Low values such as 3.43 V remain numeric; missing or invalid readings are not treated as zero. Empty adjacent fields no longer swallow the next field. Regression cases cover 2.90–4.20 V; this is a parser fix, not a change to battery thresholds or a guarantee against every missing sample.
- Improved handling of zero-duration non-DJI cues and independent SRT imports, source selection and removal.
- Fixed additional telemetry design persistence in presets.

## Downloads and compatibility

- **OSD-Editor-1.3.0-Mac.zip**: Apple Silicon app, macOS 27.0 or later.
- **OSD-Editor-1.3.0-source.zip**: matching GPL-3.0-or-later source, tests and build scripts.
- **SHA256SUMS.txt**: archive checksums.

Quit the previous version, unzip the new app and replace it. Existing fonts and presets live in the separate application support library; back it up before upgrading. The app is ad-hoc signed, not notarized. See [installation](docs/INSTALLATION.md), [user guide](docs/USER_GUIDE.md), [DJI workflows](docs/DJI.md) and [compatibility](docs/COMPATIBILITY.md).

Tested workflows are BETAFPV P1 / Artlynk and DJI written camera SRT. This release does not introduce multiple graphical OSD recordings, DJI graphical OSD extraction, general Walksnail certification, Intel or Windows support. Burned-in OSD cannot be separated from footage. See the compatibility guide for limitations.

Created by Kris Gleave (KrisTalksTech). Free/open source under GPL-3.0-or-later. [YouTube](https://www.youtube.com/@KrisTalksTech) · [Support](SUPPORT.md)
