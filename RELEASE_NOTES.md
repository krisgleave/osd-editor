# OSD Editor v1.2 — by KrisTalksTech

OSD Editor v1.2 adds DJI camera-telemetry workflows and flexible transparent overlay exports while retaining the established P1 / Artlynk editing workflow.

## Download

- **OSD-Editor-1.2.0-Mac.zip** contains the ready-to-run Apple Silicon Mac app.
- **OSD-Editor-1.2.0-source.zip** contains the matching GPL-3.0-or-later source, build scripts, tests and documentation.
- **SHA256SUMS.txt** contains SHA-256 checksums for both ZIPs.

Requires Apple Silicon and macOS 27.0 or later. The app uses Apple frameworks and needs no Homebrew, FFmpeg or Xcode to run. It is locally/ad-hoc signed and is not Developer ID signed or notarized. See the installation guide if macOS blocks opening it.

## What changed in v1.2

- Imports compatible DJI SRT camera metadata and detects it automatically.
- Displays available DJI camera fields in the written telemetry line, including ISO, Shutter, EV, CT, Colour Profile, Aperture and elapsed recording time.
- Imports a single SRT normally through **Import SRT Files**.
- Combines multiple selected DJI SRT chapters automatically for a joined Gyroflow video, saving one matching SRT beside that video. The original chapter files remain unchanged.
- Adds **Export telemetry alpha only**, producing silent transparent ProRes 4444 MOV overlays.
- Lets you select Telemetry, recorded OSD and Visuals, then export them together as one alpha overlay or individually as separate alpha movies.
- Shows alpha-export progress in the app status bar.

## Using v1.2

### P1 / Artlynk recordings

Open the recording. The app reads supported embedded OSD and automatically loads a same-name SRT sidecar when one is beside the video. Move, resize, colour or hide recorded OSD groups, select telemetry fields and enable any visual cards. Use **Export video** to bake the chosen overlays into a new MP4.

### DJI camera recordings and Gyroflow exports

Open the original or stabilised video. A matching DJI SRT beside it loads automatically. Otherwise select **Import SRT Files**.

- Select one DJI SRT to use it directly.
- Select every original DJI SRT chapter for a video that Gyroflow has joined. The app sorts them by recording time, combines them and saves one SRT beside the opened video using the video filename.

Choose the required fields under Telemetry contents. **Elapsed** starts at `00:00:00`, while Recording Time is the camera’s time of day. Save the layout as a preset when you want to reuse it.

### Transparent alpha overlays

Select **Export telemetry alpha only**. Choose the layers you want and choose one combined file or separate files. Place each exported MOV above the matching footage in your editor. Separate alpha movies make it straightforward to enable, disable, reorder or style OSD, telemetry and visuals independently.

Alpha-only exports process quickly because they create overlays without rendering the source video. Use **Export video** when you want the selected overlays baked into a new MP4 instead.

For a Gyroflow workflow, export the complete joined clip at its original speed before importing its SRT chapters. An SRT starts at the original recording beginning, so it will not align with a Gyroflow file that has been trimmed or retimed. Trim the full video and any alpha overlay together later in the video editor.

## Compatibility

v1.2 has been checked with BETAFPV P1 / Artlynk recordings and a DJI camera-metadata SRT sample. DJI support is for written camera telemetry. It does not extract or edit DJI graphical OSD from video pixels. Existing limits for unverified recording systems, fonts and operating systems continue to apply.

## Licence and credits

GPL-3.0-or-later. Recorded-OSD parsing incorporates adapted work from Alexander van Saase’s Walksnail OSD Tool and ksielick’s Artlynk-capable fork. See LICENSE and THIRD_PARTY_NOTICES.md. Optional OSD fonts are separately licensed and not bundled.
