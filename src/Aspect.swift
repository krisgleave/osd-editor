// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech) — original Swift implementation and modifications.
import Cocoa
import AVFoundation

func aspectLabel(_ size:CGSize)->String{
 let ratio=size.width/max(1,size.height)
 if abs(ratio-16.0/9)<0.02{return "16:9"};if abs(ratio-4.0/3)<0.02{return "4:3"};return "Source"
}
func centreCrop(_ source:CGSize,_ aspect:String?,picture:CGRect?=nil)->CGRect{
 guard aspect != nil else{return CGRect(origin:.zero,size:source)}
 if aspect==aspectLabel(source){return CGRect(origin:.zero,size:source)}
 let content=picture ?? CGRect(origin:.zero,size:source)
 let requested:CGFloat=aspect=="4:3" ? 4/3:(aspect=="16:9" ? 16/9:source.width/max(1,source.height))
 var size=content.size
 if size.width/max(1,size.height)>requested{size.width=content.height*requested}else{size.height=content.width/requested}
 return CGRect(x:content.midX-size.width/2,y:content.midY-size.height/2,width:size.width,height:size.height)
}
struct AspectAdjustment{var layout:Layout;var movedGroups:Int;var telemetryAdjusted:Bool}
func fitOverlays(_ initial:Layout,_ groups:[Set<Int>],_ cues:[Cue],_ canvas:CGSize)->AspectAdjustment{
 var layout=initial;var cells=layout.cells ?? [:];let safe=CGRect(x:0.02,y:0.02,width:0.96,height:0.96);var moved=0
 for group in groups where !group.isEmpty{
  var box=cellBounds(group,cells)
  guard !box.isNull,box.width>0,box.height>0 else{continue}
  if !safe.insetBy(dx:-0.000001,dy:-0.000001).contains(box){
   moved+=1;let factor=min(1,min(safe.width/box.width,safe.height/box.height));if factor<1{scaleCells(group,&cells,factor)}
   box=cellBounds(group,cells);let x=max(safe.minX,min(safe.maxX-box.width,box.minX));let y=max(safe.minY,min(safe.maxY-box.height,box.minY));moveCells(group,&cells,x-box.minX,y-box.minY)
  }
 }
 layout.cells=cells
 let texts=Set(cues.map{telemetryLine($0.values,layout.widgets)}).filter{!$0.isEmpty}
 var telemetryChanged=false
 if !texts.isEmpty{
  func measurements()->CGSize{texts.reduce(CGSize.zero){result,text in let size=(text as NSString).size(withAttributes:textAttributes(layout.line,canvas.height));return CGSize(width:max(result.width,size.width),height:max(result.height,size.height))}}
  var size=measurements();let available=canvas.width*safe.width
  if size.width>available{layout.line.size=max(1,floor(layout.line.size*available/size.width*0.999));telemetryChanged=true;size=measurements()}
  let oldX=layout.line.x,oldY=layout.line.y
  if effectiveAlignment(layout)=="Custom"{layout.line.x=max(safe.minX,min(safe.maxX-size.width/canvas.width,layout.line.x))}
  layout.line.y=max(safe.minY,min(safe.maxY-size.height/canvas.height,layout.line.y))
  telemetryChanged = telemetryChanged || abs(oldX-layout.line.x)>0.000001 || abs(oldY-layout.line.y)>0.000001
 }
 return AspectAdjustment(layout:layout,movedGroups:moved,telemetryAdjusted:telemetryChanged)
}
func aspectAdjustment(_ initial:Layout,_ aspect:String?,_ source:CGSize,_ frames:[OSDFrame],_ cues:[Cue],picture:CGRect?=nil)->AspectAdjustment{
 let oldCrop=centreCrop(source,initial.aspectRatio,picture:picture),newCrop=centreCrop(source,aspect,picture:picture)
 var layout=initial;layout.aspectRatio=aspect;var cells=layout.cells ?? [:]
 if oldCrop != newCrop{
  let sy=oldCrop.height/newCrop.height;let sx=oldCrop.width/newCrop.width
  for id in 0..<1060{
   var style=cells[String(id)] ?? CellStyle();let box=cellRect(id,cells)
   let x=(oldCrop.minX+box.minX*oldCrop.width-newCrop.minX)/newCrop.width;let y=(oldCrop.minY+box.minY*oldCrop.height-newCrop.minY)/newCrop.height
   style.dx=x-Double(id%53)*36/1920;style.dy=y-Double(id/53)/20;style.scale *= sy;style.aspectX=(style.aspectX ?? 1)*sx/sy;cells[String(id)]=style
  }
  layout.line.x=(oldCrop.minX+initial.line.x*oldCrop.width-newCrop.minX)/newCrop.width
  layout.line.y=(oldCrop.minY+initial.line.y*oldCrop.height-newCrop.minY)/newCrop.height
  layout.line.size *= sy
 }
 layout.cells=cells
 return fitOverlays(layout,recordingElements(frames),cues,newCrop.size)
}
extension App{
 func refreshAspectPopup(){
  let selected=settings.layout.aspectRatio ?? aspectLabel(preview.sourceSize);aspectPopup.selectItem(withTitle:selected);aspectPopup.toolTip="Source: \(aspectLabel(preview.sourceSize)). The selected output frame uses a centred crop."
 }
 @objc func aspectChanged(){
  guard asset != nil,!loadingOSD else{refreshAspectPopup();return};pausePlayback()
  let choice=aspectPopup.titleOfSelectedItem;let aspect=choice=="Source" ? nil:choice
  var proposal=aspectAdjustment(settings.layout,aspect,preview.sourceSize,osdFrames,cues,picture:preview.pictureRect)
  if proposal.movedGroups>0 || proposal.telemetryAdjusted{
   let alert=NSAlert();alert.messageText="Adjust overlays to fit \(choice ?? "the frame")?"
   var affected=[String]();if proposal.movedGroups>0{affected.append("\(proposal.movedGroups) OSD group\(proposal.movedGroups==1 ? "":"s")")};if proposal.telemetryAdjusted{affected.append("the telemetry line")}
   alert.informativeText="The video will be cropped in the centre. \(affected.joined(separator:" and ")) would extend outside the new frame. Move whole groups inside and reduce their size only where needed? Telemetry will remain one line. This checks the entire recording."
   alert.addButton(withTitle:"Adjust to fit");alert.addButton(withTitle:"Cancel")
   guard alert.runModal() == .alertFirstButtonReturn else{refreshAspectPopup();return}
  }
  guard let asset=asset,let compatible=compatibleExportLayout(proposal.layout,asset) else{refreshAspectPopup();return};proposal.layout=compatible
  rememberMove();if activePresetName != "Default",let original=settings.presets[activePresetName],presetAspect(original) != (proposal.layout.aspectRatio ?? aspectLabel(preview.sourceSize)){activePresetName="Default"};settings.layout=proposal.layout;codec.selectItem(withTitle:settings.layout.codec);save();syncPreview();refreshAspectPopup();refreshPresets();selectionChanged();status.stringValue="Frame set to \(choice ?? "Source"). Centre crop; overlays fitted inside. Undo restores the previous frame and layout."
 }
}

