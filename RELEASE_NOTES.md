# OSD Editor v1.0 — by KrisTalksTech

First public release of OSD Editor, created by Kris Gleave (KrisTalksTech).

## Download

- **OSD-Editor-1.0-Mac.zip** — ready-to-run Apple Silicon Mac app.
- **OSD-Editor-1.0-source.zip** — matching source, original icon, build/package scripts, tests and documentation.
- **SHA256SUMS.txt** — SHA-256 checksums for those two ZIPs.

Requires Apple Silicon and macOS 27.0 or later. No Homebrew, FFmpeg or Xcode is required to run the packaged app. It is locally/ad-hoc signed, not Apple Developer ID signed or notarized; see the installation guide.

## Features

- Reconstruct supported recorded OSD, then drag, resize, tint, align or hide groups.
- Written telemetry line with selectable contents and text fonts.
- Optional battery, signal, bitrate/history and distance cards; individual/group selection and movement.
- Custom drone-name text using an imported OSD PNG font.
- Grid snapping, yellow centre guides and supported Undo/Redo.
- Playback, source file information and In/Out trimming.
- 16:9/4:3 framing and Original/2K/4K H.264 or HEVC export, retaining source frame timing.
- Sequential full-clip batch export, progress, cancellation and reports.
- Saved/shareable aspect-specific presets and a managed font library.

## Compatibility and fonts

Tested on an **M4 Pro MacBook Pro** with supplied **BETAFPV P1 / Artlynk** recordings. Other systems and firmware/modes need community testing; opening a video does not imply support for its editable OSD. Intel/Windows/browser builds are not included.

**No OSD font is bundled.** The app recommends the compatible Nexus PNG used with the P1/Betaflight sample and links to Sneaky FPV. Download and import your own font, subject to its creator’s licence.

Personal fonts, presets, recordings and settings are not part of the download. Updating preserves the separate local library; existing P1 OSD Studio libraries can be copied on first launch. Original recordings remain unchanged.

## Licence and credits

GPL-3.0-or-later. Includes OSD parsing adapted from Alexander van Saase’s Walksnail OSD Tool and ksielick’s Artlynk-capable fork. See LICENSE and THIRD_PARTY_NOTICES.md; corresponding source and build scripts accompany this release. Optional fonts have separate licences.

## Support and testing

The best support is [subscribing to KrisTalksTech on YouTube](https://www.youtube.com/@kristalkstech) for FPV content and reviews. [Optional PayPal support](https://www.paypal.me/krisgleave) is welcome too. The app remains free to use.

Bug reports and compatibility tests are welcome through the issue templates. Please describe your setup before posting samples, and keep private footage, location data and restricted font files out of public issues.
