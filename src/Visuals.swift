// SPDX-License-Identifier: GPL-3.0-or-later
import Cocoa
import CoreImage
struct TelemetryVisual:Codable {
 var text:String?;var tint:[Double]?;var kind:String;var hidden:Bool?;var enabled=false;var x:Double;var y:Double;var scale:Double=1
}
func defaultVisuals()->[TelemetryVisual]{[TelemetryVisual(kind:"SBat",x:0.05,y:0.72),TelemetryVisual(kind:"Signal",x:0.05,y:0.57),TelemetryVisual(kind:"Bitrate",x:0.72,y:0.72),TelemetryVisual(kind:"GBat",x:0.72,y:0.57),TelemetryVisual(kind:"Distance",x:0.72,y:0.42),TelemetryVisual(text:"MY DRONE",kind:"Custom",x:0.40,y:0.12)]}
func reading(_ value:String?)->Double?{guard let value=value else{return nil};return Double(value.prefix{ "0123456789.-".contains($0) })}
func bandColour(_ value:Double,_ red:Double,_ green:Double)->NSColor{value < red ? .systemRed:(value < green ? .systemOrange:.systemGreen)}
func visualRect(_ visual:TelemetryVisual,_ canvas:CGRect)->CGRect{if visual.kind=="Custom"{return CGRect(x:canvas.minX+visual.x*canvas.width,y:canvas.minY+visual.y*canvas.height,width:canvas.width*36/1920*visual.scale*Double((visual.text ?? "MY DRONE").count),height:canvas.height*0.05*visual.scale)};let height=canvas.height*0.13*visual.scale;let width=height*2.2;return CGRect(x:canvas.minX+visual.x*canvas.width,y:canvas.minY+visual.y*canvas.height,width:width,height:height)}
func drawVisuals(_ layout:Layout,_ values:[String:String],_ cues:[Cue],_ time:Double,_ canvas:CGRect,preview:Bool=false){
 for v in layout.visuals ?? defaultVisuals() where v.kind != "Custom" && v.enabled && (preview || v.hidden != true) {
  let box=visualRect(v,canvas);let u=box.height/100
  NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
  if v.hidden == true{NSGraphicsContext.current?.cgContext.setAlpha(0.25)}
  NSColor.black.withAlphaComponent(0.70).setFill();NSBezierPath(roundedRect:box,xRadius:8*u,yRadius:8*u).fill()
  func text(_ value:String,_ x:Double,_ y:Double,_ size:Double,_ colour:NSColor = .white){(value as NSString).draw(at:CGPoint(x:box.minX+x*u,y:box.minY+y*u),withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:size*u,weight:.semibold),.foregroundColor:colour])}
  switch v.kind {
  case "Battery","SBat","GBat":
   let source=v.kind=="GBat" ? "GBat":"SBat",cells=1;let voltage=reading(values[source]);let perCell=voltage.map{$0/Double(cells)};let colour=perCell.map{bandColour($0,layout.batteryRed ?? 3.5,layout.batteryGreen ?? 3.75)} ?? .gray
   text(source,12,8,14)
   let battery=CGRect(x:box.minX+14*u,y:box.minY+37*u,width:65*u,height:39*u);colour.setStroke();let outline=NSBezierPath(roundedRect:battery,xRadius:4*u,yRadius:4*u);outline.lineWidth=3*u;outline.stroke();colour.setFill();NSBezierPath(rect:CGRect(x:battery.maxX+2*u,y:battery.minY+12*u,width:5*u,height:15*u)).fill()
   if let p=perCell{let fraction=max(0,min(1,(p-3.2)/(4.35-3.2)));NSBezierPath(rect:CGRect(x:battery.minX+5*u,y:battery.minY+5*u,width:55*u*fraction,height:29*u)).fill()}
   text(voltage.map{String(format:"%.2f V",$0)} ?? "— V",94,42,23,colour)
  case "Signal":
   let level=reading(values["Signal"]);let colour=level.map{bandColour($0,2,4)} ?? .gray;text("VIDEO SIGNAL",12,8,14)
   for i in 0..<4{let h=Double(i+1)*11;((level ?? 0)>=Double(i+1) ? colour:NSColor.gray.withAlphaComponent(0.35)).setFill();NSBezierPath(roundedRect:CGRect(x:box.minX+(14+Double(i)*18)*u,y:box.minY+(85-h)*u,width:12*u,height:h*u),xRadius:2*u,yRadius:2*u).fill()}
   text(level.map{String(format:"%.0f / 4",$0)} ?? "— / 4",104,44,23,colour)
  case "Distance":
   text("DISTANCE",12,8,14)
   let distance=reading(values["Distance"])
   let ink=NSColor.systemYellow
   func pin(_ x:CGFloat,_ y:CGFloat){let centre=CGPoint(x:box.minX+x*u,y:box.minY+y*u);let path=NSBezierPath();path.move(to:CGPoint(x:centre.x,y:centre.y+24*u));path.curve(to:CGPoint(x:centre.x-13*u,y:centre.y),controlPoint1:CGPoint(x:centre.x-5*u,y:centre.y+17*u),controlPoint2:CGPoint(x:centre.x-13*u,y:centre.y+8*u));path.curve(to:CGPoint(x:centre.x+13*u,y:centre.y),controlPoint1:CGPoint(x:centre.x-13*u,y:centre.y-18*u),controlPoint2:CGPoint(x:centre.x+13*u,y:centre.y-18*u));path.curve(to:CGPoint(x:centre.x,y:centre.y+24*u),controlPoint1:CGPoint(x:centre.x+13*u,y:centre.y+8*u),controlPoint2:CGPoint(x:centre.x+5*u,y:centre.y+17*u));path.close();ink.setFill();path.fill();NSColor.black.setFill();NSBezierPath(ovalIn:CGRect(x:centre.x-5*u,y:centre.y-6*u,width:10*u,height:10*u)).fill()}
   pin(25,44);pin(68,60)
   let route=NSBezierPath();route.move(to:CGPoint(x:box.minX+25*u,y:box.minY+71*u));route.curve(to:CGPoint(x:box.minX+61*u,y:box.minY+87*u),controlPoint1:CGPoint(x:box.minX+51*u,y:box.minY+63*u),controlPoint2:CGPoint(x:box.minX+31*u,y:box.minY+92*u));route.setLineDash([4*u,4*u],count:2,phase:0);route.lineWidth=2.5*u;route.lineCapStyle = .round;ink.setStroke();route.stroke()
   text(distance.map{String(format:"%.0f m",$0)} ?? "— m",90,41,25)
  default:
   let rate=reading(values["Bitrate"]);let colour=rate.map{bandColour($0,layout.bitrateRed ?? 4,layout.bitrateGreen ?? 12)} ?? .gray;text("BITRATE",12,6,14);text(rate.map{String(format:"%.1f Mbps",$0)} ?? "— Mbps",12,25,20,colour)
   let graph=CGRect(x:box.minX+12*u,y:box.minY+55*u,width:box.width-24*u,height:33*u);let samples=cues.filter{$0.start>=max(0,time-10) && $0.start<=time};let path=NSBezierPath();var first=true
   for cue in samples{guard let n=reading(cue.values["Bitrate"]) else{first=true;continue};let point=CGPoint(x:graph.minX+(cue.start-(time-10))/10*graph.width,y:graph.maxY-max(0,min(1,n/21))*graph.height);if first{path.move(to:point);first=false}else{path.line(to:point)}}
   colour.setStroke();path.lineWidth=2*u;path.stroke()
  }
 }
}
func visualsLayer(_ layout:Layout,_ values:[String:String],_ cues:[Cue],_ time:Double,_ size:CGSize)->CIImage? {
 guard (layout.visuals ?? []).contains(where:{$0.enabled}),let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(size.width),pixelsHigh:Int(size.height),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),let context=NSGraphicsContext(bitmapImageRep:bitmap) else{return nil}
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:context.cgContext,flipped:true);context.cgContext.translateBy(x:0,y:size.height);context.cgContext.scaleBy(x:1,y:-1);drawVisuals(layout,values,cues,time,CGRect(origin:.zero,size:size));NSGraphicsContext.restoreGraphicsState();return bitmap.cgImage.map{CIImage(cgImage:$0)}
}
extension App {
 func buildVisualControls()->NSView {
  let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8;stack.widthAnchor.constraint(equalToConstant:312).isActive=true
  let toggles=NSStackView();toggles.spacing=12
  for (i,name) in ["SBat","Signal","Bitrate","GBat","Distance"].enumerated(){let check=NSButton(checkboxWithTitle:name,target:self,action:#selector(visualToggle(_:)));check.font = .systemFont(ofSize:11);check.tag=i;visualChecks.append(check);toggles.addArrangedSubview(check)}
  let checkRows=NSStackView();checkRows.orientation = .vertical;checkRows.alignment = .leading;checkRows.spacing=6
  for pair in [[0,3,1],[2,4]]{let row=NSStackView();row.spacing=6;for i in pair{toggles.removeArrangedSubview(visualChecks[i]);visualChecks[i].removeFromSuperview();row.addArrangedSubview(visualChecks[i]);visualChecks[i].widthAnchor.constraint(equalToConstant:98).isActive=true};checkRows.addArrangedSubview(row)}
  stack.addArrangedSubview(checkRows)

  let custom=NSButton(checkboxWithTitle:"Custom OSD text",target:self,action:#selector(customTextToggle(_:)));customTextCheck=custom;stack.addArrangedSubview(custom)
  let entry=NSTextField(string:settings.layout.visuals?.first(where:{$0.kind=="Custom"})?.text ?? "MY DRONE");entry.placeholderString="Drone name";entry.target=self;entry.action=#selector(customTextEdited(_:));entry.widthAnchor.constraint(equalToConstant:290).isActive=true;entry.toolTip="Uppercase letters, numbers and punctuation, up to 32 characters. Uses the selected OSD PNG font. Press Return to apply.";customTextEntry=entry;stack.addArrangedSubview(entry)
  func thresholdLabel(_ text:String,_ colour:NSColor = .labelColor)->NSTextField{let label=NSTextField(labelWithString:text);label.font = .systemFont(ofSize:11);label.textColor=colour;return label}
  let redHeader=thresholdLabel("RED · Below",.systemRed),greenHeader=thresholdLabel("GREEN · From",.systemGreen)
  let grid=NSGridView(views:[[thresholdLabel(""),redHeader,greenHeader]])
  grid.columnSpacing=10;grid.rowSpacing=7;grid.xPlacement = .leading;grid.yPlacement = .center
  var fields=[Int:NSTextField]()
  for (title,redKey,greenKey,red,green) in [("Battery (V)",0,1,3.5,3.75),("Bitrate (Mbps)",2,3,4.0,12.0)]{
   func field(_ key:Int,_ value:Double)->NSTextField{let f=NSTextField(string:String(value));f.tag=key;f.target=self;f.action=#selector(visualThreshold(_:));f.widthAnchor.constraint(equalToConstant:76).isActive=true;fields[key]=f;return f}
   grid.addRow(with:[thresholdLabel(title),field(redKey,red),field(greenKey,green)])
  }
  visualThresholds=(0..<4).compactMap{fields[$0]};stack.addArrangedSubview(grid)
  let amber=thresholdLabel("Amber between these values",.secondaryLabelColor);stack.addArrangedSubview(amber)

  return stack
 }
 func refreshVisualControls(){customTextCheck?.state=settings.layout.visuals?.first(where:{$0.kind=="Custom"})?.enabled == true ? .on:.off;customTextEntry?.stringValue=settings.layout.visuals?.first(where:{$0.kind=="Custom"})?.text ?? "MY DRONE";let visuals=settings.layout.visuals ?? defaultVisuals();for i in 0..<min(visuals.count,visualChecks.count){visualChecks[i].state=visuals[i].enabled ? .on:.off;};visualSliders.first?.doubleValue=visuals.first?.scale ?? 1;batteryVisualSource?.selectItem(withTitle:settings.layout.batterySource ?? "SBat");batteryVisualCells?.selectItem(at:max(0,min(7,(settings.layout.batteryCells ?? 1)-1)));let values=[settings.layout.batteryRed ?? 3.5,settings.layout.batteryGreen ?? 3.75,settings.layout.bitrateRed ?? 4,settings.layout.bitrateGreen ?? 12];for (i,f) in visualThresholds.enumerated(){f.doubleValue=values[i]}}
 func ensureCustomText(){var visuals=settings.layout.visuals ?? defaultVisuals();if !visuals.contains(where:{$0.kind=="Custom"}){visuals.append(defaultVisuals()[5])};settings.layout.visuals=visuals}
 @objc func customTextToggle(_ sender:NSButton){ensureCustomText();let i=settings.layout.visuals!.firstIndex{$0.kind=="Custom"}!;settings.layout.visuals![i].enabled=sender.state == .on;save();syncPreview();selectionChanged()}
 @objc func customTextEdited(_ sender:NSTextField){ensureCustomText();let filtered=String(sender.stringValue.uppercased().unicodeScalars.filter{(32...90).contains(Int($0.value))}.prefix(32));sender.stringValue=filtered;let i=settings.layout.visuals!.firstIndex{$0.kind=="Custom"}!;settings.layout.visuals![i].text=filtered;save();syncPreview();selectionChanged()}
 @objc func visualToggle(_ sender:NSButton){var v=settings.layout.visuals ?? defaultVisuals();v[sender.tag].enabled=sender.state == .on;settings.layout.visuals=v;save();syncPreview();selectionChanged()}
 @objc func visualScale(_ sender:NSSlider){var v=settings.layout.visuals ?? defaultVisuals();let canvas=CGRect(origin:.zero,size:preview.canvasSize);for i in v.indices{v[i].scale=sender.doubleValue;let box=visualRect(v[i],canvas);v[i].x=min(v[i].x,max(0,1-box.width/canvas.width));v[i].y=min(v[i].y,max(0,1-box.height/canvas.height))};settings.layout.visuals=v;save();syncPreview()}

 @objc func visualSource(_ sender:NSPopUpButton){settings.layout.batterySource=sender.titleOfSelectedItem;save();syncPreview()}
 @objc func visualCells(_ sender:NSPopUpButton){settings.layout.batteryCells=sender.indexOfSelectedItem+1;save();syncPreview()}
 @objc func visualThreshold(_ sender:NSTextField){let n=sender.doubleValue;guard n.isFinite,n>0 else{refreshVisualControls();return};var red=settings.layout.batteryRed ?? 3.5,green=settings.layout.batteryGreen ?? 3.75,br=settings.layout.bitrateRed ?? 4,bg=settings.layout.bitrateGreen ?? 12;switch sender.tag{case 0:red=n;case 1:green=n;case 2:br=n;default:bg=n};guard red<green,br<bg else{refreshVisualControls();return};settings.layout.batteryRed=red;settings.layout.batteryGreen=green;settings.layout.bitrateRed=br;settings.layout.bitrateGreen=bg;save();syncPreview()}
}
