// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech) — original Swift implementation and modifications.
import Cocoa
import AVFoundation

func exportDimensions(_ asset:AVAsset,_ choice:String,aspect:String?=nil)->CGSize{
 guard let track=asset.tracks(withMediaType:.video).first else{return CGSize(width:1920,height:1080)}
 let transformed=track.naturalSize.applying(track.preferredTransform);let source=centreCrop(CGSize(width:abs(transformed.width),height:abs(transformed.height)),aspect,picture:aspect == nil ? nil:detectedPictureRect(asset)).size
 guard choice != "Original" else{return CGSize(width:max(2,(source.width/2).rounded()*2),height:max(2,(source.height/2).rounded()*2))}
 let edge:CGFloat=choice.hasPrefix("4K") ? 3840:2560;let scale=edge/max(source.width,source.height)
 return CGSize(width:max(2,(source.width*scale/2).rounded()*2),height:max(2,(source.height*scale/2).rounded()*2))
}
func matchingSRT(_ source:URL)->URL?{
 let same=source.deletingPathExtension().appendingPathExtension("srt")
 if FileManager.default.fileExists(atPath:same.path){return same}
 return ((try? FileManager.default.contentsOfDirectory(at:source.deletingLastPathComponent(),includingPropertiesForKeys:nil)) ?? []).first{$0.pathExtension.lowercased()=="srt" && $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(source.deletingPathExtension().lastPathComponent) == .orderedSame}
}
extension App{
 func updateStatusSummary(){
  let range=batchSources.count>1 ? "Batch \(batchSources.count) · Full videos":"In \(startField.stringValue) · Out \(endField.stringValue)"
  statusSummary.stringValue="\(displayPresetName(activePresetName))\(presetDirty() ? " *":"")  ·  \(range)  ·  \(settings.layout.codec)  ·  \(settings.layout.outputSize ?? "Original") · \(settings.layout.aspectRatio ?? aspectLabel(preview.sourceSize))"
 }
 @objc func outputSizeChanged(){var proposed=settings.layout;proposed.outputSize=outputSize.titleOfSelectedItem ?? "Original";if let asset=asset{guard let compatible=compatibleExportLayout(proposed,asset) else{outputSize.selectItem(withTitle:settings.layout.outputSize ?? "Original");return};proposed=compatible};settings.layout=proposed;codec.selectItem(withTitle:proposed.codec);save();updateStatusSummary()}
 func setBatchSources(_ sources:[URL]){
  batchSources=sources;batchPicker.removeAllItems();for (i,url) in sources.enumerated(){batchPicker.addItem(withTitle:"\(i+1). \(url.lastPathComponent)")}
  batchPicker.isHidden=sources.count<2;batchLabel.stringValue=sources.count>1 ? "\(sources.count) videos · One layout · Full-length exports":"Single video · Trimming available"
  updateEnabled();updateStatusSummary()
 }
 @objc func openBatch(){
  pausePlayback();let panel=NSOpenPanel();panel.allowedContentTypes=[.movie,.mpeg4Movie,.quickTimeMovie];panel.allowsMultipleSelection=true;panel.message="Choose the videos to process with one shared layout. Each uses its matching SRT; batch trimming is disabled."
  guard panel.runModal() == .OK,!panel.urls.isEmpty else{return};let sources=panel.urls.sorted{$0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending};setBatchSources(sources);loadVideo(sources[0])
 }
 @objc func batchPreviewChanged(){let index=batchPicker.indexOfSelectedItem;guard !batchRunning,batchSources.indices.contains(index) else{return};loadVideo(batchSources[index])}
 func beginBatchExport(){
  guard !batchRunning,session==nil else{return};pausePlayback();let panel=NSOpenPanel();panel.canChooseFiles=false;panel.canChooseDirectories=true;panel.canCreateDirectories=true;panel.message="Choose where to save a new batch export folder. Original videos will stay unchanged."
  guard panel.runModal() == .OK,let directory=panel.url else{return}
  let date=DateFormatter();date.dateFormat="yyyyMMdd-HHmmss";let folder=directory.appendingPathComponent("P1-exports-"+date.string(from:Date())+"-"+String(UUID().uuidString.prefix(4)))
  do{try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false)}catch{status.stringValue="Couldn’t create export folder: \(error.localizedDescription)";return}
  startBatch(to:folder)
 }
 func startBatch(to folder:URL){
  batchDestination=folder;batchPresetName=displayPresetName(activePresetName);batchLayout=settings.layout;batchRenderer=osdRenderer;batchRunning=true;batchCancelled=false;batchIndex=0;batchResults=[];updateEnabled();nextBatchFile()
 }
 func nextBatchFile(){
  guard !batchCancelled,batchIndex<batchSources.count else{finishBatch();return}
  let index=batchIndex;let source=batchSources[index];let layout=batchLayout!;let renderer=batchRenderer
  status.stringValue="Preparing \(index+1)/\(batchSources.count): \(source.lastPathComponent)";bar.doubleValue=Double(index)/Double(batchSources.count)*100;exportPercent.stringValue=String(format:"%.0f%%",bar.doubleValue)
  DispatchQueue.global(qos:.userInitiated).async{
   let asset=AVURLAsset(url:source);let seconds=CMTimeGetSeconds(asset.duration)
   var frames=[OSDFrame]();var cues=[Cue]();var problem:String?
   do{
    guard seconds.isFinite,seconds>0,!asset.tracks(withMediaType:.video).isEmpty else{throw NSError(domain:"Batch",code:1,userInfo:[NSLocalizedDescriptionKey:"Unreadable video"])}
    frames=(try? extractOSD(source)) ?? [];let sidecar=source.deletingPathExtension().appendingPathExtension("osd");if frames.isEmpty,FileManager.default.fileExists(atPath:sidecar.path){frames=try readOSD(sidecar)}
    if let srt=matchingSRT(source){cues=parseSRT(try String(contentsOf:srt,encoding:.utf8))}
    guard !frames.isEmpty || !cues.isEmpty else{throw NSError(domain:"Batch",code:2,userInfo:[NSLocalizedDescriptionKey:"No OSD or matching telemetry SRT found"])}
    if !frames.isEmpty && renderer==nil{throw NSError(domain:"Batch",code:3,userInfo:[NSLocalizedDescriptionKey:"Import a compatible OSD PNG font first"])}
   }catch{problem=error.localizedDescription}
   DispatchQueue.main.async{
    guard !self.batchCancelled else{self.finishBatch();return}
    if let problem=problem{self.batchResults.append("FAILED: \(source.lastPathComponent) — \(problem)");self.batchIndex+=1;self.nextBatchFile();return}
    self.exportBatchFile(asset,source,frames,cues,seconds,layout,renderer,index)
   }
  }
 }
 func exportBatchFile(_ asset:AVAsset,_ source:URL,_ frames:[OSDFrame],_ cues:[Cue],_ seconds:Double,_ layout:Layout,_ renderer:OSDRenderer?,_ index:Int){
  let profile=layout.codec=="HEVC" ? AVAssetExportPresetHEVCHighestQuality:AVAssetExportPresetHighestQuality
  guard let export=AVAssetExportSession(asset:asset,presetName:profile),export.supportedFileTypes.contains(.mp4) else{batchResults.append("FAILED: \(source.lastPathComponent) — Export format unavailable");batchIndex+=1;nextBatchFile();return}
  let destination=uniqueExportURL(batchDestination!.appendingPathComponent(exportFileName(source,batchPresetName,layout.outputSize ?? "Original",exportDimensions(asset,layout.outputSize ?? "Original",aspect:layout.aspectRatio))))
  export.outputURL=destination;export.outputFileType = .mp4;export.timeRange=CMTimeRange(start:.zero,duration:CMTime(seconds:seconds,preferredTimescale:60000));let fitted=layout.aspectRatio == nil ? layout:fitOverlays(layout,recordingElements(frames),cues,exportDimensions(asset,"Original",aspect:layout.aspectRatio)).layout;export.videoComposition=composition(asset,widgets:fitted.widgets,cues:cues,layoutOverride:fitted,framesOverride:frames,rendererOverride:renderer);session=export
  status.stringValue="Exporting \(index+1)/\(batchSources.count): \(source.lastPathComponent)"
  progressTimer=Timer.scheduledTimer(withTimeInterval:0.3,repeats:true){[weak self] _ in guard let self=self else{return};let progress=(Double(index)+Double(export.progress))/Double(self.batchSources.count)*100;self.bar.doubleValue=progress;self.exportPercent.stringValue=String(format:"%.0f%%",progress)}
  export.exportAsynchronously{DispatchQueue.main.async{
   self.progressTimer?.invalidate();self.progressTimer=nil;self.session=nil
   if export.status == .completed{self.batchResults.append("SAVED: \(destination.lastPathComponent)")}else{try? FileManager.default.removeItem(at:destination);self.batchResults.append("\(self.batchCancelled ? "CANCELLED":"FAILED"): \(source.lastPathComponent) — \(export.error?.localizedDescription ?? "Export stopped")")}
   self.batchIndex+=1;self.nextBatchFile()
  }}
 }
 func finishBatch(){
  let saved=batchResults.filter{$0.hasPrefix("SAVED:")}.count
  let summary="\(batchCancelled ? "Batch stopped":"Batch complete"): \(saved)/\(batchSources.count) videos saved."
  if let folder=batchDestination{try? (summary+"\n\n"+batchResults.joined(separator:"\n")).write(to:folder.appendingPathComponent("Batch report.txt"),atomically:true,encoding:.utf8);if !CommandLine.arguments.contains("--batch-test") && !CommandLine.arguments.contains("--batch-cancel-test"){NSWorkspace.shared.activateFileViewerSelecting([folder])}}
  batchRunning=false;session=nil;status.stringValue=summary;bar.doubleValue=100;updateEnabled()
  if CommandLine.arguments.contains("--batch-cancel-test"){print("CANCELLED:",batchCancelled,"saved",saved);exit(batchCancelled && saved<batchSources.count ? 0:1)}
  if CommandLine.arguments.contains("--batch-test"){print(batchResults.joined(separator:"\n"));exit(saved==batchSources.count ? 0:1)}
 }
}

func compactPresetName(_ name:String)->String{
 let pieces=name.components(separatedBy:CharacterSet.alphanumerics.inverted).filter{!$0.isEmpty}
 return String(pieces.joined(separator:"-").prefix(20)).trimmingCharacters(in:CharacterSet(charactersIn:"-"))
}
func exportFileName(_ source:URL,_ preset:String,_ size:String,_ dimensions:CGSize)->String{
 var parts=[source.deletingPathExtension().lastPathComponent,"TELEM"]
 if preset != "Default"{let compact=compactPresetName(preset);if !compact.isEmpty{parts.append(compact)}}
 parts.append(size.hasPrefix("4K") ? "4K":(size.hasPrefix("2K") ? "2K":"\(Int(dimensions.height.rounded()))p"))
 if aspectLabel(dimensions)=="4:3"{parts.append("4x3")}
 return parts.joined(separator:"-")+".mp4"
}
func uniqueExportURL(_ desired:URL)->URL{
 var candidate=desired;var number=2
 while FileManager.default.fileExists(atPath:candidate.path){candidate=desired.deletingLastPathComponent().appendingPathComponent(desired.deletingPathExtension().lastPathComponent+"-\(number)").appendingPathExtension(desired.pathExtension);number+=1}
 return candidate
}
