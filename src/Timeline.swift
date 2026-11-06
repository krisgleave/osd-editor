// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech) — original Swift implementation and modifications.
import Cocoa
final class TrimTimeline:NSView {
 var duration=0.0;var start=0.0;var end=0.0;var playhead=0.0
 var onSeek:((Double)->Void)?;var onRange:((Double,Double)->Void)?
 var trimmingEnabled=true;var dragging=0
 override var isFlipped:Bool{true}
 var track:NSRect{NSRect(x:10,y:12,width:max(1,bounds.width-20),height:20)}
 func x(_ time:Double)->CGFloat{track.minX+CGFloat(duration>0 ? time/duration:0)*track.width}
 override func draw(_ dirtyRect:NSRect){
  NSColor.controlBackgroundColor.setFill();NSBezierPath(roundedRect:track,xRadius:5,yRadius:5).fill()
  guard duration>0 else{return}
  let selected=NSRect(x:x(start),y:track.minY,width:max(1,x(end)-x(start)),height:track.height)
  NSColor.systemBlue.withAlphaComponent(0.3).setFill();selected.fill()
  for (time,label) in [(start,"IN"),(end,"OUT")]{
   NSColor.systemBlue.setFill();NSRect(x:x(time)-4,y:track.minY-3,width:8,height:track.height+6).fill()
   (label as NSString).draw(at:NSPoint(x:max(0,min(bounds.width-26,x(time)-10)),y:34),withAttributes:[.font:NSFont.systemFont(ofSize:9,weight:.semibold),.foregroundColor:NSColor.secondaryLabelColor])
  }
  NSColor.labelColor.setFill();NSRect(x:x(playhead)-1,y:track.minY-5,width:2,height:track.height+10).fill()
 }
 override func mouseDown(with event:NSEvent){
  guard duration>0 else{return};let p=convert(event.locationInWindow,from:nil)
  let ds=abs(p.x-x(start)),de=abs(p.x-x(end));dragging=trimmingEnabled && min(ds,de)<9 ? (ds<=de ? 1:2):3
  mouseDragged(with:event)
 }
 override func mouseDragged(with event:NSEvent){
  guard duration>0 else{return};let p=convert(event.locationInWindow,from:nil);let t=max(0,min(duration,Double((p.x-track.minX)/track.width)*duration))
  if dragging==1{start=min(t,max(0,end-0.001));onRange?(start,end)}
  else if dragging==2{end=max(t,min(duration,start+0.001));onRange?(start,end)}
  else{playhead=t;onSeek?(t)}
  needsDisplay=true
 }
 override func mouseUp(with event:NSEvent){dragging=0}
}
