# Editing DJI camera telemetry

Open OSD Editor and click **Import SRT Files**. A DJI camera sidecar can be opened by itself. To preview against footage, open the video first. A matching SRT in the same folder loads automatically, or use Import SRT Files to pair it manually. The file information shows **DJI camera** when the sidecar contains recognised bracketed camera fields.

Scrub the timeline to see the settings change. Under **Telemetry contents**, choose ISO, Shutter, EV, CT and Colour Profile. Select the telemetry line in the preview to reposition it and use the existing telemetry text, size, colour and alignment controls. Save a preset to reuse the layout.

**Export camera line with alpha…** creates a silent ProRes 4444 MOV containing the visible camera line for the full SRT duration. Position its start at the original clip start in your video editor. With just the SRT loaded, the default canvas is 1920 × 1080. With video loaded, the export uses its configured output dimensions. **Export video…** uses the existing video workflow, including trim and other enabled overlays.


## A Gyroflow video made from multiple DJI chapters

Open the stabilised video, click **Import SRT Files**, then Command-click all the original DJI sidecars in the file picker. The files can live in a different folder from the video. The app orders and combines the chapters automatically, then confirms the generated matching SRT filename and folder.

The editor sorts by the first embedded recording date and time when every chapter has one. Otherwise it uses natural filename order. Each chapter starts at the preceding chapters’ combined SRT duration. Local cue gaps are preserved. The dialog shows the video and telemetry durations to help spot missing chapters or a trim. This assumes Gyroflow kept the full chapters at their original speed in recording order. For a trimmed or retimed output, align or retime the exported transparent overlay to match the edit.

Use **Import SRT Files** after opening the joined Gyroflow video. Selecting one file imports it normally. Selecting several original DJI chapters orders and joins them automatically, then saves one SRT alongside the video with the same base name. That file loads automatically with the video on future edits.

The two-column field picker includes the fields found across all selected chapters. Five camera settings are enabled initially. Other fields, including frame-level details, can be enabled individually and saved in presets. The date and time refer to the original recording, and frame numbers are those written by the camera.

## DJI camera workspace

When a DJI SRT is loaded, P1-only visual controls are hidden. The **Elapsed** item appears in Telemetry contents. It starts at `00:00:00`, advances with the SRT timing and can be enabled or disabled alongside ISO, Shutter, EV, CT and Colour Profile. Recording Time is capped to `HH:MM:SS`; DJI fractional seconds are not displayed.

## Transparent overlay exports

**Export telemetry alpha only…** appears beside Export video and works with DJI and P1 sources. Its dialog lets you select Telemetry, OSD and Visuals. Choose **One combined file** for a single ProRes 4444 overlay, or **Separate files** to create one transparent movie for each selected layer. Separate files make it easy to enable, disable and arrange layers independently in a video editor.
