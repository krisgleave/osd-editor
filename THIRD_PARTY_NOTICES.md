# Third-party notices and provenance

## OSD format and parser

OSD Editor’s OSD format handling and Artlynk unpacking are adapted from:

1. **Walksnail OSD Tool**, Alexander van Saase and contributors — https://github.com/avsaase/walksnail-osd-tool — GNU GPL version 3.
2. **Walksnail OSD Tool, ksielick fork**, ksielick and contributors — https://github.com/ksielick/walksnail-osd-tool — GNU GPL version 3. This fork adds Artlynk MP4 OSD extraction.

Development reference checkout: `ksielick/walksnail-osd-tool` commit [`929ee02c1d5bebc49bcb857fccb06b6c53b2c699`](https://github.com/ksielick/walksnail-osd-tool/tree/929ee02c1d5bebc49bcb857fccb06b6c53b2c699).

Relevant reference areas include `backend/src/osd/artlynk.rs` and `backend/src/osd/osd_file.rs`. The Swift implementation is in `src/OSD.swift`.

**Modification notice, 5–6 November 2026:** OSD parsing was reimplemented/adapted in Swift for this project. MP4 H.264 SEI extraction uses AVFoundation rather than invoking FFmpeg. The application adds its own AppKit interface, layout editing, grouping/selection, telemetry visuals, custom labels, presets, framing and export workflows. It is not an official release of either upstream project.

Original upstream copyright/licensing interests remain with their respective authors. New original implementation and modifications: copyright © 2026 Kris Gleave (KrisTalksTech). Distribution of this combined project is under GPL-3.0-or-later, with GPLv3 text in LICENSE. Upstream code is not claimed as solely authored by this project’s maintainer.

## Optional fonts — not distributed

SNEAKY_FPV font packs, including Nexus, are created by Shannon M Baker and have their own licence. They are not covered by this project’s GPL licence. The app, repository and release assets do not include those PNG font files.

The inspected Nexus pack’s `LICENSE.txt` (copyright 2026 Shannon M Baker) permits personal non-commercial FPV use and sharing its original package with hobbyists, but prohibits bundling with FPV software releases without prior written permission. Obtain fonts from https://sites.google.com/view/sneaky-fpv/home and read the licence supplied with the selected pack. Its public site also distinguishes personal from other uses. This project’s link and import feature do not grant additional rights to use or redistribute fonts. Direct any permission requests to the font author through the official site.

## Apple frameworks

The app uses macOS system frameworks including AppKit/Cocoa, AVFoundation, Core Image, Core Text and QuartzCore. These are supplied by macOS and are not redistributed as project source. The packaged app does not bundle FFmpeg, libmtp, libusb or another third-party executable runtime.

## Project icon and assistance

Original OSD Editor icon concept: generated using an AI image-generation tool, selected and refined under the maintainer’s direction. Development assistance: OpenAI Codex. Project source and original icon assets are offered under the project GPL licence, subject to any rights that exist in those assets. No manufacturer logo or third-party OSD font is incorporated in the app icon.

## No warranty

This software is provided without warranty, including implied warranties of merchantability or fitness for a particular purpose, to the extent permitted by law. See LICENSE. It is a post-processing editor, not a flight-safety instrument.
