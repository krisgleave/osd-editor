// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech)
import Cocoa
import AVFoundation
import CoreImage
import UniformTypeIdentifiers
import QuartzCore

let fieldNames = ["Signal", "CH", "FlightTime", "SBat", "GBat", "Bitrate", "Distance", "STYMode"]
let labels = ["Signal", "Channel", "Flight time", "SBat", "GBat", "Bitrate", "Distance", "STYMode"]
struct Cue { var start:Double; var end:Double; var values:[String:String] }
func seconds(_ t:String)->Double {
 let p=t.replacingOccurrences(of:",",with:".").split(separator:":").compactMap{Double($0)}
 return p.count == 3 ? p[0]*3600+p[1]*60+p[2]:0
}
func parseSRT(_ text:String)->[Cue] {
 let normalized=text.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n")
 let expression=try! NSRegularExpression(pattern:#"\b([A-Za-z][A-Za-z0-9]*):\s*([^\s]+)"#)
 return normalized.components(separatedBy:"\n\n").compactMap { block in
  let lines=block.components(separatedBy:.newlines)
  guard let timeIndex=lines.firstIndex(where:{$0.contains("-->")}) else{return nil}
  let parts=lines[timeIndex].components(separatedBy:"-->").map{$0.trimmingCharacters(in:.whitespaces)}
  guard parts.count==2 else{return nil}
  let body=lines.dropFirst(timeIndex+1).joined(separator:" ");let ns=body as NSString
  var values=[String:String]()
  for m in expression.matches(in:body,range:NSRange(location:0,length:ns.length)) {values[ns.substring(with:m.range(at:1))]=ns.substring(with:m.range(at:2))}
  guard !values.isEmpty else{return nil}
  return Cue(start:seconds(parts[0]),end:seconds(parts[1]),values:values)
 }.sorted{$0.start < $1.start}
}
func valuesAt(_ time:Double,_ cues:[Cue])->[String:String] {
 var low=0;var high=cues.count
 while low<high {let mid=(low+high)/2;if cues[mid].start<=time {low=mid+1}else{high=mid}}
 guard low>0 else{return [:]};let c=cues[low-1]
 return time<=c.end+0.002 ? c.values:[:]
}
struct Widget:Codable {
 var field:String;var enabled=true;var x:Double;var y:Double;var size:Double=28
 var fontName:String?;var red:Double=1;var green:Double=1;var blue:Double=1
 var colour:NSColor {NSColor(srgbRed:red,green:green,blue:blue,alpha:1)}
 var label:String {labels[fieldNames.firstIndex(of:field) ?? 0]}
 func text(_ values:[String:String])->String {"\(label): \(values[field] ?? "—")"}
}
func initialWidgets()->[Widget] {fieldNames.enumerated().map{Widget(field:$0.element,x:0.025+Double($0.offset%4)*0.245,y:0.84+Double($0.offset/4)*0.07)}}
struct Layout:Codable {var centreGuides:Bool?;var visuals:[TelemetryVisual]?;var batterySource:String?;var batteryCells:Int?;var batteryRed:Double?;var batteryGreen:Double?;var bitrateRed:Double?;var bitrateGreen:Double?;var widgets=initialWidgets();var line=Widget(field:"line",x:0.12,y:0.96,size:25);var regions=[Region]();var centred:Bool?;var lineAlignment:String?;var cells:[String:CellStyle]?;var outlines:Bool?;var telemetryHidden:Bool?;var presetTitle:String?;var referenceAspect:String?;var aspectRatio:String?;var outputSize:String?;var codec="H.264";var theme="Dark";var gridEnabled:Bool?;var gridColumns:Int?;var osdFontID:String?}
struct Settings:Codable {var layout=Layout();var presets:[String:Layout]=[:];var startup="Default";var fontPath:String?;var fonts:[LibraryFont]?;var legacyOSDFontID:String?}
func textAttributes(_ w:Widget,_ height:CGFloat)->[NSAttributedString.Key:Any] {
 let scale=height/1080;let shadow=NSShadow();shadow.shadowColor=NSColor.black;shadow.shadowBlurRadius=2*scale;shadow.shadowOffset=NSSize(width:scale,height:-scale)
 return [.font:libraryTextFont(w.fontName,max(1,w.size*scale)),.foregroundColor:w.colour,.strokeColor:NSColor.black,.strokeWidth:-3,.shadow:shadow]
}

func telemetryLine(_ values:[String:String],_ widgets:[Widget])->String {
 let order=["FlightTime","SBat","GBat","Signal","CH","Bitrate","Distance","STYMode"]
 return widgets.sorted{order.firstIndex(of:$0.field)! < order.firstIndex(of:$1.field)!}.filter{$0.enabled && values[$0.field] != nil}.map{w in
 let v=values[w.field]!
 switch w.field {
 case "FlightTime":let t=Int(v) ?? 0;return String(format:"Time:%d:%02d",t/60,t%60)
 case "SBat","GBat":return "\(w.field):\(v)V"
 default:return "\(w.field):\(v)"
 }
 }.joined(separator:"  ")
}
func migrateLayout(_ layout:inout Layout){
 guard layout.cells == nil else{return}
 var cells=[String:CellStyle]()
 for region in layout.regions{for row in region.row..<region.row+region.rows{for col in region.col..<region.col+region.columns{
  let id=row*53+col;if cells[String(id)] == nil{cells[String(id)]=CellStyle(dx:region.dx,dy:region.dy,hidden:region.hidden)}
 }}}
 layout.cells=cells;layout.regions=[]
}
func effectiveAlignment(_ layout:Layout)->String{layout.lineAlignment ?? (layout.centred == true ? "Centre":"Custom")}
func lineX(_ layout:Layout,_ text:String,_ width:CGFloat,_ height:CGFloat)->CGFloat {
 let textWidth=(text as NSString).size(withAttributes:textAttributes(layout.line,height)).width
 switch effectiveAlignment(layout) {
 case "Left":return width*0.02
 case "Centre":return max(0,(width-textWidth)/2)
 case "Right":return max(0,width*0.98-textWidth)
 default:return layout.line.x*width
 }
}
func parseExportTime(_ text:String)->Double?{
 let parts=text.trimmingCharacters(in:.whitespacesAndNewlines).split(separator:":",omittingEmptySubsequences:false)
 guard (1...3).contains(parts.count) else{return nil}
 let values=parts.compactMap{Double($0)}
 guard values.count==parts.count,values.allSatisfy({$0.isFinite && $0>=0}),values.dropFirst().allSatisfy({$0<60}) else{return nil}
 return values.reduce(0){$0*60+$1}
}
func boxedSection(_ title:String,_ content:NSView,collapsed:Bool=false)->NSBox{CompactSection(title,content,collapsed)}
final class ExportProgress:NSProgressIndicator{
 override var doubleValue:Double{didSet{needsDisplay=true}}
 override func draw(_ dirtyRect:NSRect){let r=bounds.insetBy(dx:0,dy:4);NSColor.controlBackgroundColor.setFill();NSBezierPath(roundedRect:r,xRadius:4,yRadius:4).fill();var fill=r;fill.size.width *= max(0,min(1,doubleValue/100));NSColor.systemBlue.setFill();NSBezierPath(roundedRect:fill,xRadius:4,yRadius:4).fill()}
}
final class StatusField:NSTextField{
 override var stringValue:String{didSet{isHidden=stringValue.isEmpty}}
}
final class FlippedView:NSView {override var isFlipped:Bool{true}}
final class Preview:NSView {
 var selectedVisuals=Set<Int>();var visualDragStarts=[Int:CGPoint]();var visualDragBounds=CGRect.zero;var visualDragOrigin=CGPoint.zero;var allVisualsSelected=false;var selectedVisual:Int?;var visualCues=[Cue]();var visualTime=0.0;var draggingVisual:Int?;var onVisualMove:((Int,Double,Double)->Void)?

 var telemetrySelected=false;var draggingTelemetry=false;var onTargetSelect:((Bool)->Void)?
 var layout=Layout();var osdImage:NSImage?;var mode=0;var selectionStart:NSPoint?;var selectionEnd:NSPoint?
 var selectedCells=Set<Int>();var availableCells=Set<Int>();var visibleCells=Set<Int>()
 var elementGroups=[Set<Int>]()
 var outlines:[Set<Int>]{let groups=elementGroups.isEmpty ? detectedGroups(availableCells.isEmpty ? visibleCells:availableCells,[:],includeHidden:true):elementGroups;return groups.filter{!$0.isDisjoint(with:visibleCells)}}
 func lineRect()->NSRect{let r=videoRect;let text=telemetryLine(values,layout.widgets);let size=(text as NSString).size(withAttributes:textAttributes(layout.line,r.height));return NSRect(x:r.minX+lineX(layout,text,r.width,r.height),y:r.minY+layout.line.y*r.height,width:size.width,height:size.height)}
 func displayBox(_ ids:Set<Int>)->NSRect{let b=cellBounds(ids,layout.cells ?? [:]);let r=videoRect;return NSRect(x:r.minX+b.minX*r.width,y:r.minY+b.minY*r.height,width:b.width*r.width,height:b.height*r.height)}
 var onEditBegin:(()->Void)?;var editStarted=false
 var onSelection:((Set<Int>)->Void)?;var onCellMove:((Double,Double)->Void)?;var onSelectionFinish:(()->Void)?
 func selectionRect()->NSRect{
  let b=cellBounds(selectedCells,layout.cells ?? [:]);let r=videoRect
  return b.isNull ? .zero:NSRect(x:r.minX+b.minX*r.width,y:r.minY+b.minY*r.height,width:b.width*r.width,height:b.height*r.height)
 }

 var frameImage:NSImage?;var widgets=initialWidgets();var values=[String:String]();var selected=0
 var onSelect:((Int)->Void)?;var onMove:((Int,Double,Double)->Void)?
 var dragging=false;var movedDuringGesture=false
 var dragStartBounds=CGRect.zero;var dragOrigin=NSPoint.zero;var appliedDrag=CGPoint.zero
 func beginOSDDrag(_ point:NSPoint){dragging=true;dragOffset=point;dragOrigin=point;appliedDrag = .zero;dragStartBounds=cellBounds(selectedCells,layout.cells ?? [:])}
 var pictureRect:CGRect?;var sourceSize=NSSize(width:1920,height:1080);var dragOffset=NSPoint.zero
 override var isFlipped:Bool {true}
 override var acceptsFirstResponder:Bool {true}
 var canvasSize:CGSize{centreCrop(sourceSize,layout.aspectRatio,picture:pictureRect).size}
 var videoRect:NSRect {let scale=min(bounds.width/canvasSize.width,bounds.height/canvasSize.height);let s=NSSize(width:canvasSize.width*scale,height:canvasSize.height*scale);return NSRect(x:(bounds.width-s.width)/2,y:(bounds.height-s.height)/2,width:s.width,height:s.height)}
 override func draw(_ dirtyRect:NSRect) {
  NSColor(calibratedWhite:0.065,alpha:1).setFill();bounds.fill()
  let r=videoRect
  NSGraphicsContext.current?.cgContext.saveGState();NSGraphicsContext.current?.cgContext.clip(to:r)
  if let img=frameImage {let crop=centreCrop(sourceSize,layout.aspectRatio,picture:pictureRect);let full=NSRect(x:r.minX-crop.minX/crop.width*r.width,y:r.minY-crop.minY/crop.height*r.height,width:sourceSize.width/crop.width*r.width,height:sourceSize.height/crop.height*r.height);img.draw(in:full,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)}
  else {let text="Open a video to preview its telemetry";let a:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:16),.foregroundColor:NSColor.lightGray];(text as NSString).draw(at:NSPoint(x:r.minX+25,y:r.midY),withAttributes:a)}

  if layout.gridEnabled == true{
   let step=r.width/CGFloat(layout.gridColumns ?? 32);let path=NSBezierPath()
   for x in stride(from:r.minX,through:r.maxX,by:step){path.move(to:NSPoint(x:x,y:r.minY));path.line(to:NSPoint(x:x,y:r.maxY))}
   for y in stride(from:r.minY,through:r.maxY,by:step){path.move(to:NSPoint(x:r.minX,y:y));path.line(to:NSPoint(x:r.maxX,y:y))}
   NSColor.white.withAlphaComponent(0.18).setStroke();path.lineWidth=0.5;path.stroke()
  }
  osdImage?.draw(in:r,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
  let line=telemetryLine(values,layout.widgets) as NSString
  if layout.telemetryHidden == true{NSGraphicsContext.current?.cgContext.setAlpha(0.25)}
  line.draw(at:NSPoint(x:r.minX+lineX(layout,line as String,r.width,r.height),y:r.minY+layout.line.y*r.height),withAttributes:textAttributes(layout.line,r.height))
  NSGraphicsContext.current?.cgContext.setAlpha(1)
  if telemetrySelected {NSColor.systemCyan.setStroke();NSBezierPath(rect:NSRect(x:r.minX+lineX(layout,line as String,r.width,r.height),y:r.minY+layout.line.y*r.height,width:line.size(withAttributes:textAttributes(layout.line,r.height)).width,height:line.size(withAttributes:textAttributes(layout.line,r.height)).height).insetBy(dx:-3,dy:-3)).stroke()}
  drawVisuals(layout,values,visualCues,visualTime,r,preview:true)
  for i in (layout.visuals ?? []).indices where (allVisualsSelected || selectedVisual==i || selectedVisuals.contains(i)) && layout.visuals![i].enabled{let visuals=layout.visuals!;let box=visualRect(visuals[i],r);NSColor.systemBlue.withAlphaComponent(0.18).setFill();NSBezierPath(rect:box).fill();NSColor.systemCyan.setStroke();let path=NSBezierPath(rect:box);path.lineWidth=2.5;path.stroke()}
  if layout.centreGuides == true{
   let guides=NSBezierPath();guides.move(to:CGPoint(x:r.midX,y:r.minY));guides.line(to:CGPoint(x:r.midX,y:r.maxY));guides.move(to:CGPoint(x:r.minX,y:r.midY));guides.line(to:CGPoint(x:r.maxX,y:r.midY));guides.lineWidth=1.25;NSColor.systemYellow.withAlphaComponent(0.9).setStroke();guides.stroke()
  }
  if !selectedCells.isEmpty{let box=selectionRect();NSColor.systemBlue.withAlphaComponent(0.18).setFill();NSBezierPath(rect:box).fill();NSColor.systemCyan.setStroke();let border=NSBezierPath(rect:box);border.lineWidth=2.5;border.stroke();for p in [NSPoint(x:box.minX,y:box.minY),NSPoint(x:box.maxX,y:box.minY),NSPoint(x:box.minX,y:box.maxY),NSPoint(x:box.maxX,y:box.maxY)]{NSColor.white.setFill();NSBezierPath(rect:NSRect(x:p.x-3,y:p.y-3,width:6,height:6)).fill()}}
  NSGraphicsContext.current?.cgContext.restoreGState()
  if let a=selectionStart,let b=selectionEnd{NSColor.systemOrange.setStroke();NSBezierPath(rect:NSRect(x:min(a.x,b.x),y:min(a.y,b.y),width:abs(a.x-b.x),height:abs(a.y-b.y))).stroke()}
 }
 override func mouseDown(with event:NSEvent) {
  let p=convert(event.locationInWindow,from:nil);guard videoRect.contains(p) else{return};dragging=false;movedDuringGesture=false;editStarted=false;draggingTelemetry=false
  draggingVisual=nil
  let visuals=layout.visuals ?? defaultVisuals()
  let existing=Set(visuals.indices.filter{visuals[$0].enabled && (allVisualsSelected || selectedVisual==$0 || selectedVisuals.contains($0))})
  if let i=visuals.indices.reversed().first(where:{visuals[$0].enabled && visualRect(visuals[$0],videoRect).contains(p)}){
   selectedVisuals=existing.contains(i) ? existing:[i];selectedVisual=selectedVisuals.count==1 ? i:nil;allVisualsSelected=false;telemetrySelected=false;selectedCells=[]
   visualDragStarts=Dictionary(uniqueKeysWithValues:selectedVisuals.map{($0,CGPoint(x:visuals[$0].x,y:visuals[$0].y))});visualDragBounds=selectedVisuals.reduce(CGRect.null){$0.union(visualRect(visuals[$1],videoRect))};visualDragOrigin=p
   onTargetSelect?(false);needsDisplay=true;draggingVisual=i;dragging=true;dragOffset=p;return
  }
  selectedVisual=nil;selectedVisuals=[];allVisualsSelected=false
  if !telemetryLine(values,layout.widgets).isEmpty && lineRect().insetBy(dx:-4,dy:-3).contains(p){telemetrySelected=true;selectedCells=[];onTargetSelect?(true);draggingTelemetry=true;dragging=true;dragOffset=NSPoint(x:p.x-videoRect.minX-lineX(layout,telemetryLine(values,layout.widgets),videoRect.width,videoRect.height),y:p.y-videoRect.minY-layout.line.y*videoRect.height);return}
  telemetrySelected=false;onTargetSelect?(false)
  if !selectedCells.isEmpty && selectedCells.contains(where:{displayBox([$0]).contains(p)}){beginOSDDrag(p);return}
  if let group=outlines.first(where:{displayBox($0).contains(p)}){
   selectedCells=group;onSelection?(selectedCells);beginOSDDrag(p);needsDisplay=true;return
  }
  selectedCells=[];onSelection?([]);selectionStart=p;selectionEnd=p;needsDisplay=true
 }
 override func mouseUp(with event:NSEvent){
  let wasDragging=dragging;dragging=false
  if let a=selectionStart,let b=selectionEnd{
   let r=videoRect
   let box=CGRect(x:(min(a.x,b.x)-r.minX)/r.width,y:(min(a.y,b.y)-r.minY)/r.height,width:abs(a.x-b.x)/r.width,height:abs(a.y-b.y)/r.height)
   if abs(a.x-b.x)>3 && abs(a.y-b.y)>3{
    selectedCells=outlines.filter{group in cellBounds(group,layout.cells ?? [:]).intersects(box)}.reduce(into:Set<Int>()){$0.formUnion($1)}
    let canvas=CGRect(origin:.zero,size:videoRect.size);let selection=CGRect(x:box.minX*canvas.width,y:box.minY*canvas.height,width:box.width*canvas.width,height:box.height*canvas.height)
    let visuals=layout.visuals ?? [];selectedVisuals=Set(visuals.indices.filter{visuals[$0].enabled && visualRect(visuals[$0],canvas).intersects(selection)})
    if !selectedVisuals.isEmpty{selectedCells=[];telemetrySelected=false;selectedVisual=selectedVisuals.count==1 ? selectedVisuals.first:nil;onTargetSelect?(false)}else{onSelection?(selectedCells)}
   }else if layout.outlines != false,let group=outlines.first(where:{displayBox($0).contains(a)}){
    selectedCells=group;onSelection?(selectedCells)
   }
  }
  selectionStart=nil;selectionEnd=nil
  if wasDragging && movedDuringGesture{onSelectionFinish?()}
  needsDisplay=true
 }

 override func mouseDragged(with event:NSEvent){
  let p=convert(event.locationInWindow,from:nil);let r=videoRect
  if selectionStart != nil{selectionEnd=NSPoint(x:max(r.minX,min(r.maxX,p.x)),y:max(r.minY,min(r.maxY,p.y)));needsDisplay=true;return}
  guard dragging else{return}
  if !editStarted{onEditBegin?();editStarted=true};if hypot(p.x-dragOffset.x,p.y-dragOffset.y)>1{movedDuringGesture=true}
  if draggingVisual != nil{
   var origin=CGPoint(x:visualDragBounds.minX+(p.x-visualDragOrigin.x),y:visualDragBounds.minY+(p.y-visualDragOrigin.y))
   if layout.gridEnabled == true{let normalized=snappedOrigin(CGPoint(x:(origin.x-r.minX)/r.width,y:(origin.y-r.minY)/r.height),layout.gridColumns ?? 32,canvasSize.width/canvasSize.height);origin=CGPoint(x:r.minX+normalized.x*r.width,y:r.minY+normalized.y*r.height)}
   origin.x=max(r.minX,min(r.maxX-visualDragBounds.width,origin.x));origin.y=max(r.minY,min(r.maxY-visualDragBounds.height,origin.y))
   let dx=(origin.x-visualDragBounds.minX)/r.width,dy=(origin.y-visualDragBounds.minY)/r.height
   for (i,start) in visualDragStarts{onVisualMove?(i,start.x+dx,start.y+dy)};needsDisplay=true;return
  }

  if draggingTelemetry{var point=CGPoint(x:max(0,min(0.98,(p.x-dragOffset.x-r.minX)/r.width)),y:max(0,min(0.98,(p.y-dragOffset.y-r.minY)/r.height)));if layout.gridEnabled == true{point=snappedOrigin(point,layout.gridColumns ?? 32,canvasSize.width/canvasSize.height)};let x=point.x,y=point.y;layout.line.x=x;layout.line.y=y;onMove?(0,x,y)}
  else if !selectedCells.isEmpty{
   var target=CGPoint(x:dragStartBounds.minX+(p.x-dragOrigin.x)/r.width,y:dragStartBounds.minY+(p.y-dragOrigin.y)/r.height)
   if layout.gridEnabled == true{target=snappedOrigin(target,layout.gridColumns ?? 32,canvasSize.width/canvasSize.height)}
   let total=CGPoint(x:target.x-dragStartBounds.minX,y:target.y-dragStartBounds.minY)
   onCellMove?(total.x-appliedDrag.x,total.y-appliedDrag.y);appliedDrag=total
  };needsDisplay=true
 }

}
final class TextCache {
 let lock=NSLock();var images=[String:CIImage]()
 func image(_ widget:Widget,_ text:String,_ height:CGFloat)->CIImage {
  let key="\(widget.fontName ?? "builtin:mono")|\(widget.field)|\(text)|\(widget.size)|\(widget.red)|\(widget.green)|\(widget.blue)|\(height)"
  lock.lock();defer{lock.unlock()};if let image=images[key]{return image}
  let attrs=textAttributes(widget,height);let string=text as NSString;let measured=string.size(withAttributes:attrs);let pad=max(3,height/360)
  let size=NSSize(width:ceil(measured.width)+pad*2,height:ceil(measured.height)+pad*2)
  let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:max(1,Int(size.width)),pixelsHigh:max(1,Int(size.height)),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
  string.draw(at:NSPoint(x:pad,y:pad),withAttributes:attrs);NSGraphicsContext.restoreGraphicsState()
  let image=CIImage(cgImage:rep.cgImage!)
  if images.count>500 {images.removeAll(keepingCapacity:true)};images[key]=image;return image
 }
}
final class App:NSObject,NSApplicationDelegate,NSWindowDelegate {
 var customTextCheck:NSButton?;var customTextEntry:NSTextField?;var visualChecks=[NSButton]();var visualSliders=[NSSlider]();var visualThresholds=[NSTextField]();var batteryVisualSource:NSPopUpButton?;var batteryVisualCells:NSPopUpButton?
 let aspectPopup=NSPopUpButton();let outputSize=NSPopUpButton();let mediaInfo=NSTextField(labelWithString:"");let srtInfo=NSTextField(labelWithString:"");let statusSummary=NSTextField(labelWithString:"");let batchOpen=NSButton(title:"Open batch…",target:nil,action:nil);let batchPicker=NSPopUpButton();let batchLabel=NSTextField(labelWithString:"Single video");var batchSources=[URL]();var batchRunning=false;var batchCancelled=false;var batchIndex=0;var batchResults=[String]();var batchDestination:URL?;var batchPresetName="Default";var batchLayout:Layout?;var batchRenderer:OSDRenderer?
 let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1220,height:840),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
 let preview=Preview();let status=StatusField(wrappingLabelWithString:"")
 let scrub=NSSlider(value:0,minValue:0,maxValue:1,target:nil,action:nil);let timeLabel=NSTextField(labelWithString:"00:00:00 / 00:00:00")
 let undoMoveButton=NSButton(title:"Undo",target:nil,action:nil);var undoCells:[String:CellStyle]?;var undoLayout:Layout?;var redoLayout:Layout?;var undoPresetName:String?;var redoPresetName:String?;let redoButton=NSButton()
 let selectionChooser=NSSegmentedControl(labels:["None","All OSD","Telemetry","VIS"],trackingMode:.selectOne,target:nil,action:nil);let presetRenameButton=NSButton(title:"Rename…",target:nil,action:nil);let presetDeleteButton=NSButton(title:"Delete",target:nil,action:nil);var trimButtons=[NSButton]()
 let fullScreenButton=NSButton(title:"Full screen",target:nil,action:nil);let alignReference=NSPopUpButton();let presetManage=NSPopUpButton(frame:.zero,pullsDown:true);var activePresetName="Default"
 let timelineView=TrimTimeline();let playButton=NSButton(title:"Play",target:nil,action:nil);let videoName=NSTextField(labelWithString:"Video: —");let srtName=NSTextField(labelWithString:"SRT: —")
 let makeDefaultButton=NSButton(title:"Make Default",target:nil,action:nil);let presetSaveButton=NSButton(title:"Save",target:nil,action:nil);let presetState=NSTextField(labelWithString:"");var telemetryBaseSize=25.0
 var player:AVPlayer?;var playerOutput:AVPlayerItemVideoOutput?;var playbackTimer:Timer?;let playbackContext=CIContext();var isPlaying=false;var playbackFrames=0
 let startField=NSTextField(string:"00:00:00");let endField=NSTextField(string:"00:00:00");let rangeLabel=NSTextField(labelWithString:"")
 let verticalAlign=NSSegmentedControl(labels:["Top","Middle","Bottom"],trackingMode:.selectOne,target:nil,action:nil)
 let gridToggle=NSButton(checkboxWithTitle:"Grid & snap",target:nil,action:nil);let gridSize=NSPopUpButton()
 let osdFontPopup=NSPopUpButton();let textFontPopup=NSPopUpButton();let osdFontMenu=NSPopUpButton(frame:.zero,pullsDown:true);let textFontMenu=NSPopUpButton(frame:.zero,pullsDown:true);let osdRename=NSButton(title:"Rename…",target:nil,action:nil);let osdDelete=NSButton(title:"Delete",target:nil,action:nil);let textRename=NSButton(title:"Rename…",target:nil,action:nil);let textDelete=NSButton(title:"Delete",target:nil,action:nil)
 var spaceMonitor:Any?;var exactIn=0.0;var exactOut=0.0
 let hideSelectionButton=NSButton(title:"Hide selection",target:nil,action:nil);let showOutlines=NSButton(checkboxWithTitle:"Show detected outlines",target:nil,action:nil);let osdScale=NSSlider(value:20,minValue:4,maxValue:50,target:nil,action:nil);let sizeValue=NSTextField(string:"20");let osdScaleLabel=NSTextField(labelWithString:"Size");let osdColour=NSColorWell();let selectionLabel=NSTextField(labelWithString:"Draw around OSD to select");var lastOSDScale=100.0
 let alignment=NSSegmentedControl(labels:["Left","Centre","Right"],trackingMode:.selectOne,target:nil,action:nil);let resetTint=NSButton(title:"Reset",target:nil,action:nil);let mode=NSPopUpButton();let regionPicker=NSPopUpButton();let hideRegion=NSButton(checkboxWithTitle:"Hide selected OSD region",target:nil,action:nil);let fontStatus=NSTextField(labelWithString:"OSD font: not imported");let field=NSPopUpButton();let size=NSSlider(value:28,minValue:12,maxValue:80,target:nil,action:nil);let xSlider=NSSlider(value:0,minValue:0,maxValue:98,target:nil,action:nil);let ySlider=NSSlider(value:0,minValue:0,maxValue:98,target:nil,action:nil)
 let sizeLabel=NSTextField(labelWithString:"");let xLabel=NSTextField(labelWithString:"");let yLabel=NSTextField(labelWithString:"");let colour=NSColorWell()
 let theme=NSPopUpButton();let codec=NSPopUpButton();let preset=NSPopUpButton();let startup=NSPopUpButton();var checks=[NSButton]()
 let open=NSButton(title:"Open video…",target:nil,action:nil);let match=NSButton(title:"Choose SRT…",target:nil,action:nil);let export=NSButton(title:"Export video…",target:nil,action:nil);let cancel=NSButton(title:"Cancel export",target:nil,action:nil)
 let exportPercent=NSTextField(labelWithString:"");let pauseButton=NSButton();let stopButton=NSButton();let bar=ExportProgress();var settings=Settings();var url:URL?;var asset:AVURLAsset?;var cues=[Cue]();var duration=0.0;var generator:AVAssetImageGenerator?;var imageQueue=DispatchQueue(label:"p1.preview",qos:.userInitiated);var previewGeneration=0
 var osdFrames=[OSDFrame]();var osdRenderer:OSDRenderer?;var loadingOSD=false;var loadToken=0
 var session:AVAssetExportSession?;var progressTimer:Timer?;var lastSRT:URL?;var outputTemp:URL?;var settingsURL:URL!
 func applicationDidFinishLaunching(_ n:Notification) {
  guard settingsURL == nil else { return }
  NSApp.setActivationPolicy(.regular)
  window.delegate=self
  let support=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
  let current=support.appendingPathComponent("OSD Editor"),legacy=support.appendingPathComponent("P1 OSD Studio")
  let isolated=CommandLine.arguments.contains(where:{$0.hasSuffix("-test")}) || CommandLine.arguments.contains("--ui-review")
  let dir=isolated ? FileManager.default.temporaryDirectory.appendingPathComponent("OSD-Editor-test-"+UUID().uuidString):current
  try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
  let live=FileManager.default.fileExists(atPath:current.appendingPathComponent("settings-v09.json").path) ? current:legacy
  if CommandLine.arguments.contains("--ui-review") || (!isolated && !FileManager.default.fileExists(atPath:current.appendingPathComponent("settings-v09.json").path)){
   do{for name in ["Fonts","settings-v09.json","settings-v08.json","settings-v02.json"]{let original=live.appendingPathComponent(name),destination=dir.appendingPathComponent(name);if FileManager.default.fileExists(atPath:original.path) && !FileManager.default.fileExists(atPath:destination.path){try FileManager.default.copyItem(at:original,to:destination)}}}catch{let alert=NSAlert();alert.messageText="Couldn’t copy your existing library";alert.informativeText="Your P1 OSD Studio files are unchanged. Close the app and try again. "+error.localizedDescription;alert.runModal();NSApp.terminate(nil);return}
  }
  settingsURL=dir.appendingPathComponent("settings-v09.json")
  let earlier=dir.appendingPathComponent("settings-v08.json")
  let readSettingsURL=FileManager.default.fileExists(atPath:settingsURL.path) ? settingsURL!:(FileManager.default.fileExists(atPath:earlier.path) ? earlier:dir.appendingPathComponent("settings-v02.json"))
  if let data=try? Data(contentsOf:readSettingsURL),let saved=try? JSONDecoder().decode(Settings.self,from:data),saved.layout.widgets.count==8 {settings=saved}
  migrateLayout(&settings.layout);bootstrapFontLibrary();migratePresetIdentities();applyStartupLayout()
  let menu=NSMenu();let top=NSMenuItem();menu.addItem(top);let appMenu=NSMenu();appMenu.addItem(withTitle:"About OSD Editor",action:#selector(about),keyEquivalent:"");appMenu.addItem(.separator());appMenu.addItem(withTitle:"Quit OSD Editor",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");top.submenu=appMenu;NSApp.mainMenu=menu
  window.title="OSD Editor v1.0 — by KrisTalksTech";window.minSize=NSSize(width:1220,height:740);window.collectionBehavior.insert(.fullScreenPrimary);window.center()
  let root=NSStackView();root.orientation = .vertical;root.distribution = .fill;root.alignment = .leading;root.spacing=10;root.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(root)
  NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),root.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),root.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:18),root.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-18)])
  let toolbar=NSStackView();toolbar.spacing=10
  open.target=self;open.action=#selector(openVideo);match.target=self;match.action=#selector(chooseSRT);theme.addItems(withTitles:["System","Light","Dark"]);theme.target=self;theme.action=#selector(changeTheme)
  undoMoveButton.target=self;undoMoveButton.action=#selector(undoMove);undoMoveButton.isEnabled=false;let flex=NSView();toolbar.addArrangedSubview(flex)
  let appearanceControls=NSStackView();appearanceControls.orientation = .vertical;appearanceControls.alignment = .trailing;appearanceControls.spacing=8;let appearanceRow=NSStackView();appearanceRow.spacing=8;appearanceRow.addArrangedSubview(NSTextField(labelWithString:"Appearance"));appearanceRow.addArrangedSubview(theme);appearanceControls.addArrangedSubview(appearanceRow);fullScreenButton.target=self;fullScreenButton.action=#selector(maximise);appearanceControls.addArrangedSubview(fullScreenButton);toolbar.addArrangedSubview(appearanceControls);root.addArrangedSubview(toolbar);toolbar.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true

  let body=NSView();body.translatesAutoresizingMaskIntoConstraints=false
  let left=NSStackView();left.orientation = .vertical;left.distribution = .fill;left.alignment = .leading;left.spacing=6;left.translatesAutoresizingMaskIntoConstraints=false
  preview.translatesAutoresizingMaskIntoConstraints=false;preview.heightAnchor.constraint(greaterThanOrEqualToConstant:280).isActive=true
  let files=NSStackView();files.orientation = .vertical;files.alignment = .leading;files.spacing=8
  for (button,label,info) in [(open,videoName,mediaInfo),(match,srtName,srtInfo)]{
   let row=NSStackView();row.spacing=12;button.widthAnchor.constraint(equalToConstant:112).isActive=true;row.addArrangedSubview(button);label.font = .monospacedSystemFont(ofSize:11,weight:.regular);label.lineBreakMode = .byTruncatingMiddle;label.widthAnchor.constraint(equalToConstant:205).isActive=true;row.addArrangedSubview(label);info.font = .systemFont(ofSize:11);info.textColor = .secondaryLabelColor;info.lineBreakMode = .byTruncatingTail;info.widthAnchor.constraint(equalToConstant:330).isActive=true;row.addArrangedSubview(info)
   if button===open{batchOpen.target=self;batchOpen.action=#selector(openBatch);row.addArrangedSubview(batchOpen)};files.addArrangedSubview(row)
  };toolbar.insertArrangedSubview(toolPanel(files),at:0)
  left.addArrangedSubview(preview);preview.widthAnchor.constraint(equalTo:left.widthAnchor).isActive=true
  timelineView.toolTip="Drag IN or OUT to trim; click between them to seek.";timelineView.heightAnchor.constraint(equalToConstant:44).isActive=true;left.addArrangedSubview(timelineView);timelineView.widthAnchor.constraint(equalTo:left.widthAnchor).isActive=true
  timelineView.onSeek = {[weak self] t in self?.pausePlayback();self?.scrub.doubleValue=t;self?.requestPreview()}
  timelineView.onRange = {[weak self] a,b in self?.exactIn=a;self?.exactOut=b;self?.startField.stringValue=self?.rangeTime(a) ?? "";self?.endField.stringValue=self?.rangeTime(b) ?? "";self?.rangeEdited()}
  let transport=NSStackView();transport.spacing=10;configureIcon(playButton,"play.fill","Play (Space)");playButton.target=self;playButton.action=#selector(togglePlayback);transport.addArrangedSubview(playButton);configureIcon(pauseButton,"pause.fill","Pause");pauseButton.target=self;pauseButton.action=#selector(pauseMedia);configureIcon(stopButton,"stop.fill","Stop and return to In point");stopButton.target=self;stopButton.action=#selector(stopMedia);transport.addArrangedSubview(stopButton)
  for (title,action) in [("Set In",#selector(setStartHere)),("Set Out",#selector(setEndHere)),("Full video",#selector(fullVideo))]{let b=NSButton(title:title,target:self,action:action);configureIcon(b,title=="Set In" ? "backward.end":(title=="Set Out" ? "forward.end":"arrow.left.and.right"),title=="Full video" ? "Use full video range":title);if title=="Set In" || title=="Set Out"{b.image=trimMarkIcon(title=="Set In")};trimButtons.append(b);transport.addArrangedSubview(b)}
  let transportSpace=NSView();transport.addArrangedSubview(transportSpace);timeLabel.font = .monospacedDigitSystemFont(ofSize:11,weight:.regular);transport.addArrangedSubview(timeLabel);left.addArrangedSubview(transport);transport.widthAnchor.constraint(equalTo:left.widthAnchor).isActive=true
  preview.setContentHuggingPriority(.defaultLow,for:.vertical)
  body.addSubview(left);let inspectorStack=NSStackView();inspectorStack.orientation = .vertical;inspectorStack.alignment = .leading;inspectorStack.spacing=8
  let right=NSStackView();right.orientation = .vertical;right.alignment = .leading;right.spacing=10;right.widthAnchor.constraint(equalToConstant:312).isActive=true

  selectionChooser.target=self;selectionChooser.action=#selector(selectionChoiceChanged);selectionChooser.segmentStyle = .rounded
  for (i,label) in ["None","OSD","TELEM","VIS"].enumerated(){selectionChooser.setLabel(label,forSegment:i);selectionChooser.setImage(nil,forSegment:i);selectionChooser.setWidth(60,forSegment:i)}

  selectionChooser.setAccessibilityLabel("Selection target");right.addArrangedSubview(selectionChooser)
  let sizeRow=NSStackView();sizeRow.spacing=8;osdScaleLabel.font = .systemFont(ofSize:12);osdScaleLabel.widthAnchor.constraint(equalToConstant:32).isActive=true;sizeRow.addArrangedSubview(osdScaleLabel);osdScale.target=self;osdScale.action=#selector(scaleOSD);osdScale.isContinuous=true;osdScale.widthAnchor.constraint(equalToConstant:90).isActive=true;sizeValue.widthAnchor.constraint(equalToConstant:40).isActive=true;sizeValue.target=self;sizeValue.action=#selector(sizeEntered);sizeRow.addArrangedSubview(sizeValue);sizeRow.addArrangedSubview(osdScale);right.addArrangedSubview(sizeRow)
  let alignRow=NSStackView();alignRow.spacing=8
  alignment.target=self;alignment.action=#selector(alignmentChanged);alignment.setAccessibilityLabel("Horizontal alignment")
  verticalAlign.target=self;verticalAlign.action=#selector(verticalAlignmentChanged);verticalAlign.setAccessibilityLabel("Vertical alignment")
  for (control,symbols,names) in [(alignment,["align.horizontal.left","align.horizontal.center","align.horizontal.right"],["Align left","Align centre","Align right"]),(verticalAlign,["align.vertical.top","align.vertical.center","align.vertical.bottom"],["Align top","Align middle","Align bottom"])]{
   for i in 0..<3{control.setLabel("",forSegment:i);control.setImage(NSImage(systemSymbolName:symbols[i],accessibilityDescription:names[i]),forSegment:i);control.setToolTip(names[i],forSegment:i);control.setWidth(24,forSegment:i)}
   alignRow.addArrangedSubview(control)
  };right.addArrangedSubview(alignRow)
  let referenceRow=NSStackView();referenceRow.spacing=12;alignReference.addItems(withTitles:["Frame","Selection"]);alignReference.selectItem(at:1);alignReference.widthAnchor.constraint(equalToConstant:100).isActive=true;referenceRow.addArrangedSubview(alignReference);right.addArrangedSubview(referenceRow)
  let colourRow=NSStackView();colourRow.spacing=12;osdColour.toolTip="Selection colour";osdColour.target=self;osdColour.action=#selector(tintOSD);colourRow.addArrangedSubview(osdColour);resetTint.target=self;resetTint.action=#selector(resetOSDTint);configureIcon(resetTint,"arrow.counterclockwise","Restore default colour");colourRow.addArrangedSubview(resetTint);right.addArrangedSubview(colourRow)
  let visibilityRow=NSStackView();visibilityRow.spacing=12;hideSelectionButton.target=self;hideSelectionButton.action=#selector(hideOSDSelection);hideSelectionButton.bezelStyle = .rounded;configureIcon(hideSelectionButton,"eye.slash","Hide selection");visibilityRow.addArrangedSubview(hideSelectionButton);right.addArrangedSubview(visibilityRow)
  let actionRow=NSStackView();actionRow.spacing=6;configureIcon(undoMoveButton,"arrow.uturn.backward","Undo");actionRow.addArrangedSubview(undoMoveButton);configureIcon(redoButton,"arrow.uturn.forward","Redo");redoButton.target=self;redoButton.action=#selector(redoMove);redoButton.isEnabled=false;actionRow.addArrangedSubview(redoButton)
  let reset=NSButton(title:"Reset layout",target:self,action:#selector(resetToDefault));configureIcon(reset,"arrow.counterclockwise.circle","Reset layout");actionRow.addArrangedSubview(reset)
  let displayRow=NSStackView();displayRow.spacing=10;gridToggle.title="";gridToggle.setButtonType(.pushOnPushOff);configureIcon(gridToggle,"square.grid.3x3","Snap grid");gridToggle.toolTip="Show square grid and snap moved items";gridToggle.target=self;gridToggle.action=#selector(gridChanged);displayRow.addArrangedSubview(gridToggle)
  gridSize.addItems(withTitles:["32","48","64","96"]);gridSize.target=self;gridSize.action=#selector(gridChanged);gridSize.widthAnchor.constraint(equalToConstant:64).isActive=true;displayRow.addArrangedSubview(gridSize);showOutlines.title="";showOutlines.setButtonType(.pushOnPushOff);configureIcon(showOutlines,"ruler","Centre guides");showOutlines.toolTip="Show yellow centre guides (preview only)";showOutlines.target=self;showOutlines.action=#selector(outlinesChanged);displayRow.addArrangedSubview(showOutlines);right.addArrangedSubview(displayRow)
  let tools=NSStackView();tools.orientation = .vertical;tools.alignment = .leading;tools.spacing=10
  func toolRow(_ groups:[NSView])->NSStackView{let row=NSStackView();row.spacing=8;for (i,group) in groups.enumerated(){if i>0{let divider=NSBox();divider.boxType = .separator;divider.widthAnchor.constraint(equalToConstant:1).isActive=true;divider.heightAnchor.constraint(equalToConstant:26).isActive=true;row.addArrangedSubview(divider)};group.setContentHuggingPriority(.required,for:.horizontal);group.setContentCompressionResistancePriority(.required,for:.horizontal);row.addArrangedSubview(group)};let space=NSView();space.setContentHuggingPriority(.defaultLow,for:.horizontal);row.addArrangedSubview(space);return row}
  for item in [selectionChooser,sizeRow,alignRow,referenceRow,colourRow,visibilityRow,displayRow]{right.removeArrangedSubview(item);item.removeFromSuperview()}
  tools.addArrangedSubview(toolRow([actionRow,selectionChooser,visibilityRow,sizeRow,colourRow,alignRow,referenceRow,displayRow]))
  let toolsPanel=toolPanel(tools);root.insertArrangedSubview(toolsPanel,at:1);toolsPanel.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true

  let queueControls=NSStackView();queueControls.orientation = .vertical;queueControls.alignment = .leading;queueControls.spacing=6;queueControls.widthAnchor.constraint(equalToConstant:312).isActive=true;batchLabel.font = .systemFont(ofSize:11);queueControls.addArrangedSubview(batchLabel);batchPicker.widthAnchor.constraint(equalToConstant:300).isActive=true;batchPicker.target=self;batchPicker.action=#selector(batchPreviewChanged);queueControls.addArrangedSubview(batchPicker);inspectorStack.addArrangedSubview(boxedSection("Videos",queueControls))
  let telemetryControls=NSStackView();telemetryControls.orientation = .vertical;telemetryControls.alignment = .leading;telemetryControls.spacing=8;telemetryControls.widthAnchor.constraint(equalToConstant:312).isActive=true
  let toggles=NSStackView();toggles.orientation = .vertical;toggles.spacing=4;toggles.distribution = .fillEqually
  for i in stride(from:0,to:labels.count,by:3){let row=NSStackView();row.distribution = .fillEqually;row.spacing=8
   for j in i..<min(i+3,labels.count){let check=NSButton(checkboxWithTitle:labels[j],target:self,action:#selector(toggle(_:)));check.font = .systemFont(ofSize:11);check.tag=j;checks.append(check);row.addArrangedSubview(check)}
   if row.arrangedSubviews.count<3{row.addArrangedSubview(NSView())}
   toggles.addArrangedSubview(row);row.widthAnchor.constraint(equalTo:toggles.widthAnchor).isActive=true
  }
  telemetryControls.addArrangedSubview(toggles);toggles.widthAnchor.constraint(equalTo:telemetryControls.widthAnchor).isActive=true;toggles.heightAnchor.constraint(equalToConstant:74).isActive=true
  inspectorStack.addArrangedSubview(boxedSection("Telemetry contents",telemetryControls))
  inspectorStack.addArrangedSubview(boxedSection("Telemetry visuals",buildVisualControls()))
  let fontControls=NSStackView();fontControls.orientation = .vertical;fontControls.alignment = .leading;fontControls.spacing=8;fontControls.widthAnchor.constraint(equalToConstant:312).isActive=true
  for (title,popup,kind,menu) in [("OSD",osdFontPopup,"osd",osdFontMenu),("Text",textFontPopup,"text",textFontMenu)]{
   let row=NSStackView();row.spacing=6;let label=NSTextField(labelWithString:title);label.widthAnchor.constraint(equalToConstant:33).isActive=true;row.addArrangedSubview(label)
   popup.target=self;popup.action=kind=="osd" ? #selector(osdFontChanged):#selector(textFontChanged);row.addArrangedSubview(popup);popup.widthAnchor.constraint(equalToConstant:220).isActive=true
   menu.addItem(withTitle:"");menu.item(at:0)?.image=NSImage(systemSymbolName:"ellipsis.circle",accessibilityDescription:title+" font actions");menu.widthAnchor.constraint(equalToConstant:39).isActive=true;menu.menu?.autoenablesItems=false
   for (name,action) in [("Import…",kind=="osd" ? #selector(importFont):#selector(importTextFont)),("Rename…",kind=="osd" ? #selector(renameOSDFont):#selector(renameTextFont)),("Delete",kind=="osd" ? #selector(deleteOSDFont):#selector(deleteTextFont))]{menu.addItem(withTitle:name);menu.lastItem?.target=self;menu.lastItem?.action=action}
   menu.toolTip=title+" font: import, rename or delete";row.addArrangedSubview(menu);fontControls.addArrangedSubview(row)
  }
  let fontHelp=NSButton(title:"Get OSD fonts…",target:self,action:#selector(openFontWebsite));fontHelp.toolTip="Open Sneaky FPV’s font website";fontControls.addArrangedSubview(fontHelp)
  inspectorStack.addArrangedSubview(boxedSection("Fonts",fontControls))
  let timeFields=NSStackView();timeFields.spacing=8
  for (label,field) in [("In",startField),("Out",endField)]{let name=NSTextField(labelWithString:label);name.font = .systemFont(ofSize:11);timeFields.addArrangedSubview(name);timeFields.addArrangedSubview(field);field.widthAnchor.constraint(equalToConstant:80).isActive=true;field.font = .monospacedDigitSystemFont(ofSize:11,weight:.regular);field.target=self;field.action=#selector(rangeEdited(_:))}
  rangeLabel.font = .systemFont(ofSize:11);rangeLabel.lineBreakMode = .byTruncatingTail;rangeLabel.setContentCompressionResistancePriority(.defaultLow,for:.horizontal);timeFields.addArrangedSubview(rangeLabel);transport.insertArrangedSubview(timeFields,at:5)
  let presetControls=NSStackView();presetControls.orientation = .vertical;presetControls.alignment = .leading;presetControls.spacing=8;presetControls.widthAnchor.constraint(equalToConstant:312).isActive=true
  preset.target=self;preset.action=#selector(presetSelected);let presetRow=NSStackView();presetRow.spacing=6;presetRow.addArrangedSubview(preset);preset.widthAnchor.constraint(equalToConstant:168).isActive=true
  presetSaveButton.target=self;presetSaveButton.action=#selector(overwritePreset);presetSaveButton.isEnabled=false;presetRow.addArrangedSubview(presetSaveButton);presetRow.addArrangedSubview(NSButton(title:"Save as…",target:self,action:#selector(savePreset)));presetControls.addArrangedSubview(presetRow)
  let editPresets=NSStackView();editPresets.spacing=12;presetRenameButton.target=self;presetRenameButton.action=#selector(renamePreset);presetDeleteButton.target=self;presetDeleteButton.action=#selector(deletePreset);configureIcon(presetRenameButton,"pencil","Rename preset");configureIcon(presetDeleteButton,"trash","Delete preset");editPresets.addArrangedSubview(presetRenameButton);editPresets.addArrangedSubview(presetDeleteButton);presetControls.addArrangedSubview(editPresets)
  for (symbol,label,action) in [("square.and.arrow.down","Import preset",#selector(importPreset)),("square.and.arrow.up","Export preset",#selector(exportPreset))]{let button=NSButton();button.target=self;button.action=action;configureIcon(button,symbol,label);editPresets.addArrangedSubview(button)}
  makeDefaultButton.target=self;makeDefaultButton.action=#selector(makePresetDefault);editPresets.addArrangedSubview(makeDefaultButton)
  let launchRow=NSStackView();launchRow.spacing=12;launchRow.addArrangedSubview(NSTextField(labelWithString:"On launch"));startup.target=self;startup.action=#selector(startupChanged);launchRow.addArrangedSubview(startup);startup.widthAnchor.constraint(equalToConstant:185).isActive=true;presetControls.addArrangedSubview(launchRow)
  presetState.font = .systemFont(ofSize:11);presetControls.addArrangedSubview(presetState)
  inspectorStack.addArrangedSubview(boxedSection("Presets",presetControls))
  let inspector=NSScrollView();inspector.hasVerticalScroller=true;inspector.autohidesScrollers=true;inspector.scrollerStyle = .overlay;inspector.drawsBackground=false;inspector.translatesAutoresizingMaskIntoConstraints=false
  let document=FlippedView();document.translatesAutoresizingMaskIntoConstraints=false;inspectorStack.translatesAutoresizingMaskIntoConstraints=false;document.addSubview(inspectorStack);inspector.documentView=document
  NSLayoutConstraint.activate([document.widthAnchor.constraint(equalTo:inspector.contentView.widthAnchor),inspectorStack.leadingAnchor.constraint(equalTo:document.leadingAnchor),inspectorStack.trailingAnchor.constraint(equalTo:document.trailingAnchor),inspectorStack.topAnchor.constraint(equalTo:document.topAnchor,constant:6),inspectorStack.bottomAnchor.constraint(equalTo:document.bottomAnchor,constant:-16)])
  for section in inspectorStack.arrangedSubviews{section.widthAnchor.constraint(equalTo:inspectorStack.widthAnchor).isActive=true}
  body.addSubview(inspector);root.addArrangedSubview(body)
  NSLayoutConstraint.activate([body.widthAnchor.constraint(equalTo:root.widthAnchor),body.heightAnchor.constraint(greaterThanOrEqualToConstant:400),left.leadingAnchor.constraint(equalTo:body.leadingAnchor),left.topAnchor.constraint(equalTo:body.topAnchor),left.bottomAnchor.constraint(equalTo:body.bottomAnchor),left.trailingAnchor.constraint(equalTo:inspector.leadingAnchor,constant:-18),inspector.trailingAnchor.constraint(equalTo:body.trailingAnchor),inspector.topAnchor.constraint(equalTo:body.topAnchor),inspector.bottomAnchor.constraint(equalTo:body.bottomAnchor),inspector.widthAnchor.constraint(equalToConstant:364)])
  body.setContentHuggingPriority(.defaultLow,for:.vertical)
  let footer=NSStackView();footer.spacing=10;codec.addItems(withTitles:["H.264","HEVC"]);codec.target=self;codec.action=#selector(codecChanged);footer.addArrangedSubview(NSTextField(labelWithString:"Export format"));footer.addArrangedSubview(codec);outputSize.addItems(withTitles:["Original","2K · 1440p","4K · 2160p"]);outputSize.target=self;outputSize.action=#selector(outputSizeChanged);footer.addArrangedSubview(outputSize);footer.addArrangedSubview(NSTextField(labelWithString:"Frame"));aspectPopup.addItems(withTitles:["16:9","4:3","Source"]);aspectPopup.target=self;aspectPopup.action=#selector(aspectChanged);aspectPopup.setAccessibilityLabel("Output aspect ratio");footer.addArrangedSubview(aspectPopup)
  let footerSpace=NSView();footerSpace.setContentHuggingPriority(.defaultLow,for:.horizontal);footer.addArrangedSubview(footerSpace)
  bar.isHidden=true;bar.isIndeterminate=false;bar.minValue=0;bar.maxValue=100;bar.widthAnchor.constraint(equalToConstant:220).isActive=true;
  cancel.target=self;cancel.action=#selector(cancelExport);cancel.isHidden=true;footer.addArrangedSubview(cancel);export.target=self;export.action=#selector(exportVideo);footer.addArrangedSubview(export);footer.addArrangedSubview(NSButton(title:"Close",target:self,action:#selector(closeApp)));root.addArrangedSubview(footer);footer.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
  let statusRow=NSStackView();statusRow.spacing=12;status.font = .systemFont(ofSize:11);status.textColor = .secondaryLabelColor;status.maximumNumberOfLines=1;status.lineBreakMode = .byTruncatingMiddle;statusSummary.font = .systemFont(ofSize:10);statusSummary.textColor = .secondaryLabelColor;statusRow.addArrangedSubview(statusSummary);statusRow.addArrangedSubview(status);status.setContentCompressionResistancePriority(.defaultLow,for:.horizontal);let statusSpace=NSView();statusSpace.setContentHuggingPriority(.defaultLow,for:.horizontal);statusRow.addArrangedSubview(statusSpace);statusRow.addArrangedSubview(bar);exportPercent.font = .monospacedDigitSystemFont(ofSize:11,weight:.medium);exportPercent.widthAnchor.constraint(equalToConstant:40).isActive=true;statusRow.addArrangedSubview(exportPercent);bar.heightAnchor.constraint(equalToConstant:16).isActive=true;statusRow.heightAnchor.constraint(equalToConstant:18).isActive=true;let statusPanel=toolPanel(statusRow,verticalPadding:3);statusPanel.identifier=NSUserInterfaceItemIdentifier("statusBar");statusPanel.heightAnchor.constraint(equalToConstant:24).isActive=true;statusPanel.setContentHuggingPriority(.required,for:.vertical);root.addArrangedSubview(statusPanel);statusPanel.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true


  preview.onTargetSelect = {[weak self] _ in self?.selectionChanged()}
  preview.onMove = {[weak self] _,x,y in guard let self=self else{return};self.settings.layout.centred=false;self.settings.layout.lineAlignment="Custom";self.settings.layout.line.x=x;self.settings.layout.line.y=y;self.preview.layout=self.settings.layout;self.save();self.updateInspector()}
  preview.onVisualMove = {[weak self] i,x,y in guard let self=self else{return};var v=self.settings.layout.visuals ?? defaultVisuals();v[i].x=x;v[i].y=y;self.settings.layout.visuals=v;self.save();self.syncPreview()}
  preview.onEditBegin = {[weak self] in self?.rememberMove()}
  preview.onSelection = {[weak self] _ in self?.selectionChanged()}
  preview.onSelectionFinish = {[weak self] in self?.selectionChanged()}
  preview.onCellMove = {[weak self] x,y in guard let self=self else{return};var cells=self.settings.layout.cells ?? [:];moveCells(self.preview.selectedCells,&cells,x,y);self.settings.layout.cells=cells;self.save();self.syncPreview()}
  refreshFontMenus();applyOSDFont()
  spaceMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown){[weak self] event in
   guard let self=self,event.keyCode==49,event.modifierFlags.intersection([.command,.control,.option]).isEmpty,NSApp.keyWindow===self.window,!(self.window.firstResponder is NSTextView) else{return event}
   if !event.isARepeat{self.togglePlayback()};return nil
  }
  setBatchSources([]);refreshUI();save();window.contentView?.layoutSubtreeIfNeeded();inspector.contentView.scroll(to:.zero);inspector.reflectScrolledClipView(inspector.contentView);window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
  if let i=CommandLine.arguments.firstIndex(of:"--preview-video"),CommandLine.arguments.count>i+1{loadVideo(URL(fileURLWithPath:CommandLine.arguments[i+1]))}
  if let i=CommandLine.arguments.firstIndex(of:"--preview-batch"),CommandLine.arguments.count>i+2{let files=[URL(fileURLWithPath:CommandLine.arguments[i+1]),URL(fileURLWithPath:CommandLine.arguments[i+2])];setBatchSources(files);loadVideo(files[0])}
  if !CommandLine.arguments.contains(where:{$0.hasSuffix("-test")}){
   DispatchQueue.main.async{[weak self] in guard let self=self,self.osdRenderer==nil else{return};let alert=NSAlert();alert.messageText="Import an OSD font";alert.informativeText="Recommended for the tested P1 / Betaflight recordings: Sneaky FPV Nexus, Walksnail Betaflight version. For 1080p footage choose the _36.png file, such as WS_BTFL_Nexus_36.png.\n\nGet OSD fonts… opens Sneaky FPV’s website. Download and extract the font pack, then use Import font… here to select its PNG. Please follow the font creator’s licence terms. No font is bundled with this app.\n\nImported fonts are copied into your own library. Telemetry text uses a separate text font.";alert.addButton(withTitle:"Import font…");alert.addButton(withTitle:"Get OSD fonts…");alert.addButton(withTitle:"Later");let websiteButton=alert.buttons[1];websiteButton.target=self;websiteButton.action=#selector(self.openFontWebsite);let response=alert.runModal();if response == .alertFirstButtonReturn{self.importFont()}}
  }

 }
 func windowShouldClose(_ sender:NSWindow)->Bool{NSApp.terminate(nil);return false}
 func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
 func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
  guard confirmCloseChanges() else{return .terminateCancel}
  if session != nil || batchRunning{let alert=NSAlert();alert.messageText="An export is in progress";alert.informativeText="Quit and cancel the export? Your original video remains unchanged.";alert.addButton(withTitle:"Keep exporting");alert.addButton(withTitle:"Quit");if alert.runModal() == .alertFirstButtonReturn{return .terminateCancel};batchCancelled=true;session?.cancelExport()}
  if asset != nil,activePresetName != "Default",settings.presets[activePresetName] != nil,settings.startup != activePresetName{
   let alert=NSAlert();alert.messageText="Open ‘\(displayPresetName(activePresetName))’ automatically next time?";alert.informativeText="You can also set this using Make Default in Presets.";alert.addButton(withTitle:"Use on launch");alert.addButton(withTitle:"Not now");alert.addButton(withTitle:"Cancel");let answer=alert.runModal();if answer == .alertThirdButtonReturn{return .terminateCancel};if answer == .alertFirstButtonReturn{settings.startup=activePresetName;guard persistClosingChanges() else{return .terminateCancel}}
  }
  return .terminateNow
 }
 func persistClosingChanges()->Bool{do{try JSONEncoder().encode(settings).write(to:settingsURL,options:.atomic);return true}catch{libraryError("Couldn’t save your changes: "+error.localizedDescription);return false}}
 func saveActiveChanges()->Bool{if activePresetName=="Default"{guard savePresetAs() != nil else{return false}}else{overwritePreset()};return persistClosingChanges()}
 func discardActiveChanges(){settings.layout=presetDefinition(activePresetName) ?? defaultLayout();refreshUI()}
 var shouldPromptToSaveLayout:Bool{asset != nil && presetDirty()}
 func confirmCloseChanges()->Bool{
  guard shouldPromptToSaveLayout else{return true}
  let alert=NSAlert();alert.messageText="Save changes before closing?";alert.informativeText=activePresetName=="Default" ? "Save your current layout as a new preset, or discard the changes.":"Save changes to ‘\(displayPresetName(activePresetName))’, or discard them.";alert.addButton(withTitle:"Save");alert.addButton(withTitle:"Discard");alert.addButton(withTitle:"Cancel")
  switch alert.runModal(){case .alertFirstButtonReturn:return saveActiveChanges();case .alertSecondButtonReturn:discardActiveChanges();return persistClosingChanges();default:return false}
 }
 @objc func makePresetDefault(){
  if presetDirty(){let alert=NSAlert();alert.messageText="Save changes and make this the default?";alert.informativeText=activePresetName=="Default" ? "Your layout needs to be saved as a named preset before it can open on launch.":"Your changes to ‘\(displayPresetName(activePresetName))’ will be saved before making it the launch preset.";alert.addButton(withTitle:"Save and make default");alert.addButton(withTitle:"Cancel");guard alert.runModal() == .alertFirstButtonReturn,saveActiveChanges() else{return}}
  settings.startup=activePresetName;save();refreshPresets();status.stringValue="‘\(displayPresetName(activePresetName))’ will open on launch."
 }

 func save(){do{try JSONEncoder().encode(settings).write(to:settingsURL,options:.atomic);updatePresetSaveState()}catch{status.stringValue="Couldn’t save settings: \(error.localizedDescription)"}}
 func applyTheme(){switch settings.layout.theme {case "Dark":window.appearance=NSAppearance(named:.darkAqua);case "Light":window.appearance=NSAppearance(named:.aqua);default:window.appearance=nil}}
 func refreshUI(){refreshVisualControls();syncPreview();for (i,c) in checks.enumerated(){c.state=settings.layout.widgets[i].enabled ? .on:.off};theme.selectItem(withTitle:settings.layout.theme);codec.selectItem(withTitle:settings.layout.codec);outputSize.selectItem(withTitle:settings.layout.outputSize ?? "Original");applyTheme();updateInspector();refreshPresets();refreshFontMenus();selectionChanged();updateEnabled()}
 func updateEnabled(){let idle=session==nil && !batchRunning;let trim=idle && batchSources.count<2;bar.isHidden=idle;timelineView.isHidden=asset==nil;playButton.isEnabled=asset != nil && idle;pauseButton.isEnabled=asset != nil && idle;stopButton.isEnabled=asset != nil && idle;exportPercent.isHidden=idle;startField.isEnabled=asset != nil && trim;endField.isEnabled=asset != nil && trim;trimButtons.forEach{$0.isEnabled=asset != nil && trim};timelineView.trimmingEnabled=trim;batchOpen.isEnabled=idle;batchPicker.isEnabled=idle;outputSize.isEnabled=idle;aspectPopup.isEnabled=idle && asset != nil && !loadingOSD;codec.isEnabled=idle;export.title=batchSources.count>1 ? "Export all \(batchSources.count) videos…":"Export video…";open.isEnabled=idle;match.isEnabled=idle && batchSources.count<2;export.isEnabled=idle && !loadingOSD && asset != nil && (batchSources.count>1 || !cues.isEmpty || (!osdFrames.isEmpty && osdRenderer != nil));cancel.isHidden=idle}
 func layoutData(_ layout:Layout)->Data{var normalized=layout;normalized.presetTitle=nil;normalized.referenceAspect=presetAspect(layout);let e=JSONEncoder();e.outputFormatting = .sortedKeys;return (try? e.encode(normalized)) ?? Data()}
 func defaultLayout()->Layout{var l=Layout();l.osdFontID=settings.legacyOSDFontID ?? fonts("osd").first?.id;migrateLayout(&l);return l}
 func presetDefinition(_ name:String)->Layout?{name=="Default" ? defaultLayout():settings.presets[name]}
 func applyStartupLayout(){
  if let old=settings.presets.removeValue(forKey:"Default"){let name=uniqueName("Default (saved)",Array(settings.presets.keys));settings.presets[name]=old;if settings.startup=="Default"{settings.startup=name}}
  if settings.presets[settings.startup]==nil{settings.startup="Default"}
  activePresetName=settings.startup;settings.layout=presetDefinition(activePresetName) ?? defaultLayout();migrateLayout(&settings.layout)
 }
 func presetDirty()->Bool{
  var base=presetDefinition(activePresetName) ?? defaultLayout();if activePresetName=="Default"{base.referenceAspect=aspectLabel(preview.sourceSize)};migrateLayout(&base);if base.osdFontID==nil{base.osdFontID=settings.legacyOSDFontID}
  return layoutData(base) != layoutData(settings.layout)
 }
 func updatePresetSaveState(){
  for item in preset.itemArray{item.attributedTitle=NSAttributedString(string:item.title,attributes:[.foregroundColor:item.representedObject as? String==activePresetName && activePresetName != "Default" ? NSColor.systemBlue:NSColor.labelColor])};updateStatusSummary()
  let dirty=presetDirty();makeDefaultButton.isHidden=activePresetName=="Default" && settings.startup=="Default" && !dirty;makeDefaultButton.title=settings.startup==activePresetName && !dirty ? "Default on launch":"Make Default";makeDefaultButton.isEnabled=settings.startup != activePresetName || dirty;presetSaveButton.isEnabled=activePresetName != "Default" && settings.presets[activePresetName] != nil && dirty
  presetState.stringValue=dirty ? "Unsaved changes":"";presetState.isHidden = !dirty;presetRenameButton.isEnabled=activePresetName != "Default";presetDeleteButton.isEnabled=activePresetName != "Default"
  for item in presetManage.itemArray where ["Rename…","Delete"].contains(item.title){item.isEnabled=activePresetName != "Default"}
 }
 func applyPreset(_ name:String,prepared:Layout?=nil){
  guard var layout=prepared ?? (name=="Default" ? defaultForCurrentFrame():presetDefinition(name)) else{return};pausePlayback();clearMoveUndo();activePresetName=name;migrateLayout(&layout);settings.layout=layout;preview.selectedCells=[];preview.telemetrySelected=false;applyOSDFont();save();refreshUI()
 }
 func requestPreset(_ name:String){
  guard var proposed=(name=="Default" ? defaultForCurrentFrame():presetDefinition(name)) else{refreshPresets();return}
  let current=aspectLabel(preview.canvasSize);let target=name=="Default" ? current:presetAspect(proposed)
  if asset != nil,target != "Source",target != current{
   let alert=NSAlert();alert.messageText="Load a \(target) preset into the \(current) frame?";alert.informativeText="The output frame will change to \(target), using a centred crop where required. Whole OSD groups and the telemetry line will be adjusted to fit. Cancel keeps your current frame and layout.";alert.addButton(withTitle:"Adjust to fit");alert.addButton(withTitle:"Cancel");guard alert.runModal() == .alertFirstButtonReturn else{refreshPresets();return}
   if proposed.aspectRatio==nil && aspectLabel(preview.sourceSize) != target{proposed.aspectRatio=target}
   proposed=fitOverlays(proposed,recordingElements(osdFrames),cues,centreCrop(preview.sourceSize,proposed.aspectRatio,picture:preview.pictureRect).size).layout
  }
  if presetDirty(){
   let a=NSAlert();a.messageText="Save changes before loading ‘\(displayPresetName(name))’?";a.informativeText="Your current layout has unsaved changes."
   a.addButton(withTitle:activePresetName=="Default" ? "Save as…":"Save");a.addButton(withTitle:"Discard changes");a.addButton(withTitle:"Cancel")
   switch a.runModal(){
   case .alertFirstButtonReturn:if activePresetName=="Default"{guard savePresetAs() != nil else{refreshPresets();return}}else{overwritePreset()}
   case .alertSecondButtonReturn:break
   default:refreshPresets();return
   }
  };applyPreset(name,prepared:proposed)
 }
 @objc func presetSelected(){if let name=preset.selectedItem?.representedObject as? String{requestPreset(name)}}
 @objc func resetToDefault(){requestPreset("Default")}
 @objc func overwritePreset(){guard activePresetName != "Default",settings.presets[activePresetName] != nil else{return};settings.layout.referenceAspect=aspectLabel(preview.canvasSize);settings.presets[activePresetName]=settings.layout;save();updatePresetSaveState();status.stringValue="Saved preset: "+displayPresetName(activePresetName)}
 func refreshPresets(){
  let ratio=aspectLabel(preview.canvasSize)
  if settings.startup != "Default",let launch=settings.presets[settings.startup],presetAspect(launch) != ratio{settings.startup="Default";save()}
  for popup in [preset,startup]{popup.removeAllItems();let names=settings.presets.keys.sorted().filter{presetAspect(settings.presets[$0]!)==ratio};for name in ["Default"]+names{popup.addItem(withTitle:displayPresetName(name));popup.lastItem?.representedObject=name}}

  selectPresetNamed(activePresetName,in:preset);selectPresetNamed(settings.startup,in:startup);updatePresetSaveState()

 }


 func syncPreview(){if let columns=settings.layout.gridColumns,[16,24].contains(columns){settings.layout.gridColumns=32};if var visuals=settings.layout.visuals,visuals.count==3{if visuals[0].kind=="Battery"{visuals[0].kind="SBat";if settings.layout.batterySource=="GBat"{visuals[0].enabled=false;var ground=defaultVisuals()[3];ground.enabled=true;visuals.append(ground)}else{visuals.append(defaultVisuals()[3])}}else{visuals.append(defaultVisuals()[3])};settings.layout.visuals=visuals};if var visuals=settings.layout.visuals,visuals.count==4{visuals.append(defaultVisuals()[4]);settings.layout.visuals=visuals};if var visuals=settings.layout.visuals,visuals.count==5{visuals.append(defaultVisuals()[5]);settings.layout.visuals=visuals};preview.visualCues=cues;preview.visualTime=scrub.doubleValue;preview.layout=settings.layout;refreshAspectPopup();preview.visibleCells=Set(osdAt(scrub.doubleValue,osdFrames).filter{osdRenderer?.glyphs.indices.contains($0.index) == true}.map{$0.y*53+$0.x});if let renderer=osdRenderer{preview.osdImage=renderer.preview(scrub.doubleValue,osdFrames,settings.layout.cells ?? [:],preview.canvasSize,custom:settings.layout.visuals?.first{$0.kind=="Custom"})}else{preview.osdImage=nil};preview.needsDisplay=true}
 @objc func outlinesChanged(){settings.layout.centreGuides=showOutlines.state == .on;showOutlines.contentTintColor=showOutlines.state == .on ? .systemBlue:nil;save();syncPreview()}
 func selectionChanged(){
  selectionChooser.selectedSegment=preview.telemetrySelected ? 2:(preview.selectedCells.isEmpty ? 0:(preview.selectedCells==preview.availableCells ? 1:-1));selectionChooser.setEnabled(!preview.availableCells.isEmpty,forSegment:1);selectionChooser.setEnabled(!cues.isEmpty,forSegment:2)
  showOutlines.state=settings.layout.centreGuides == true ? .on:.off;showOutlines.contentTintColor=settings.layout.centreGuides == true ? .systemBlue:nil
  let sizes=preview.selectedCells.map{(settings.layout.cells?[String($0)]?.scale ?? 1)*20};let actual=preview.telemetrySelected ? settings.layout.line.size:(sizes.first ?? 20);let mixed = !preview.telemetrySelected && sizes.contains{abs($0-actual)>0.01};lastOSDScale=actual;osdScale.doubleValue=actual;sizeValue.stringValue=mixed ? "":String(Int(actual.rounded()));sizeValue.placeholderString=mixed ? "Mixed":"20";sizeValue.isEnabled=preview.telemetrySelected || !preview.selectedCells.isEmpty;osdScale.isEnabled = !preview.selectedCells.isEmpty;osdColour.isEnabled = !preview.selectedCells.isEmpty
  alignment.selectedSegment=preview.telemetrySelected ? (["Left","Centre","Right"].firstIndex(of:effectiveAlignment(settings.layout)) ?? -1):-1;verticalAlign.selectedSegment = -1;gridToggle.state=settings.layout.gridEnabled == true ? .on:.off;gridToggle.contentTintColor=settings.layout.gridEnabled == true ? .systemBlue:nil;gridSize.selectItem(withTitle:String([16,24].contains(settings.layout.gridColumns ?? 32) ? 32:(settings.layout.gridColumns ?? 32)))
  telemetryBaseSize=settings.layout.line.size;let active = preview.telemetrySelected || !preview.selectedCells.isEmpty;osdScale.isEnabled=active;osdColour.isEnabled=active
  selectionLabel.stringValue=preview.telemetrySelected ? "Telemetry":(preview.selectedCells.isEmpty ? "None":"OSD")
  let allHidden = preview.telemetrySelected ? settings.layout.telemetryHidden == true:(!preview.selectedCells.isEmpty && preview.selectedCells.allSatisfy{settings.layout.cells?[String($0)]?.hidden == true})
  hideSelectionButton.title="";hideSelectionButton.image=visibilityIcon(hidden:allHidden);hideSelectionButton.toolTip=allHidden ? "Show selection":"Hide selection";hideSelectionButton.setAccessibilityLabel(hideSelectionButton.toolTip);hideSelectionButton.contentTintColor=allHidden ? .systemRed:nil;hideSelectionButton.isEnabled = preview.telemetrySelected || !preview.selectedCells.isEmpty
  updateOSDColourControls()
  selectionChooser.setEnabled((settings.layout.visuals ?? []).contains{$0.enabled},forSegment:3)
  if let i=chosenVisuals.first,let visuals=settings.layout.visuals{let v=visuals[i];selectionChooser.selectedSegment=preview.allVisualsSelected ? 3:-1;selectionLabel.stringValue=preview.allVisualsSelected ? "Visuals":v.kind;sizeValue.isEnabled=true;osdScale.isEnabled=true;let mixed=chosenVisuals.contains{abs(visuals[$0].scale-v.scale)>0.001};sizeValue.stringValue=mixed ? "":String(Int((v.scale*20).rounded()));sizeValue.placeholderString="Mixed";osdScale.doubleValue=v.scale*20;osdColour.isEnabled=chosenVisuals.count==1 && v.kind=="Custom";resetTint.isEnabled=osdColour.isEnabled && v.tint != nil;if osdColour.isEnabled{let rgb=v.tint ?? [1,1,1];osdColour.color=NSColor(srgbRed:rgb[0],green:rgb[1],blue:rgb[2],alpha:1)};osdColour.toolTip="Visual colours follow their telemetry thresholds";let hidden=chosenVisuals.allSatisfy{visuals[$0].hidden == true};hideSelectionButton.isEnabled=true;hideSelectionButton.image=visibilityIcon(hidden:hidden);hideSelectionButton.toolTip=hidden ? "Show visuals":"Hide visuals"}

  updateStatusSummary();preview.needsDisplay=true
 }
 @objc func selectionChoiceChanged(){switch selectionChooser.selectedSegment{case 1:selectAllOSD();case 2:selectTelemetry();case 3:selectAllVisuals();default:clearOSDSelection()}}
 var chosenVisuals:[Int]{let visuals=settings.layout.visuals ?? [];return visuals.indices.filter{visuals[$0].enabled && (preview.allVisualsSelected || preview.selectedVisual==$0 || preview.selectedVisuals.contains($0))}}
 @objc func selectAllVisuals(){preview.selectedVisuals=[];preview.allVisualsSelected=true;preview.selectedVisual=nil;preview.selectedCells=[];preview.telemetrySelected=false;selectionChanged()}
 @objc func selectTelemetry(){preview.selectedVisuals=[];preview.allVisualsSelected=false;preview.selectedVisual=nil;preview.selectedCells=[];preview.telemetrySelected=true;selectionChanged()}
 @objc func selectAllOSD(){preview.selectedVisuals=[];preview.allVisualsSelected=false;preview.selectedVisual=nil;preview.telemetrySelected=false;preview.mode=0;preview.selectedCells=preview.availableCells;selectionChanged()}
 @objc func clearOSDSelection(){preview.selectedVisuals=[];preview.allVisualsSelected=false;preview.selectedVisual=nil;preview.telemetrySelected=false;preview.selectedCells=[];selectionChanged()}
 @objc func sizeEntered(){guard let value=Double(sizeValue.stringValue),value>=4,value<=50 else{selectionChanged();return};osdScale.doubleValue=value;scaleOSD()}
 @objc func scaleOSD(){clearMoveUndo();let target=osdScale.doubleValue.rounded();osdScale.doubleValue=target;sizeValue.stringValue=String(Int(target))
  if !chosenVisuals.isEmpty{var visuals=settings.layout.visuals ?? defaultVisuals();let canvas=CGRect(origin:.zero,size:preview.canvasSize);for i in chosenVisuals{visuals[i].scale=target/20;let box=visualRect(visuals[i],canvas);visuals[i].x=max(0,min(visuals[i].x,1-box.width/canvas.width));visuals[i].y=max(0,min(visuals[i].y,1-box.height/canvas.height))};settings.layout.visuals=visuals;save();syncPreview();selectionChanged();return}

  if preview.telemetrySelected{settings.layout.line.size=target;save();syncPreview();return}
  guard !preview.selectedCells.isEmpty else{return};var cells=settings.layout.cells ?? [:]
  let groups=(preview.elementGroups.isEmpty ? detectedGroups(preview.availableCells,[:],includeHidden:true):preview.elementGroups).filter{!$0.isDisjoint(with:preview.selectedCells)}
  for group in groups{let ids=group.intersection(preview.selectedCells);let current=(cells[String(ids.first!)]?.scale ?? 1)*20;scaleCells(ids,&cells,target/current)}
  settings.layout.cells=cells;lastOSDScale=target;save();syncPreview()
 }
 func updateOSDColourControls(){
  if preview.telemetrySelected{let w=settings.layout.line;osdColour.color=w.colour;resetTint.isEnabled=w.red != 1 || w.green != 1 || w.blue != 1;return}
  let cells=settings.layout.cells ?? [:];let tints=preview.selectedCells.compactMap{cells[String($0)]?.tint}
  resetTint.isEnabled = !tints.isEmpty
  if let tint=tints.first,tint.count==3{osdColour.color=NSColor(srgbRed:tint[0],green:tint[1],blue:tint[2],alpha:1)}else{osdColour.color = .white}
 }
 @objc func tintOSD(){clearMoveUndo();guard let c=osdColour.color.usingColorSpace(.sRGB) else{return}
  if let i=chosenVisuals.first,chosenVisuals.count==1,settings.layout.visuals![i].kind=="Custom"{settings.layout.visuals![i].tint=[c.redComponent,c.greenComponent,c.blueComponent];save();syncPreview();selectionChanged();return}
  if preview.telemetrySelected{settings.layout.line.red=c.redComponent;settings.layout.line.green=c.greenComponent;settings.layout.line.blue=c.blueComponent;save();syncPreview();updateOSDColourControls();return}
  var cells=settings.layout.cells ?? [:]
  for id in preview.selectedCells{var style=cells[String(id)] ?? CellStyle();style.tint=[c.redComponent,c.greenComponent,c.blueComponent];cells[String(id)]=style}
  settings.layout.cells=cells;save();syncPreview();updateOSDColourControls()
 }
 @objc func resetOSDTint(){clearMoveUndo();if let i=chosenVisuals.first,chosenVisuals.count==1,settings.layout.visuals![i].kind=="Custom"{settings.layout.visuals![i].tint=nil;save();syncPreview();selectionChanged();return};if preview.telemetrySelected{settings.layout.line.red=1;settings.layout.line.green=1;settings.layout.line.blue=1;save();syncPreview();updateOSDColourControls();return};var cells=settings.layout.cells ?? [:];for id in preview.selectedCells{var style=cells[String(id)] ?? CellStyle();style.tint=nil;cells[String(id)]=style};settings.layout.cells=cells;save();syncPreview();updateOSDColourControls()}
 @objc func hideOSDSelection(){clearMoveUndo();if !chosenVisuals.isEmpty{var visuals=settings.layout.visuals ?? defaultVisuals();let hidden = !chosenVisuals.allSatisfy{visuals[$0].hidden == true};for i in chosenVisuals{visuals[i].hidden=hidden};settings.layout.visuals=visuals;save();syncPreview();selectionChanged();return};if preview.telemetrySelected{settings.layout.telemetryHidden = !(settings.layout.telemetryHidden ?? false);save();syncPreview();selectionChanged();return};guard !preview.selectedCells.isEmpty else{return};var cells=settings.layout.cells ?? [:];let shouldHide = !preview.selectedCells.allSatisfy{cells[String($0)]?.hidden == true};for id in preview.selectedCells{var style=cells[String(id)] ?? CellStyle();style.hidden=shouldHide;cells[String(id)]=style};settings.layout.cells=cells;save();syncPreview();selectionChanged()}
 @objc func resetOSD(){clearMoveUndo();settings.layout.cells=[:];settings.layout.regions=[];clearOSDSelection();save();syncPreview()}
 func updateInspector(){alignment.selectedSegment=["Left","Centre","Right"].firstIndex(of:effectiveAlignment(settings.layout)) ?? -1;xSlider.isEnabled=true;let w=settings.layout.line;size.doubleValue=w.size;xSlider.doubleValue=w.x*100;ySlider.doubleValue=w.y*100;sizeLabel.stringValue="Line size: \(Int(w.size)) (at 1080p)";xLabel.stringValue=String(format:"Line horizontal: %.1f%%",w.x*100);yLabel.stringValue=String(format:"Line vertical: %.1f%%",w.y*100);colour.color=w.colour;preview.needsDisplay=true}
 func rememberMove(){pausePlayback();undoPresetName=activePresetName;redoPresetName=nil;redoLayout=nil;redoButton.isEnabled=false;undoLayout=settings.layout;undoCells=settings.layout.cells ?? [:];undoMoveButton.isEnabled=true}
 func clearMoveUndo(){undoPresetName=nil;redoPresetName=nil;redoLayout=nil;redoButton.isEnabled=false;undoLayout=nil;undoCells=nil;undoMoveButton.isEnabled=false}
 @objc func undoMove(){guard let layout=undoLayout else{return};redoLayout=settings.layout;redoPresetName=activePresetName;activePresetName=undoPresetName ?? activePresetName;settings.layout=layout;undoPresetName=nil;undoLayout=nil;undoCells=nil;undoMoveButton.isEnabled=false;redoButton.isEnabled=true;save();syncPreview();refreshPresets();selectionChanged()}
 @objc func redoMove(){guard let layout=redoLayout else{return};undoLayout=settings.layout;undoPresetName=activePresetName;undoCells=settings.layout.cells ?? [:];activePresetName=redoPresetName ?? activePresetName;settings.layout=layout;redoPresetName=nil;redoLayout=nil;redoButton.isEnabled=false;undoMoveButton.isEnabled=true;save();syncPreview();refreshPresets();selectionChanged()}
 func rangeTime(_ seconds:Double)->String{let n=Int(max(0,seconds));return String(format:"%02d:%02d:%02d",n/3600,(n/60)%60,n%60)}
 func chosenRange()->(Double,Double)?{
  let start=startField.stringValue==rangeTime(exactIn) ? exactIn:parseExportTime(startField.stringValue)
  let end=endField.stringValue==rangeTime(exactOut) ? exactOut:parseExportTime(endField.stringValue)
  guard let a=start,let b=end,a<b,b<=duration+0.001 else{return nil};return(a,min(b,duration))
 }
 func updateTimeline(){timelineView.duration=duration;timelineView.playhead=scrub.doubleValue;if let (a,b)=chosenRange(){timelineView.start=a;timelineView.end=b};timelineView.needsDisplay=true}
 @objc func rangeEdited(_ sender:Any?=nil){
  if let field=sender as? NSTextField,let t=parseExportTime(field.stringValue){if field===startField{exactIn=t}else if field===endField{exactOut=t};field.stringValue=rangeTime(t)}
  updateTimeline();updateStatusSummary();if let (a,b)=chosenRange(){rangeLabel.stringValue="Duration  "+rangeTime(b-a);if isPlaying && (scrub.doubleValue<a || scrub.doubleValue>=b){pausePlayback()}}else{rangeLabel.stringValue="Start must be before end and within the video."}
 }
 @objc func setStartHere(){exactIn=scrub.doubleValue;startField.stringValue=rangeTime(exactIn);rangeEdited()}
 @objc func setEndHere(){exactOut=scrub.doubleValue;endField.stringValue=rangeTime(exactOut);rangeEdited()}
 @objc func fullVideo(){exactIn=0;exactOut=duration;startField.stringValue=rangeTime(0);endField.stringValue=rangeTime(duration);rangeEdited()}
 @objc func closeApp(){NSApp.terminate(nil)}
 @objc func maximise(){window.toggleFullScreen(nil)}
 func windowDidEnterFullScreen(_ notification:Notification){fullScreenButton.title="Exit full screen"}
 func windowDidExitFullScreen(_ notification:Notification){fullScreenButton.title="Full screen"}
 @objc func gridChanged(){settings.layout.gridEnabled=gridToggle.state == .on;gridToggle.contentTintColor=gridToggle.state == .on ? .systemBlue:nil;settings.layout.gridColumns=Int(gridSize.titleOfSelectedItem ?? "32");save();syncPreview()}
 func alignSelection(_ horizontal:Int?,_ vertical:Int?){
  if !chosenVisuals.isEmpty{rememberMove();var visuals=settings.layout.visuals ?? defaultVisuals();let canvas=CGRect(origin:.zero,size:preview.canvasSize);let bounds=chosenVisuals.reduce(CGRect.null){$0.union(visualRect(visuals[$1],canvas))};let relative=alignReference.indexOfSelectedItem==1 && chosenVisuals.count>1;for i in chosenVisuals{let box=visualRect(visuals[i],canvas);let w=box.width/canvas.width,h=box.height/canvas.height;if let x=horizontal{visuals[i].x=relative ? (x==0 ? bounds.minX:(x==1 ? bounds.midX-box.width/2:bounds.maxX-box.width))/canvas.width:(x==0 ? 0.02:(x==1 ? (1-w)/2:max(0,0.98-w)))};if let y=vertical{visuals[i].y=relative ? (y==0 ? bounds.minY:(y==1 ? bounds.midY-box.height/2:bounds.maxY-box.height))/canvas.height:(y==0 ? 0.02:(y==1 ? (1-h)/2:max(0,0.98-h)))}};settings.layout.visuals=visuals;save();syncPreview();return}

  guard preview.telemetrySelected || !preview.selectedCells.isEmpty else{return};rememberMove()
  if preview.telemetrySelected{
   if let h=horizontal{settings.layout.lineAlignment=["Left","Centre","Right"][h];settings.layout.centred=h==1}
   if let v=vertical{let text=telemetryLine(preview.values,settings.layout.widgets);let height=(text as NSString).size(withAttributes:textAttributes(settings.layout.line,1080)).height/1080;settings.layout.line.y=v==0 ? 0.02:(v==1 ? (1-height)/2:0.98-height)}
  }else{
   var cells=settings.layout.cells ?? [:];let b=cellBounds(preview.selectedCells,cells)
   let groups=preview.outlines.filter{!$0.isDisjoint(with:preview.selectedCells)}
   if alignReference.indexOfSelectedItem==1 && groups.count>1{
    for group in groups{let box=cellBounds(group,cells);var dx=0.0,dy=0.0
     if let h=horizontal{dx=(h==0 ? b.minX:(h==1 ? b.midX-box.width/2:b.maxX-box.width))-box.minX}
     if let v=vertical{dy=(v==0 ? b.minY:(v==1 ? b.midY-box.height/2:b.maxY-box.height))-box.minY}
     moveCells(group,&cells,dx,dy)
    }
   }else{
    var dx=0.0,dy=0.0
    if let h=horizontal{dx=(h==0 ? 0.02:(h==1 ? (1-b.width)/2:0.98-b.width))-b.minX}
    if let v=vertical{dy=(v==0 ? 0.02:(v==1 ? (1-b.height)/2:0.98-b.height))-b.minY}
    moveCells(preview.selectedCells,&cells,dx,dy)
   };settings.layout.cells=cells
  };save();syncPreview()
 }
 @objc func alignmentChanged(){guard alignment.selectedSegment>=0 else{return};alignSelection(alignment.selectedSegment,nil)}
 @objc func verticalAlignmentChanged(){guard verticalAlign.selectedSegment>=0 else{return};alignSelection(nil,verticalAlign.selectedSegment)}
 @objc func openFontWebsite(){NSWorkspace.shared.open(URL(string:"https://sites.google.com/view/sneaky-fpv/home")!)}
 @objc func about(){let a=NSAlert();a.messageText="OSD Editor v1.0 — by KrisTalksTech";a.informativeText="Copyright © 2026 Kris Gleave (KrisTalksTech).\n\nEdit recorded FPV OSD, telemetry and video. Tested with BETAFPV P1 / Artlynk recordings. Other systems are not yet verified.\n\nFree software under GPL-3.0-or-later; redistribution and modification are permitted under that licence. Provided WITHOUT ANY WARRANTY.\n\nIncludes OSD parsing adapted from ksielick/walksnail-osd-tool and Alexander van Saase’s upstream project. See Credits for provenance. Fonts have separate licences and are not bundled.";a.addButton(withTitle:"OK");a.addButton(withTitle:"Licence");a.addButton(withTitle:"Credits");let response=a.runModal();let name=response == .alertSecondButtonReturn ? "LICENSE":(response == .alertThirdButtonReturn ? "THIRD_PARTY_NOTICES":nil);if let name=name,let url=Bundle.main.url(forResource:name,withExtension:"txt"){NSWorkspace.shared.open(url)}}

 @objc func changeTheme(){settings.layout.theme=theme.titleOfSelectedItem ?? "Dark";applyTheme();save()}
 @objc func codecChanged(){var proposed=settings.layout;proposed.codec=codec.titleOfSelectedItem ?? "H.264";if let asset=asset{guard let compatible=compatibleExportLayout(proposed,asset) else{codec.selectItem(withTitle:settings.layout.codec);return};proposed=compatible};settings.layout=proposed;codec.selectItem(withTitle:proposed.codec);save()}
 @objc func toggle(_ sender:NSButton){settings.layout.widgets[sender.tag].enabled=sender.state == .on;syncPreview();save()}
 @objc func selectField(){updateInspector()}
 @objc func styleChanged(){settings.layout.line.size=size.doubleValue;save();syncPreview();updateInspector()}
 @objc func positionChanged(_ sender:NSSlider){if sender===xSlider{settings.layout.centred=false;settings.layout.lineAlignment="Custom"};settings.layout.line.x=xSlider.doubleValue/100;settings.layout.line.y=ySlider.doubleValue/100;save();syncPreview();updateInspector()}
 @objc func colourChanged(){let c=colour.color.usingColorSpace(.sRGB) ?? .white;settings.layout.line.red=c.redComponent;settings.layout.line.green=c.greenComponent;settings.layout.line.blue=c.blueComponent;save();syncPreview()}
 @objc func resetLayout(){clearMoveUndo();settings.layout=Layout();preview.selectedCells=[];save();refreshUI()}
 @objc func savePreset(){_ = savePresetAs()}
 func savePresetAs()->String?{
  let a=NSAlert();a.messageText="Save layout preset";let input=NSTextField(frame:NSRect(x:0,y:0,width:260,height:24));a.accessoryView=input;a.addButton(withTitle:"Save");a.addButton(withTitle:"Cancel")
  guard a.runModal() == .alertFirstButtonReturn else{return nil};let name=input.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
  guard !name.isEmpty,name.caseInsensitiveCompare("Default") != .orderedSame,name != "Last settings" else{libraryError("Choose a name other than Default.");return nil}
  let ratio=aspectLabel(preview.canvasSize)
  if existingPreset(named:name,aspect:ratio) != nil{let confirm=NSAlert();confirm.messageText="Replace preset ‘\(name)’?";confirm.informativeText="A \(ratio) preset with this name already exists. The other aspect-ratio versions are separate.";confirm.addButton(withTitle:"Replace");confirm.addButton(withTitle:"Cancel");guard confirm.runModal() == .alertFirstButtonReturn else{return nil}}
  settings.layout.referenceAspect=ratio
  do{let key=try storePreset(named:name,layout:settings.layout,replace:true);settings.layout=settings.presets[key]!;activePresetName=key;save();refreshPresets();return key}catch{libraryError(error.localizedDescription);return nil}

 }
 @objc func loadPreset(){if let name=preset.selectedItem?.representedObject as? String{requestPreset(name)}}
 @objc func startupChanged(){settings.startup=startup.selectedItem?.representedObject as? String ?? "Default";save();refreshPresets()}
 @objc func openVideo(){pausePlayback();let p=NSOpenPanel();p.allowedContentTypes=[.movie,.mpeg4Movie,.quickTimeMovie];guard p.runModal() == .OK,let u=p.url else{return};setBatchSources([]);loadVideo(u)}
 func loadVideo(_ u:URL){preview.pictureRect=nil;pausePlayback();clearMoveUndo();url=u;videoName.stringValue=u.lastPathComponent;videoName.toolTip=u.path;asset=AVURLAsset(url:u);let a=asset!;duration=CMTimeGetSeconds(a.duration);guard duration.isFinite,duration>0,let track=a.tracks(withMediaType:.video).first else{status.stringValue="Couldn’t read this video.";asset=nil;return}
  let transformed=track.naturalSize.applying(track.preferredTransform);preview.sourceSize=NSSize(width:abs(transformed.width),height:abs(transformed.height));if settings.layout.aspectRatio==nil{let detected=aspectLabel(preview.sourceSize);if activePresetName != "Default",let named=settings.presets[activePresetName],presetAspect(named) != detected{activePresetName="Default"};settings.layout.referenceAspect=detected};mediaInfo.stringValue=String(format:"%.0f×%.0f · %.2f fps · %.1f Mbps · %@",preview.sourceSize.width,preview.sourceSize.height,track.nominalFrameRate,track.estimatedDataRate/1_000_000,rangeTime(duration));mediaInfo.toolTip=mediaInfo.stringValue;generator=AVAssetImageGenerator(asset:a);generator!.appliesPreferredTrackTransform=true;generator!.requestedTimeToleranceBefore = .zero;generator!.requestedTimeToleranceAfter = .zero;generator!.maximumSize=NSSize(width:1600,height:1000);let item=AVPlayerItem(asset:a);let output=AVPlayerItemVideoOutput(pixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]);item.add(output);playerOutput=output;player=AVPlayer(playerItem:item)
  scrub.maxValue=duration;scrub.doubleValue=0;fullVideo()
  let same=u.deletingPathExtension().appendingPathExtension("srt");let siblings=(try? FileManager.default.contentsOfDirectory(at:u.deletingLastPathComponent(),includingPropertiesForKeys:nil)) ?? []
  let match=FileManager.default.fileExists(atPath:same.path) ? same:siblings.first{$0.pathExtension.lowercased()=="srt" && $0.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(u.deletingPathExtension().lastPathComponent) == .orderedSame}
  cues=[];lastSRT=nil;if let m=match{loadSRT(m)}else{status.stringValue="\(u.lastPathComponent) opened. No matching SRT found; use Choose SRT."};updateFileLabels();startOSD(u);updateEnabled();requestPreview()
 }

 func startOSD(_ video:URL){
  loadToken+=1;let token=loadToken;loadingOSD=true;osdFrames=[];syncPreview();status.stringValue="Reading OSD from video…";updateEnabled()
  DispatchQueue.global(qos:.userInitiated).async{
   let sidecar=video.deletingPathExtension().appendingPathExtension("osd")
   var result=[OSDFrame]();var message=""
   do{result=try extractOSD(video);message="OSD extracted from MP4";if result.isEmpty && FileManager.default.fileExists(atPath:sidecar.path){result=try readOSD(sidecar);message="OSD loaded from .osd file"}}catch{if let fallback=try? readOSD(sidecar){result=fallback;message="OSD loaded from .osd file"}else{message="OSD couldn’t load: "+error.localizedDescription}}
   let picture=detectedPictureRect(AVURLAsset(url:video))
   DispatchQueue.main.async{guard token==self.loadToken else{return};self.loadingOSD=false;self.preview.pictureRect=picture;self.osdFrames=result;self.preview.availableCells=Set(result.flatMap{$0.glyphs.map{$0.y*53+$0.x}});self.preview.elementGroups=recordingElements(result);self.preview.selectedCells=[];self.refreshPresets();self.selectionChanged();self.status.stringValue=(result.isEmpty ? "No OSD data found. ":"")+(self.osdRenderer == nil && !result.isEmpty ? "Choose an OSD font in Fonts. ":"")+(self.cues.isEmpty ? "No SRT loaded.":"");if self.scrub.doubleValue==0,let first=result.first,first.time>0{self.scrub.doubleValue=min(self.duration,first.time);self.requestPreview()}else{self.syncPreview()};self.updateEnabled()}
  }
 }
 @objc func chooseSRT(){pausePlayback();let p=NSOpenPanel();p.allowedContentTypes=[UTType(filenameExtension:"srt") ?? .plainText];guard p.runModal() == .OK,let u=p.url else{return};loadSRT(u);requestPreview()}
 func loadSRT(_ u:URL){do{let parsed=parseSRT(try String(contentsOf:u,encoding:.utf8));guard !parsed.isEmpty else{throw NSError(domain:"P1",code:1,userInfo:[NSLocalizedDescriptionKey:"No recognised telemetry readings found."])};cues=parsed;lastSRT=u;let keys=Set(parsed.flatMap{$0.values.keys});status.stringValue=""}catch{cues=[];lastSRT=nil;status.stringValue="Couldn’t load SRT: \(error.localizedDescription)"};updateFileLabels();updateEnabled()}
 @objc func scrubChanged(){pausePlayback();requestPreview()}
 func requestPreview(){updateTimeline();let t=scrub.doubleValue;player?.seek(to:CMTime(seconds:t,preferredTimescale:60000),toleranceBefore:.zero,toleranceAfter:.zero);preview.values=valuesAt(t,cues);syncPreview();timeLabel.stringValue="\(clock(t)) / \(clock(duration))";guard let gen=generator else{return};previewGeneration+=1;let token=previewGeneration
  imageQueue.async {let image=try? gen.copyCGImage(at:CMTime(seconds:t,preferredTimescale:600),actualTime:nil);DispatchQueue.main.async{guard token==self.previewGeneration else{return};if let cg=image{self.preview.frameImage=NSImage(cgImage:cg,size:.zero);self.preview.needsDisplay=true}}}
 }
 func updateFileLabels(){srtName.stringValue=lastSRT.map{$0.lastPathComponent} ?? "SRT: none loaded";srtName.toolTip=lastSRT?.path;if let srt=lastSRT{let bytes=((try? srt.resourceValues(forKeys:[.fileSizeKey]))?.fileSize) ?? 0;srtInfo.stringValue="\(cues.count) samples · \(rangeTime(cues.last?.end ?? 0)) · \(ByteCountFormatter.string(fromByteCount:Int64(bytes),countStyle:.file))";srtInfo.toolTip=srtInfo.stringValue}else{srtInfo.stringValue="No matching telemetry loaded"}}
 @objc func pauseMedia(){pausePlayback()}
 @objc func stopMedia(){pausePlayback();scrub.doubleValue=chosenRange()?.0 ?? 0;requestPreview()}
 func pausePlayback(){player?.pause();playbackTimer?.invalidate();playbackTimer=nil;isPlaying=false;playButton.title="";playButton.image=NSImage(systemSymbolName:"play.fill",accessibilityDescription:"Play")}
 @objc func togglePlayback(){
  guard player != nil else{return};if isPlaying{pausePlayback();return}
  guard let (start,end)=chosenRange() else{status.stringValue="Choose a valid In/Out range to play.";return}
  if scrub.doubleValue<start || scrub.doubleValue>=end-0.001{scrub.doubleValue=start}
  previewGeneration+=1;player?.seek(to:CMTime(seconds:scrub.doubleValue,preferredTimescale:60000),toleranceBefore:.zero,toleranceAfter:.zero)
  player?.currentItem?.forwardPlaybackEndTime=CMTime(seconds:end,preferredTimescale:60000);isPlaying=true;playButton.title="";playButton.image=NSImage(systemSymbolName:"pause.fill",accessibilityDescription:"Pause");player?.play()
  playbackTimer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true){[weak self] _ in self?.playbackTick()}
 }
 func playbackTick(){
  guard let player=player,let output=playerOutput else{return}
  let t=player.currentTime().seconds;guard t.isFinite else{return}
  if let (_,end)=chosenRange(),t>=end-0.001{
   pausePlayback();scrub.doubleValue=end;requestPreview();return
  }
  scrub.doubleValue=t;preview.values=valuesAt(t,cues);syncPreview();updateTimeline();timeLabel.stringValue="\(clock(t)) / \(clock(duration))"
  let itemTime=output.itemTime(forHostTime:CACurrentMediaTime())
  if output.hasNewPixelBuffer(forItemTime:itemTime),let buffer=output.copyPixelBuffer(forItemTime:itemTime,itemTimeForDisplay:nil){
   playbackFrames+=1;let image=CIImage(cvPixelBuffer:buffer)
   if let cg=playbackContext.createCGImage(image,from:image.extent){preview.frameImage=NSImage(cgImage:cg,size:.zero);preview.needsDisplay=true}
  }
  if t>=duration-0.03{pausePlayback()}
 }
 func clock(_ t:Double)->String{rangeTime(t)}
 func composition(_ asset:AVAsset,widgets:[Widget],cues:[Cue],layoutOverride:Layout?=nil,framesOverride:[OSDFrame]?=nil,rendererOverride:OSDRenderer?=nil)->AVVideoComposition {
  var layout=layoutOverride ?? settings.layout;migrateLayout(&layout);let frames=framesOverride ?? osdFrames;let renderer=rendererOverride ?? osdRenderer;let target=exportDimensions(asset,layout.outputSize ?? "Original",aspect:layout.aspectRatio);let sourcePicture=detectedPictureRect(asset);let sourceTrack=asset.tracks(withMediaType:.video).first!;let oriented=sourceTrack.naturalSize.applying(sourceTrack.preferredTransform);let nativeSize=CGSize(width:abs(oriented.width),height:abs(oriented.height))
  let cache=TextCache()
  let composition=AVMutableVideoComposition(asset:asset,applyingCIFiltersWithHandler:{ request in
   let input=request.sourceImage;let nativeCrop=centreCrop(nativeSize,layout.aspectRatio,picture:sourcePicture);let crop=CGRect(x:nativeCrop.minX/nativeSize.width*input.extent.width,y:nativeCrop.minY/nativeSize.height*input.extent.height,width:nativeCrop.width/nativeSize.width*input.extent.width,height:nativeCrop.height/nativeSize.height*input.extent.height).offsetBy(dx:input.extent.minX,dy:input.extent.minY);let bounds=CGRect(origin:.zero,size:target);let sx=target.width/crop.width,sy=target.height/crop.height;var image=input.cropped(to:crop).transformed(by:CGAffineTransform(translationX:-crop.minX,y:-crop.minY)).applyingFilter("CILanczosScaleTransform",parameters:[kCIInputScaleKey:sy,kCIInputAspectRatioKey:sx/sy])
   let values=valuesAt(CMTimeGetSeconds(request.compositionTime),cues)

   if let renderer=renderer,!frames.isEmpty{image=renderer.layer(CMTimeGetSeconds(request.compositionTime),frames,layout.cells ?? [:],bounds.width,bounds.height).composited(over:image)}
   if let renderer=renderer{image=renderer.customLayer(layout.visuals?.first{$0.kind=="Custom"},target).composited(over:image)}
   let textValue=telemetryLine(values,widgets)
   if !textValue.isEmpty && layout.telemetryHidden != true{
    let w=layout.line;let text=cache.image(w,textValue,bounds.height);let pad=max(3,bounds.height/360)
    let x=bounds.minX+lineX(layout,textValue,bounds.width,bounds.height)-pad;let y=bounds.maxY-w.y*bounds.height-text.extent.height+pad
    image=text.transformed(by:CGAffineTransform(translationX:x,y:y)).composited(over:image)
   }
   if let overlay=visualsLayer(layout,values,cues,CMTimeGetSeconds(request.compositionTime),target){image=overlay.composited(over:image)}
   request.finish(with:image.cropped(to:bounds),context:nil)
  });composition.renderSize=target
  if let track=asset.tracks(withMediaType:.video).first{
   composition.sourceTrackIDForFrameTiming=track.trackID
   let step=track.minFrameDuration
   if step.isNumeric && CMTimeCompare(step,.zero)>0{composition.frameDuration=step}
   else if track.nominalFrameRate>0{composition.frameDuration=CMTime(seconds:1/Double(track.nominalFrameRate),preferredTimescale:600000)}
  };return composition
 }
 @objc func exportVideo(){if let asset=asset{guard let compatible=compatibleExportLayout(settings.layout,asset) else{return};settings.layout=compatible;codec.selectItem(withTitle:compatible.codec);save()};if batchSources.count>1{beginBatchExport();return};pausePlayback();guard let asset=asset,let source=url,session==nil else{return};guard let (rangeStart,rangeEnd)=chosenRange() else{status.stringValue="Choose valid export start and end times before exporting.";return}
  let p=NSSavePanel();p.allowedContentTypes=[.mpeg4Movie];let proposed=source.deletingLastPathComponent().appendingPathComponent(exportFileName(source,displayPresetName(activePresetName),settings.layout.outputSize ?? "Original",exportDimensions(asset,settings.layout.outputSize ?? "Original",aspect:settings.layout.aspectRatio)));p.nameFieldStringValue=uniqueExportURL(proposed).lastPathComponent;p.directoryURL=source.deletingLastPathComponent();guard p.runModal() == .OK,let chosen=p.url else{return};let destination=uniqueExportURL(chosen)
  guard destination.resolvingSymlinksInPath().standardizedFileURL != source.resolvingSymlinksInPath().standardizedFileURL && destination.resolvingSymlinksInPath().standardizedFileURL != lastSRT?.resolvingSymlinksInPath().standardizedFileURL else{status.stringValue="Choose a new filename. Original media cannot be overwritten.";return}
  let preset=settings.layout.codec == "HEVC" ? AVAssetExportPresetHEVCHighestQuality:AVAssetExportPresetHighestQuality
  guard let s=AVAssetExportSession(asset:asset,presetName:preset) else{status.stringValue="This export format is unavailable for the video.";return}
  guard s.supportedFileTypes.contains(.mp4) else{status.stringValue="MP4 export is unavailable for this source.";return}
  let temp=destination.deletingLastPathComponent().appendingPathComponent("P1-export-\(UUID().uuidString).mp4");outputTemp=temp;s.outputURL=temp;s.outputFileType = .mp4;s.timeRange=CMTimeRange(start:CMTime(seconds:rangeStart,preferredTimescale:60000),duration:CMTime(seconds:rangeEnd-rangeStart,preferredTimescale:60000));s.shouldOptimizeForNetworkUse=true;s.videoComposition=composition(asset,widgets:settings.layout.widgets,cues:cues);session=s;bar.doubleValue=0;exportPercent.stringValue="0%";status.stringValue="Starting export… Your layout has been captured for this render.";updateEnabled();let began=Date()
  progressTimer=Timer.scheduledTimer(withTimeInterval:0.5,repeats:true){[weak self] _ in guard let self=self else{return};let progress=Double(s.progress);self.bar.doubleValue=progress*100;self.exportPercent.stringValue=String(format:"%.0f%%",progress*100);let elapsed=Date().timeIntervalSince(began);let eta=progress>0.01 ? " • about \(self.clock(elapsed*(1-progress)/progress)) remaining":" • estimating time remaining";self.status.stringValue=String(format:"Exporting %.0f%%",progress*100)+eta}
  s.exportAsynchronously {DispatchQueue.main.async{self.progressTimer?.invalidate();self.progressTimer=nil;self.session=nil;self.outputTemp=nil
   if s.status == .completed {do{let finishedDestination=uniqueExportURL(destination);try FileManager.default.moveItem(at:temp,to:finishedDestination);self.bar.doubleValue=100;self.status.stringValue="Export complete: \(finishedDestination.lastPathComponent). Original files unchanged.";NSWorkspace.shared.activateFileViewerSelecting([finishedDestination])}catch{self.status.stringValue="Export rendered, but couldn’t move it: \(error.localizedDescription). Temporary file: \(temp.path)"}}
   else {try? FileManager.default.removeItem(at:temp);self.status.stringValue=s.status == .cancelled ? "Export cancelled. Original files unchanged.":"Export failed: \(s.error?.localizedDescription ?? "Unknown error")"};self.updateEnabled()
  }}
 }
 @objc func cancelExport(){if batchRunning{batchCancelled=true};session?.cancelExport()}
}
