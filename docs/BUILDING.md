# Build and package

The distributed build targets **arm64-apple-macos27.0**. Use a compatible macOS SDK/Swift compiler through Apple’s command-line tools or Xcode, and Python 3 for the build/package helpers. These developer tools are not required to run the packaged app.

From the repository root:

```sh
python3 scripts/build.py
python3 scripts/package.py
```

The executable is written to `build/OSDEditor`. Packaging creates an icon set, app bundle with GPL/credit resources, ad-hoc signature, binary ZIP, corresponding-source ZIP and SHA-256 checksums under `dist/`. It does not create a Developer ID signature, notarize, upload or publish anything. Build output and personal media/settings are excluded from the source archive.

The app entry point is `src/main.swift`; the interface and application logic are in `src/App.swift`. Video/OSD/font work uses macOS system frameworks. No Homebrew package or external FFmpeg is needed.

## Checks

```sh
python3 scripts/build.py --tests
build/OSDEditorTests --self-test
build/OSDEditorTests --interaction-test
build/OSDEditorTests --preset-identity-test
build/OSDEditorTests --visuals-test
build/OSDEditorTests --naming-test
```

Native graphics/editor checks need a logged-in macOS GUI session. They use temporary settings directories, not the live user library. A check failing to launch in a non-GUI runner is not a media-compatibility result.

Media-dependent examples require your own recording and compatible font; none is distributed:

```sh
build/OSDEditorTests --aspect-test /path/to/recording.mp4
build/OSDEditorTests --render-test /path/to/recording.mp4 /path/to/new-output.mp4 /path/to/font.png --visuals
```

Use a new output filename and a matching SRT beside the recording. The render check exports a short clip, not the complete recording. Check preview, selection, playback, dialogue behaviour, audio sync and output timing manually before a release.

## Other targets

Intel support needs more than changing the archive name: compile for x86_64 with an appropriate older deployment target, audit API availability and verify on actual hardware. Windows/browser ports need replacements for Apple-specific interface and media code. Neither is supported by these scripts.
