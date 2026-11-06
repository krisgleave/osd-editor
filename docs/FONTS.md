# OSD and telemetry fonts

## Recommended starting point for P1 / Betaflight

The tested P1 sample used **SNEAKY_FPV Nexus for Walksnail / Betaflight**, `WS_BTFL_Nexus_36.png`.

1. In the app, click **Get OSD fonts…**, or visit [Sneaky FPV’s official site](https://sites.google.com/view/sneaky-fpv/home).
2. Find the Walksnail font collection and select the correct flight-controller mapping, such as Betaflight. Nexus is a tested starting point; other compatible styles may work but are not all verified.
3. Download and extract the ZIP. Read its included `LICENSE.txt`.
4. For the tested 1080p recording, import the `_36.png`. `_24.png` uses a smaller source glyph resolution intended for 720p. Do not select `font_update.ini`.
5. Return to the still-open prompt and click **Import font…**. Later imports are available through the **…** menu beside OSD in Fonts.

The app copies the PNG into its own font library, so deleting the original download does not remove the imported copy. Rename and Delete affect the local library; deleting a font can leave presets requiring another font choice. A missing file is labelled as such in the menu.

OSD PNGs contain indexed character images, not a normal system typeface. The renderer expects compatible glyph dimensions/mapping; a file being PNG is not sufficient. Single-/multi-page fonts may carry different warning glyphs; only pages present in the recording can be reproduced.

## Text fonts

Written SRT telemetry uses a separate ordinary text font, with built-in choices and TTF/OTF import. Importing an OSD PNG does not install it as a system text font. Imported text-font files are also copied into the local library and retain their own licences.

Custom OSD text uses the selected OSD PNG. It is uppercased, limited to 32 characters and ASCII positions from space through Z. Unsupported input is removed; appearance depends on that font’s mapping.

## Licensing

No Sneaky FPV font is included in this repository or the app release. The inspected Nexus licence forbids software-release bundling without written permission. Downloading/importing a font does not remove its personal/commercial-use restrictions. Use the licence included with the pack for your intended use; ask the author when needed.

Preset export contains settings, not font files. A recipient needs their own matching fonts. See [third-party notices](../THIRD_PARTY_NOTICES.md).
