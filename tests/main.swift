// SPDX-License-Identifier: GPL-3.0-or-later
import Cocoa
import AVFoundation
import CoreImage
if CommandLine.arguments.contains("--visuals-test") {
 let _=NSApplication.shared
 var l=Layout();precondition(l.visuals == nil);var visuals=defaultVisuals();for i in visuals.indices{visuals[i].enabled=true};l.visuals=visuals
 for size in [CGSize(width:1920,height:1080),CGSize(width:1440,height:1080)]{let canvas=CGRect(origin:.zero,size:size);let sizes=visuals.prefix(5).map{visualRect($0,canvas).size};precondition(sizes.allSatisfy{$0==sizes[0]});precondition(abs(sizes[0].width-308.88)<0.1)}
 let restored=try JSONDecoder().decode(Layout.self,from:JSONEncoder().encode(l));precondition(restored.visuals!.count==6 && restored.visuals!.allSatisfy{$0.enabled})
 precondition(reading("16Mbps")==16 && reading(nil)==nil);precondition(bandColour(3.49,3.5,3.75)==NSColor.systemRed);precondition(bandColour(3.5,3.5,3.75)==NSColor.systemOrange);precondition(bandColour(3.75,3.5,3.75)==NSColor.systemGreen)
 var cues=[Cue]();for i in 0..<100{let values=["SBat":"3.65","Signal":"3","Bitrate":String(5+i%15)];cues.append(Cue(start:Double(i)/10,end:Double(i+1)/10,values:values))}
 let layer=visualsLayer(l,["SBat":"3.65","Signal":"3","Bitrate":"11Mbps"],cues,9.9,CGSize(width:1920,height:1080))!;let cg=CIContext().createCGImage(layer,from:layer.extent)!;let rep=NSBitmapImageRep(cgImage:cg);try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"/private/tmp/p1-visuals-test.png"))
 precondition(visualsLayer(Layout(),[:],[],0,CGSize(width:1920,height:1080)) == nil)
 print("PASS: defaults off, preset roundtrip, unit parsing, colour boundaries, missing readings and shared renderer")
} else if CommandLine.arguments.contains("--preset-identity-test") {
 let a=NSApplication.shared;let app=App();a.delegate=app;app.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification));var wide=app.defaultLayout();wide.referenceAspect="16:9";wide.line.size=31;var narrow=wide;narrow.aspectRatio="4:3";narrow.referenceAspect="4:3";narrow.line.size=24
 let wideKey=try app.storePreset(named:"Example Coloured",layout:wide);let narrowKey=try app.storePreset(named:"Example Coloured",layout:narrow);precondition(wideKey=="Example Coloured (16:9)" && narrowKey=="Example Coloured (4:3)" && app.settings.presets.count==2)
 app.settings.layout=narrow;app.syncPreview();app.settings.startup=wideKey;app.refreshPresets();precondition(app.settings.startup=="Default" && app.startup.titleOfSelectedItem=="Default");for popup in [app.preset,app.startup]{precondition(popup.itemTitles==["Default","Example Coloured"] && popup.item(at:1)?.representedObject as? String==narrowKey)}
 precondition(app.existingPreset(named:"example coloured",aspect:"4:3")==narrowKey);do{try app.storePreset(named:"Example Coloured",layout:narrow);preconditionFailure("Same-ratio collision was accepted")}catch{}
 narrow.line.size=22;try app.storePreset(named:"Example Coloured",layout:narrow,replace:true);precondition(app.settings.presets[wideKey]!.line.size==31 && app.settings.presets[narrowKey]!.line.size==22)
 app.settings.startup=narrowKey;let reopened=try JSONDecoder().decode(Settings.self,from:JSONEncoder().encode(app.settings));precondition(reopened.presets.count==2 && reopened.startup==narrowKey && reopened.presets[wideKey]!.line.size==31)
 app.activePresetName=narrowKey;let renamed=try app.renamePresetValue(narrowKey,"Other");precondition(app.settings.startup==renamed && app.settings.presets[wideKey] != nil);app.removePresetValue(renamed);precondition(app.settings.presets.count==1 && app.settings.presets[wideKey]!.line.size==31)
 wide.presetTitle=nil;narrow.presetTitle=nil;app.settings.presets=["Example Coloured":wide,"Example Coloured (4:3)":narrow];app.settings.startup="Example Coloured";try JSONEncoder().encode(app.settings).write(to:app.settingsURL);app.migratePresetIdentities();precondition(app.settings.presets[wideKey]!.line.size==31 && app.settings.presets[narrowKey]!.line.size==22 && app.settings.startup==wideKey);precondition(FileManager.default.fileExists(atPath:app.settingsURL.deletingLastPathComponent().appendingPathComponent("settings-before-ratio-identities.json").path))
 print("PASS: same-name presets in both ratios coexist, case-insensitive same-ratio collision checks, independent replacement/rename/delete, filtered launch defaults, persistence and legacy migration backup")
} else if CommandLine.arguments.contains("--aspect-test") {
 let a=NSApplication.shared;let app=App();a.delegate=app;app.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification));let source=URL(fileURLWithPath:CommandLine.arguments[2]);app.loadVideo(source);app.loadToken+=1;app.loadingOSD=false;app.osdFrames=try extractOSD(source);let before=app.layoutData(app.settings.layout)
 let picture=detectedPictureRect(app.asset!);let result=aspectAdjustment(app.settings.layout,"4:3",app.preview.sourceSize,app.osdFrames,app.cues,picture:picture);precondition(result.movedGroups>0 && result.telemetryAdjusted);precondition(app.layoutData(app.settings.layout)==before)
 let canvas=centreCrop(app.preview.sourceSize,"4:3",picture:picture).size;let safe=CGRect(x:0.019999,y:0.019999,width:0.960002,height:0.960002)
 for group in recordingElements(app.osdFrames){precondition(safe.contains(cellBounds(group,result.layout.cells ?? [:])))}
 let textSizes=app.cues.map{(telemetryLine($0.values,result.layout.widgets) as NSString).size(withAttributes:textAttributes(result.layout.line,canvas.height))};let maxWidth=textSizes.map{$0.width}.max()!;let maxHeight=textSizes.map{$0.height}.max()!;precondition(maxWidth<=canvas.width*0.96+0.1 && result.layout.line.y*canvas.height+maxHeight<=canvas.height*0.98001)
 fputs("Picture: \(picture) dimensions: \(exportDimensions(app.asset!,"Original",aspect:"4:3"))\n",stderr);precondition(exportDimensions(app.asset!,"Original",aspect:"4:3")==CGSize(width:1408,height:1056));precondition(exportDimensions(app.asset!,"2K · 1440p",aspect:"4:3")==CGSize(width:2560,height:1920));precondition(exportDimensions(app.asset!,"4K · 2160p",aspect:"4:3")==CGSize(width:3840,height:2880))
 let sample=app.osdFrames.flatMap{$0.glyphs}.first!;let id=sample.y*53+sample.x;let old=cellRect(id,app.settings.layout.cells ?? [:]);let new=cellRect(id,result.layout.cells ?? [:]);precondition(abs(old.width*app.preview.sourceSize.width/(old.height*app.preview.sourceSize.height)-new.width*canvas.width/(new.height*canvas.height))<0.001)
 var wide=app.settings.layout;wide.referenceAspect="16:9";var narrow=result.layout;narrow.referenceAspect="4:3";app.settings.presets=["Wide":wide,"Narrow":narrow];app.settings.layout=narrow;app.syncPreview();app.refreshPresets();precondition(app.preset.itemTitles==["Default","Narrow"]);precondition(app.preset.itemArray.allSatisfy{!$0.title.contains("4:3") && !$0.title.contains("16:9")});app.settings.layout=wide;app.syncPreview();app.refreshPresets();precondition(app.preset.itemTitles==["Default","Wide"])
 precondition(presetIsValid(result.layout));let restored=try JSONDecoder().decode(Layout.self,from:JSONEncoder().encode(result.layout));precondition(restored.aspectRatio=="4:3")
 app.rememberMove();app.settings.layout=result.layout;app.undoMove();precondition(app.layoutData(app.settings.layout)==before)
 let reverse=aspectAdjustment(result.layout,"16:9",CGSize(width:1440,height:1080),app.osdFrames,app.cues);for group in recordingElements(app.osdFrames){precondition(safe.contains(cellBounds(group,reverse.layout.cells ?? [:])))}
 print("PASS: centred crop, all-recording OSD fit, longest telemetry line, glyph shape, 4:3 output dimensions, preset round-trip, Undo and unchanged cancelled proposal. Moved groups:",result.movedGroups,"telemetry size:",result.layout.line.size)
} else if CommandLine.arguments.contains("--naming-test") {
 let source=URL(fileURLWithPath:"/tmp/Video006.mp4");precondition(exportFileName(source,"Racing","4K · 2160p",CGSize(width:3840,height:2160))=="Video006-TELEM-Racing-4K.mp4");precondition(exportFileName(source,"Default","Original",CGSize(width:1920,height:1080))=="Video006-TELEM-1080p.mp4");precondition(compactPresetName("Kris / Racing: Blue")=="Kris-Racing-Blue")
 let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)};let first=folder.appendingPathComponent("Video006-TELEM-1080p.mp4");try Data("original".utf8).write(to:first);let second=uniqueExportURL(first);precondition(second.lastPathComponent=="Video006-TELEM-1080p-2.mp4");try Data().write(to:second);precondition(uniqueExportURL(first).lastPathComponent=="Video006-TELEM-1080p-3.mp4");let original=try String(contentsOf:first);precondition(original=="original");print("PASS: compact preset names, resolution labels, collision numbering and preservation of existing exports")
} else if CommandLine.arguments.contains("--make-fixture") {
 let a=AVURLAsset(url:URL(fileURLWithPath:CommandLine.arguments[2]));let export=AVAssetExportSession(asset:a,presetName:AVAssetExportPresetPassthrough)!;export.outputURL=URL(fileURLWithPath:CommandLine.arguments[3]);export.outputFileType = .mp4;export.timeRange=CMTimeRange(start:.zero,duration:CMTime(seconds:1,preferredTimescale:600));export.exportAsynchronously{print("Fixture:",export.status.rawValue);exit(export.status == .completed ? 0:1)};RunLoop.main.run()
} else if CommandLine.arguments.contains("--inspect-video") {
 let a=AVURLAsset(url:URL(fileURLWithPath:CommandLine.arguments[2]));let t=a.tracks(withMediaType:.video).first!;print(t.naturalSize,t.nominalFrameRate,CMTimeGetSeconds(a.duration))
} else if CommandLine.arguments.contains("--batch-test") || CommandLine.arguments.contains("--batch-cancel-test") {
 let a=NSApplication.shared;let app=App();a.delegate=app;app.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification));app.osdRenderer=try OSDRenderer(URL(fileURLWithPath:CommandLine.arguments[5]));app.batchSources=[URL(fileURLWithPath:CommandLine.arguments[2]),URL(fileURLWithPath:CommandLine.arguments[3])];app.startBatch(to:URL(fileURLWithPath:CommandLine.arguments[4]));if CommandLine.arguments.contains("--batch-cancel-test"){Timer.scheduledTimer(withTimeInterval:0.02,repeats:false){_ in app.cancelExport()}};a.run()
} else if CommandLine.arguments.contains("--self-test") {
 let text="0\n00:00:00,000 --> 00:00:00,500\nSignal:4 CH: 1 SBat: 4.13 Bitrate:21Mbps\n\n1\n00:00:00,500 --> 00:00:01,000\nSignal:3 CH: 2 SBat: 4.01 Bitrate:18Mbps\n"
 let cues=parseSRT(text);precondition(cues.count==2);precondition(valuesAt(0.25,cues)["CH"]=="1");precondition(valuesAt(0.75,cues)["SBat"]=="4.01");precondition(valuesAt(2,cues).isEmpty)
 let settings=Settings();let restored=try JSONDecoder().decode(Settings.self,from:JSONEncoder().encode(settings));precondition(restored.layout.widgets.count==8);print("PASS: SRT parsing, timestamp selection, settings round-trip")
} else if CommandLine.arguments.contains("--interaction-test") {
 let a=NSApplication.shared;let app=App();a.delegate=app;app.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
 let launchLayout=app.settings.layout;app.settings.layout.line.x=0.333;precondition(app.presetDirty());precondition(app.asset==nil && !app.shouldPromptToSaveLayout && app.confirmCloseChanges());app.asset=AVURLAsset(url:URL(fileURLWithPath:"/tmp/save-prompt-test.mp4"));precondition(app.shouldPromptToSaveLayout);app.asset=nil;app.settings.layout=launchLayout
 print("PASS: no preset save prompt without loaded video; changed layout with video still requires prompting")
 app.window.contentView!.layoutSubtreeIfNeeded();let v=app.preview
 app.settings.layout.cells=[:];app.settings.layout.outlines=true;app.syncPreview()
 let first:Set<Int>=[5,6],second:Set<Int>=[20,21];v.availableCells=first.union(second);v.visibleCells=v.availableCells
 func event(_ type:NSEvent.EventType,_ point:NSPoint)->NSEvent{NSEvent.mouseEvent(with:type,location:v.convert(point,to:nil),modifierFlags:[],timestamp:0,windowNumber:app.window.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!}
 func drag(_ ids:Set<Int>,_ dx:Double,_ dy:Double){
  let b=v.displayBox(ids);let a=NSPoint(x:b.midX,y:b.midY);let p=NSPoint(x:a.x+dx*v.videoRect.width,y:a.y+dy*v.videoRect.height)
  v.mouseDown(with:event(.leftMouseDown,a));precondition(v.selectionStart==nil && v.dragging)
  v.mouseDragged(with:event(.leftMouseDragged,p));v.mouseUp(with:event(.leftMouseUp,p))
 }
 func draw(_ box:CGRect){
  let r=v.videoRect;let a=NSPoint(x:r.minX+box.minX*r.width,y:r.minY+box.minY*r.height);let b=NSPoint(x:r.minX+box.maxX*r.width,y:r.minY+box.maxY*r.height)
  v.mouseDown(with:event(.leftMouseDown,a));precondition(v.selectionStart != nil)
  v.mouseDragged(with:event(.leftMouseDragged,b));v.mouseUp(with:event(.leftMouseUp,b))
 }
 // A rectangle beginning outside an item and touching only its edge selects it all.
 draw(CGRect(x:0.08,y:0,width:0.02,height:0.02));precondition(v.selectedCells==first)
 v.selectedCells=[];app.selectionChanged()
 // One drag, no prior selection or modifier keys.
 drag(first,0.2,0.2);precondition(v.selectedCells==first && app.settings.layout.cells!["5"]!.dx>0.19)
 let moved=app.settings.layout.cells!["5"]!.dx
 precondition(app.undoMoveButton.isEnabled);app.undoMove();precondition(app.settings.layout.cells!["5"]==nil && !app.undoMoveButton.isEnabled);precondition(app.redoButton.isEnabled);app.redoMove();precondition(abs(app.settings.layout.cells!["5"]!.dx-moved)<0.001);app.undoMove()
 v.visibleCells=v.availableCells;drag(first,0.2,0.2);precondition(abs(app.settings.layout.cells!["5"]!.dx-moved)<0.001)
 // syncPreview only affects currently visible metadata; keep the synthetic fixture visible.
 v.visibleCells=v.availableCells
 drag(second,-0.08,0.3);precondition(v.selectedCells==second)
 v.visibleCells=v.availableCells
 draw(CGRect(x:0.28,y:0.19,width:0.08,height:0.17));precondition(v.selectedCells==first.union(second))
 app.osdScale.doubleValue=30;app.scaleOSD();precondition(abs(app.settings.layout.cells!["5"]!.scale-1.5)<0.001);app.selectionChanged();precondition(app.sizeValue.stringValue=="30")
 drag(first,0.1,0);precondition(v.selectedCells==first.union(second))
 app.preview.selectedCells=first;app.selectionChanged();app.hideOSDSelection()
 precondition(first.allSatisfy{app.settings.layout.cells![String($0)]!.hidden})
 precondition(app.preview.selectedCells==first);precondition(app.hideSelectionButton.toolTip=="Show selection")
 app.hideOSDSelection();precondition(first.allSatisfy{app.settings.layout.cells![String($0)]!.hidden==false})
 precondition(parseExportTime("01:02.500")==62.5 && parseExportTime("1:02:03")==3723)
 precondition(parseExportTime("-1")==nil && parseExportTime("00:90")==nil)
 app.duration=40;app.startField.stringValue="00:02.000";app.endField.stringValue="00:05.000";precondition(app.chosenRange()!.1-app.chosenRange()!.0==3)
 app.endField.stringValue="00:50";precondition(app.chosenRange()==nil)
 // Adjacent words / icon and value separated by one blank cell form one group.
 precondition(detectedGroups([0,1,3,4],[:]).count==1)
 precondition(detectedGroups([0,1,5,6],[:]).count==2)
 precondition(detectedGroups([0,53],[:]).count==2)
 var layout=Layout();let text="Time:1:05";let w=(text as NSString).size(withAttributes:textAttributes(layout.line,1080)).width
 layout.lineAlignment="Left";precondition(abs(lineX(layout,text,1920,1080)-38.4)<0.01)
 layout.lineAlignment="Centre";precondition(abs(lineX(layout,text,1920,1080)+w/2-960)<0.01)
 layout.lineAlignment="Right";precondition(abs(lineX(layout,text,1920,1080)+w-1881.6)<0.01)
 let restored=try JSONDecoder().decode(Layout.self,from:JSONEncoder().encode(layout));precondition(restored.lineAlignment=="Right")
 // Trim handles update the right-hand fields from the timeline.
 app.duration=40;app.fullVideo();let tl=app.timelineView;let aPoint=NSPoint(x:tl.x(0),y:tl.track.midY),bPoint=NSPoint(x:tl.x(5),y:tl.track.midY)
 func timelineEvent(_ type:NSEvent.EventType,_ point:NSPoint)->NSEvent{NSEvent.mouseEvent(with:type,location:tl.convert(point,to:nil),modifierFlags:[],timestamp:0,windowNumber:app.window.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!}
 tl.mouseDown(with:timelineEvent(.leftMouseDown,aPoint));tl.mouseDragged(with:timelineEvent(.leftMouseDragged,bPoint));tl.mouseUp(with:timelineEvent(.leftMouseUp,bPoint));precondition(abs(parseExportTime(app.startField.stringValue)!-5)<0.01)
 // Drawing commands preserve complete fields across changing digit counts.
 let frameA=OSDFrame(time:0,glyphs:[],runs:[Set(37...42),Set(45...48)]),frameB=OSDFrame(time:1,glyphs:[],runs:[Set(37...43),Set(45...48)])
 let groups=recordingElements([frameA,frameB]);precondition(groups.count==2 && groups[0]==Set(37...43))
 // Shared controls edit the whole telemetry line.
 app.preview.values=["FlightTime":"95","SBat":"3.59"];app.selectTelemetry()
 let originalSize=app.settings.layout.line.size;app.osdScale.doubleValue=originalSize*1.5;app.scaleOSD();precondition(abs(app.settings.layout.line.size-(originalSize*1.5).rounded())<0.01)
 app.osdColour.color = .red;app.tintOSD();precondition(app.settings.layout.line.green<0.01)
 app.preview.telemetrySelected=true;app.selectionChanged()
 let lineBox=v.lineRect();let linePoint=NSPoint(x:lineBox.midX,y:lineBox.midY);let movedPoint=NSPoint(x:linePoint.x+30,y:linePoint.y-30)
 let oldLineY=app.settings.layout.line.y
 v.mouseDown(with:event(.leftMouseDown,linePoint));precondition(v.draggingTelemetry);v.mouseDragged(with:event(.leftMouseDragged,movedPoint));v.mouseUp(with:event(.leftMouseUp,movedPoint))
 precondition(app.settings.layout.line.y<oldLineY);app.undoMove();precondition(abs(app.settings.layout.line.y-oldLineY)<0.001)
 // Save overwrites the explicitly selected preset and clears its dirty state.
 app.settings.presets["Test"]=app.settings.layout;app.refreshPresets();app.selectPresetNamed("Test",in:app.preset);app.activePresetName="Test";app.updatePresetSaveState();precondition(!app.presetSaveButton.isEnabled)
 app.settings.layout.line.size+=1;app.save();precondition(app.presetSaveButton.isEnabled);app.overwritePreset();precondition(!app.presetSaveButton.isEnabled && app.settings.presets["Test"]!.line.size==app.settings.layout.line.size)
 app.lastSRT=URL(fileURLWithPath:"/tmp/Matching.srt");app.updateFileLabels();precondition(app.srtName.stringValue.contains("Matching.srt"))
 // Alignment and snap are shared selection tools.
 app.preview.telemetrySelected=false;app.preview.selectedCells=first;app.alignSelection(0,0)
 var bounds=cellBounds(first,app.settings.layout.cells ?? [:]);precondition(abs(bounds.minX-0.02)<0.001 && abs(bounds.minY-0.02)<0.001)
 app.settings.layout.gridEnabled=true;app.settings.layout.gridColumns=32;app.syncPreview();v.visibleCells=v.availableCells
 drag(first,0.07,0.06);bounds=cellBounds(first,app.settings.layout.cells ?? [:])
 precondition(abs(bounds.minX*32-(bounds.minX*32).rounded())<0.001)
 let rowStep=(1920.0/1080)/32;precondition(abs(bounds.minY/rowStep-(bounds.minY/rowStep).rounded())<0.001)
 // Exported presets round-trip safely without font files.
 let packed=try app.packagePreset("Test");let imported=try app.acceptPreset(packed);precondition(imported != "Test" && app.settings.presets[imported] != nil)
 app.settings.startup="Test";try app.renamePresetValue("Test","Renamed");precondition(app.settings.presets["Test"]==nil && app.settings.startup=="Renamed (16:9)")
 var bad=SharedPreset(name:"Bad",layout:Layout());bad.version=99
 do{_ = try app.acceptPreset(JSONEncoder().encode(bad));preconditionFailure("Invalid preset accepted")}catch{}
 var invalid=Layout();invalid.line.size=1e10;precondition(!presetIsValid(invalid))
 // A real TTF is copied to the app-owned library and registered from that copy.
 let systemFont=URL(fileURLWithPath:"/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf")
 if FileManager.default.fileExists(atPath:systemFont.path){
  let copy=app.fontDirectory.appendingPathComponent("font-test.ttf");try Data(contentsOf:systemFont).write(to:copy)
  let ps=try registerTextFont(copy);precondition(NSFont(name:ps,size:20) != nil)
 }
 // Built-in text choices resolve to distinct real typefaces.
 precondition(libraryTextFont("builtin:mono",20).fontName != libraryTextFont("builtin:serif",20).fontName)
 let record=LibraryFont(id:"test",name:"Example",kind:"text",file:"test.ttf",postScriptName:"Example-Regular")
 app.settings.fonts=[record];let restoredFonts=try JSONDecoder().decode(Settings.self,from:JSONEncoder().encode(app.settings));precondition(restoredFonts.fonts?.first?.name=="Example")
 app.duration=40.968;app.fullVideo();precondition(app.endField.stringValue=="00:00:40" && abs(app.chosenRange()!.1-40.968)<0.0001)
 precondition(app.clock(3723)=="01:02:03")
 // Align elements to the leftmost selected item, rather than to the frame.
 app.preview.telemetrySelected=false;v.elementGroups=[first,second];v.visibleCells=first.union(second);v.selectedCells=first.union(second)
 let leftmost=cellBounds(v.selectedCells,app.settings.layout.cells ?? [:]).minX
 app.alignReference.selectItem(at:1);app.alignSelection(0,nil)
 precondition(abs(cellBounds(first,app.settings.layout.cells ?? [:]).minX-leftmost)<0.001 && abs(cellBounds(second,app.settings.layout.cells ?? [:]).minX-leftmost)<0.001)
 // Sections remain non-overlapping when collapsed or expanded.
 func sections(_ view:NSView)->[CompactSection]{view.subviews.flatMap{child in (child as? CompactSection).map{[$0]} ?? sections(child)}}
 let cards=sections(app.window.contentView!)
 for card in cards{precondition(card.expanded);card.expanded=false;card.update()}
 app.window.contentView!.layoutSubtreeIfNeeded()
 let rectangles=cards.map{$0.convert($0.bounds,to:nil)}.sorted{$0.minY<$1.minY}
 precondition(rectangles.allSatisfy{$0.height>=37})
 for i in 1..<rectangles.count{precondition(rectangles[i].minY>=rectangles[i-1].maxY-0.5)}
 for card in cards{card.expanded=true;card.update()};app.window.contentView!.layoutSubtreeIfNeeded()
 // Batch uses full videos and disables trim controls; sizing choices preserve aspect.
 app.asset=AVURLAsset(url:URL(fileURLWithPath:"/tmp/OSDEditorTestVideo.mp4"));app.loadingOSD=false;app.setBatchSources([URL(fileURLWithPath:"/tmp/a.mp4"),URL(fileURLWithPath:"/tmp/b.mp4")]);app.updateEnabled();precondition(!app.startField.isEnabled && !app.endField.isEnabled && !app.timelineView.trimmingEnabled && app.export.isEnabled)
 print("SKIP: media dimension assertions require a real fixture; use --aspect-test with your own recording")
 app.setBatchSources([]);app.updateEnabled();precondition(app.timelineView.trimmingEnabled && app.startField.isEnabled)
 // Discard restores the selected preset and Make Default persists the chosen launch name.
 var closing=app.defaultLayout();closing.line.size=31;app.settings.presets["Closing"]=closing;app.activePresetName="Closing";app.settings.layout=closing;app.settings.layout.line.size=42;precondition(app.presetDirty());app.discardActiveChanges();precondition(app.settings.layout.line.size==31 && !app.presetDirty());app.makePresetDefault();precondition(app.settings.startup=="Closing" && app.makeDefaultButton.title=="Default on launch" && !app.makeDefaultButton.isEnabled)
 app.settings.layout.line.size=39;precondition(app.saveActiveChanges());precondition(app.settings.presets["Closing"]!.line.size==39 && !app.presetDirty())
 app.activePresetName="Default";app.settings.layout=app.defaultLayout();app.settings.startup="Default";app.refreshUI()
 // Status bar cannot expand when its message changes or the window grows.
 func findStatus(_ view:NSView)->NSView?{if view.identifier?.rawValue=="statusBar"{return view};for child in view.subviews{if let found=findStatus(child){return found}};return nil}
 let statusBar=findStatus(app.window.contentView!)!;app.status.stringValue="Video loaded";app.window.setContentSize(NSSize(width:1300,height:950));app.window.contentView!.layoutSubtreeIfNeeded();precondition(abs(statusBar.frame.height-24)<0.1)
 app.status.stringValue="";app.window.contentView!.layoutSubtreeIfNeeded();precondition(abs(statusBar.frame.height-24)<0.1)
 // Startup ignores obsolete last-layout data and deleted launch presets.
 app.settings.presets=[:];app.settings.startup="Last settings";app.settings.layout.line.x=0.9;app.applyStartupLayout()
 precondition(app.activePresetName=="Default" && app.settings.layout.line.x==0.12 && app.settings.startup=="Default")
 var example=app.defaultLayout();example.line.x=0.35;app.settings.presets["Example"]=example;app.settings.startup="Example";app.applyStartupLayout()
 precondition(app.activePresetName=="Example" && app.settings.layout.line.x==0.35)
 app.settings.layout.line.x=0.8;app.removePresetValue("Example")
 precondition(app.activePresetName=="Default" && app.settings.layout.line.x==0.12 && app.settings.startup=="Default" && app.settings.presets.isEmpty)
 app.settings.layout.line.x=0.75;let disk=try JSONEncoder().encode(app.settings);app.settings=try JSONDecoder().decode(Settings.self,from:disk);app.applyStartupLayout()
 precondition(app.settings.layout.line.x==0.12 && app.activePresetName=="Default")
 app.removePresetValue("Default");precondition(app.activePresetName=="Default" && app.settings.presets.isEmpty)
 precondition(app.presetDefinition("Default") != nil)
 let available=extraTextChoices.filter{NSFont(name:$0.1,size:12) != nil}.map{$0.0};print("Available default font choices:",available.joined(separator:", "))
 try? FileManager.default.removeItem(at:app.settingsURL.deletingLastPathComponent())

 var testVisuals=defaultVisuals();for i in testVisuals.indices{testVisuals[i].enabled=true};app.settings.layout.visuals=testVisuals;app.preview.selectedVisual=0;app.preview.telemetrySelected=false;app.preview.selectedCells=[];app.selectionChanged();precondition(app.sizeValue.isEnabled && app.osdScale.doubleValue==20 && app.hideSelectionButton.isEnabled)
 app.osdScale.doubleValue=30;app.scaleOSD();precondition(app.settings.layout.visuals![0].scale==1.5 && app.settings.layout.visuals![1].scale==1 && app.preview.selectedVisual==0)
 app.hideOSDSelection();precondition(app.settings.layout.visuals![0].hidden==true && app.preview.selectedVisual==0);app.hideOSDSelection();precondition(app.settings.layout.visuals![0].hidden==false)
 app.alignSelection(0,0);precondition(app.settings.layout.visuals![0].x==0.02 && app.settings.layout.visuals![0].y==0.02);app.undoMove();precondition(app.settings.layout.visuals![0].x==testVisuals[0].x)
 app.clearOSDSelection();precondition(app.preview.selectedVisual==nil)
 app.selectAllVisuals();precondition(app.selectionChooser.selectedSegment==3 && app.chosenVisuals.count==6);app.osdScale.doubleValue=24;app.scaleOSD();precondition(app.settings.layout.visuals!.allSatisfy{abs($0.scale-1.2)<0.001});app.clearOSDSelection()

 app.settings.layout.gridEnabled=false;app.settings.layout.visuals=defaultVisuals();for i in [0,1]{app.settings.layout.visuals![i].enabled=true};app.syncPreview()
 draw(CGRect(x:0.03,y:0.55,width:0.27,height:0.32));precondition(v.selectedVisuals==Set([0,1]) && app.chosenVisuals.count==2)
 let card=visualRect(app.settings.layout.visuals![0],v.videoRect);let start=CGPoint(x:card.midX,y:card.midY),end=CGPoint(x:card.midX+v.videoRect.width*0.1,y:card.midY-v.videoRect.height*0.1)
 v.mouseDown(with:event(.leftMouseDown,start));v.mouseDragged(with:event(.leftMouseDragged,end));v.mouseUp(with:event(.leftMouseUp,end));precondition(abs(app.settings.layout.visuals![0].x-0.15)<0.001 && abs(app.settings.layout.visuals![1].x-0.15)<0.001);precondition(abs(app.settings.layout.visuals![0].y-app.settings.layout.visuals![1].y-0.15)<0.001);app.undoMove();precondition(abs(app.settings.layout.visuals![0].x-0.05)<0.001)
 app.customTextEntry!.stringValue="My Drone 123";app.customTextEdited(app.customTextEntry!);precondition(app.settings.layout.visuals![5].text=="MY DRONE 123");app.customTextCheck!.state = .on;app.customTextToggle(app.customTextCheck!);precondition(app.settings.layout.visuals![5].enabled);let roundtrip=try JSONDecoder().decode(Layout.self,from:JSONEncoder().encode(app.settings.layout));precondition(roundtrip.visuals![5].text=="MY DRONE 123" && presetIsValid(roundtrip))
 print("PASS: custom label editing, uppercase conversion, toggle, preset validation and roundtrip")
 print("PASS: box selection of whole visual cards, group drag, spacing preservation and Undo")
 print("PASS: visual toolbar selection, individual/group sizing, persistent hide/show, alignment and Undo")
 print("PASS: Default startup/delete/reopen, item-relative alignment, movement/Undo, shared telemetry controls, preset save/share/validation, fonts, grid and trim")
 exit(0)
} else if CommandLine.arguments.contains("--rendering-test") {
 _ = NSApplication.shared
 let renderer=try OSDRenderer(URL(fileURLWithPath:CommandLine.arguments[2]))
 let frames=[OSDFrame(time:0,glyphs:[Glyph(x:0,y:0,index:65)])]
 let styles=["0":CellStyle(hidden:true)]
 let exported=renderer.layer(0,frames,styles,1920,1080)
 precondition(exported.extent.isEmpty)
 let preview=renderer.layer(0,frames,styles,1920,1080,showHidden:true)
 var pixels=[UInt8](repeating:0,count:36*54*4)
 renderer.context.render(preview,toBitmap:&pixels,rowBytes:36*4,bounds:CGRect(x:0,y:1026,width:36,height:54),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
 let alpha=stride(from:3,to:pixels.count,by:4).map{pixels[$0]}
 precondition(alpha.max()!>0 && alpha.max()!<=70)
 print("PASS: hidden glyph absent from export, present as faded grey preview (maximum alpha \(alpha.max()!))")
 exit(0)
} else if CommandLine.arguments.contains("--playback-test") {
 let a=NSApplication.shared;let app=App();a.delegate=app;app.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
 app.loadVideo(URL(fileURLWithPath:CommandLine.arguments[2]))
 app.exactIn=1;app.exactOut=2;app.startField.stringValue=app.rangeTime(1);app.endField.stringValue=app.rangeTime(2);app.rangeEdited()
 Timer.scheduledTimer(withTimeInterval:0.5,repeats:false){_ in app.togglePlayback()}
 Timer.scheduledTimer(withTimeInterval:3.5,repeats:false){_ in
  let t=app.player?.currentTime().seconds ?? 0;precondition(!app.isPlaying && abs(t-2)<0.05);app.pausePlayback()
  precondition(t>0.5 && app.playbackFrames>3 && app.srtName.stringValue.contains("Video006.srt"))
  print("PASS: playback stayed in 00:00:01–00:00:02 and stopped at \(t) seconds; \(app.playbackFrames) decoded preview frames; matching SRT displayed")
  try? FileManager.default.removeItem(at:app.settingsURL.deletingLastPathComponent());exit(0)
 };a.run()
} else if CommandLine.arguments.contains("--osd-test") {
 let source=URL(fileURLWithPath:CommandLine.arguments[2])
 let extracted=try extractOSD(source)
 precondition(!extracted.isEmpty && extracted.allSatisfy{$0.time.isFinite && $0.glyphs.allSatisfy{$0.x<53 && $0.y<20}})
 guard FileManager.default.fileExists(atPath:source.deletingPathExtension().appendingPathExtension("osd").path) else{print("PASS: extracted \(extracted.count) valid OSD frames from MP4 (no sidecar present)");exit(0)}
 let sidecar=try readOSD(source.deletingPathExtension().appendingPathExtension("osd"))
 FileHandle.standardError.write(Data("Counts \(extracted.count) / \(sidecar.count)\n".utf8));precondition(extracted.count==sidecar.count)
 for (a,b) in zip(extracted,sidecar){
  if abs(a.time-b.time)>0.002{FileHandle.standardError.write(Data("Time difference \(a.time) / \(b.time)\n".utf8))}
  let key:(Glyph)->String={"\($0.x),\($0.y),\($0.index)"}
  var grid=[String:Int]();for g in a.glyphs{grid["\(g.x),\(g.y)"]=g.index}
  var other=[String:Int]();for g in b.glyphs{other["\(g.x),\(g.y)"]=g.index}
  if grid != other {FileHandle.standardError.write(Data("Grid difference at \(a.time): \(Set(a.glyphs.map(key)).subtracting(Set(b.glyphs.map(key))))\n".utf8));exit(1)}
 }
 let region=Region(name:"Test",col:0,row:0,columns:6,rows:1,dx:0.1,dy:0.1)
 precondition(region.contains(Glyph(x:2,y:0,index:65)))
 precondition(!region.contains(Glyph(x:8,y:0,index:65)))
 print("PASS: \(extracted.count) embedded OSD frames match supplied .osd; region membership verified")
} else if CommandLine.arguments.contains("--render-test") {
 let a=NSApplication.shared;let app=App();a.delegate=app
 app.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
 let source=URL(fileURLWithPath:CommandLine.arguments[2]);let output=URL(fileURLWithPath:CommandLine.arguments[3]);app.loadVideo(source)
 app.loadToken+=1;app.loadingOSD=false
 app.osdFrames=try extractOSD(source)
 if CommandLine.arguments.count>4{app.osdRenderer=try OSDRenderer(URL(fileURLWithPath:CommandLine.arguments[4]))}
 if CommandLine.arguments.contains("--4k"){app.settings.layout.outputSize="4K · 2160p"};if CommandLine.arguments.contains("--2k"){app.settings.layout.outputSize="2K · 1440p"}
 if CommandLine.arguments.contains("--4x3"){app.settings.layout=aspectAdjustment(app.settings.layout,"4:3",app.preview.sourceSize,app.osdFrames,app.cues,picture:detectedPictureRect(app.asset!)).layout}
 if CommandLine.arguments.contains("--visuals"){var v=defaultVisuals();for i in v.indices{v[i].enabled=true};app.settings.layout.visuals=v}
 print("Extracted OSD frames:",app.osdFrames.count)
 if CommandLine.arguments.contains("--moved"){
  let ids=Set(app.osdFrames.flatMap{$0.glyphs.filter{$0.y==0 && $0.x<6}.map{$0.y*53+$0.x}})
  var cells=[String:CellStyle]();moveCells(ids,&cells,0.1,0.15);scaleCells(ids,&cells,1.5)
  for id in ids{var style=cells[String(id)]!;style.tint=[0.1,0.8,1];cells[String(id)]=style};app.settings.layout.cells=cells
 }
 if CommandLine.arguments.contains("--hevc"){app.settings.layout.codec="HEVC"}
 let asset=app.asset!;let s=AVAssetExportSession(asset:asset,presetName:app.settings.layout.codec=="HEVC" ? AVAssetExportPresetHEVCHighestQuality:AVAssetExportPresetHighestQuality)!;s.timeRange=CMTimeRange(start:CMTime(seconds:CommandLine.arguments.contains("--trim-test") ? 2:0,preferredTimescale:600),duration:CMTime(seconds:3,preferredTimescale:600));s.outputURL=output;s.outputFileType = .mp4;s.videoComposition=app.composition(asset,widgets:app.settings.layout.widgets,cues:app.cues)
 s.exportAsynchronously{print("Render test status: \(s.status.rawValue) error: \(String(describing:s.error))");exit(s.status == .completed ? 0:1)};a.run()
} else {let a=NSApplication.shared;let app=App();a.delegate=app;a.run()}