private let pictureCache=NSCache<NSString,NSValue>()
func detectedPictureRect(_ asset:AVAsset)->CGRect{
 guard let track=asset.tracks(withMediaType:.video).first else{return CGRect(x:0,y:0,width:1920,height:1080)}
 let size=track.naturalSize.applying(track.preferredTransform);let source=CGSize(width:abs(size.width),height:abs(size.height));let full=CGRect(origin:.zero,size:source)
 guard let url=(asset as? AVURLAsset)?.url else{return full}
 let stamp=(try? url.resourceValues(forKeys:[.contentModificationDateKey]))?.contentModificationDate?.timeIntervalSince1970 ?? 0;let key=(url.path+String(stamp)) as NSString
 if let cached=pictureCache.object(forKey:key){return cached.rectValue}
 let generator=AVAssetImageGenerator(asset:asset);generator.appliesPreferredTrackTransform=true;generator.maximumSize = .zero
 let seconds=asset.duration.seconds;guard seconds.isFinite,seconds>0 else{return full}
 let images=[0.2,0.5,0.8].compactMap{fraction->NSBitmapImageRep? in guard let cg=try? generator.copyCGImage(at:CMTime(seconds:seconds*fraction,preferredTimescale:60000),actualTime:nil) else{return nil};return NSBitmapImageRep(cgImage:cg)}
 guard images.count==3,let first=images.first else{pictureCache.setObject(NSValue(rect:full),forKey:key);return full}
 let width=first.pixelsWide,height=first.pixelsHigh
 func black(_ x:Int,_ y:Int)->Bool{images.allSatisfy{image in guard let c=image.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else{return false};return max(c.redComponent,max(c.greenComponent,c.blueComponent))<0.035}}
 func blackColumn(_ x:Int)->Bool{let rows=stride(from:height/6,to:height*5/6,by:max(1,height/24));return rows.allSatisfy{black(x,$0)}}
 var left=0,right=0;while left<width/4 && blackColumn(left){left+=1};while right<width/4 && blackColumn(width-1-right){right+=1}
 let border=abs(left-right)<=max(2,width/100) && left>=2 && right>=2 && left<width/4 && right<width/4 ? min(left,right):0
 func blackRow(_ y:Int)->Bool{let columns=stride(from:width/4,to:width*3/4,by:max(1,width/24));return columns.allSatisfy{black($0,y)}}
 var top=0,bottom=0;while top<height/4 && blackRow(top){top+=1};while bottom<height/4 && blackRow(height-1-bottom){bottom+=1}
 let vertical=abs(top-bottom)<=max(2,height/100) && top>=2 && bottom>=2 && top<height/4 && bottom<height/4 ? min(top,bottom):0
 let x=(CGFloat(border)/CGFloat(width)*source.width).rounded()+(border>0 ? 1:0);let y=(CGFloat(vertical)/CGFloat(height)*source.height).rounded()+(vertical>0 ? 1:0);let result=full.insetBy(dx:x,dy:y);pictureCache.setObject(NSValue(rect:result),forKey:key);return result
}

