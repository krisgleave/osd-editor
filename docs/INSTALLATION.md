# Install, update and back up

## Install

Download **OSD-Editor-1.0-Mac.zip** from [Releases](https://github.com/krisgleave/osd-editor/releases). Unzip and open OSD Editor.app; Applications is an optional convenient destination.

Requirements: Apple Silicon Mac and macOS 27.0 or later. The app needs no Homebrew, FFmpeg, Xcode or terminal commands to run. OSD rendering needs a separately imported compatible PNG font.

The current download is locally/ad-hoc signed, not Developer ID signed or notarized. If macOS blocks it, confirm it came from this repository’s release and follow Apple’s system-provided **Privacy & Security → Open Anyway** process where available. Do not disable Gatekeeper globally. If macOS reports damage, re-download and verify the release checksum; report persistent failures. [Apple’s guidance](https://support.apple.com/en-gb/102445).

## Update

Quit the previous app, replace it with the new app, then reopen. Fonts and presets live separately, not inside the app bundle.

On the first OSD Editor launch, existing saved settings and Fonts from **P1 OSD Studio** are copied to the new app’s library if no current OSD Editor settings exist. The old library is left unchanged. Subsequent changes in the old app do not synchronise to the new one. Older shared preset files can still be imported.

## Personal library

Stored on each user’s computer at:

`~/Library/Application Support/OSD Editor/`

This contains the settings file and Fonts subfolder. It is **not included in the public download**. Back up that folder while the app is closed if you want to preserve your setup. Replacing the app does not require deleting it.

A fresh user starts with built-in Default and no imported OSD fonts or personal presets.

## Common issues

| Problem | Check |
|---|---|
| Video opens, no OSD | Confirm a valid OSD PNG is loaded; check recording compatibility. SRT alone does not reproduce graphical OSD. |
| Font name says file missing | Reimport the compatible PNG through Fonts. |
| SRT not found | Use the same basename in the same folder, or Choose SRT manually. |
| Unexpected grouping | Grouping depends on recorded drawing runs/positions; report a sample layout. |
| Preset absent | Presets filter by output aspect ratio; select the matching frame ratio. |
| Unexpected colours | Battery bands use raw voltage. Configure thresholds for the actual supply; they are not universal flight limits. |
| No save prompt after only font setup | Expected: preset close prompts require a loaded video and layout changes. Font library operations save automatically. |

See [compatibility](COMPATIBILITY.md) before reporting another recording system as supported.