func presetAspect(_ layout:Layout)->String{layout.aspectRatio ?? layout.referenceAspect ?? "16:9"}
extension App{
 func selectPresetNamed(_ name:String,in popup:NSPopUpButton){if let index=popup.itemArray.firstIndex(where:{$0.representedObject as? String==name}){popup.selectItem(at:index)}}
}

extension App{
 func compatibleExportLayout(_ proposed:Layout,_ asset:AVAsset)->Layout?{
  var layout=proposed;let dimensions=exportDimensions(asset,layout.outputSize ?? "Original",aspect:layout.aspectRatio)
  if layout.codec=="H.264" && dimensions.width*dimensions.height>4096*2304{
   let alert=NSAlert();alert.messageText="Use HEVC for full-size 4K 4:3?";alert.informativeText="The H.264 export path reduces this frame size. HEVC keeps the requested \(Int(dimensions.width))×\(Int(dimensions.height)) output and the source frame timing.";alert.addButton(withTitle:"Use HEVC");alert.addButton(withTitle:"Cancel");guard alert.runModal() == .alertFirstButtonReturn else{return nil};layout.codec="HEVC"
  };return layout
 }
}

extension App{
 func defaultForCurrentFrame()->Layout{
  guard settings.layout.aspectRatio != nil else{var layout=defaultLayout();layout.referenceAspect=aspectLabel(preview.sourceSize);return layout}
  return aspectAdjustment(defaultLayout(),settings.layout.aspectRatio,preview.sourceSize,osdFrames,cues,picture:preview.pictureRect).layout
 }
}
