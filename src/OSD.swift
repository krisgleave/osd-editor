// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech) — original Swift implementation and modifications.
// OSD parser adapted from Walksnail OSD Tool (GPL-3.0):
// Alexander van Saase and contributors; Artlynk implementation by ksielick and contributors.
// Modified/reimplemented in Swift on 2026-11-05/06. See THIRD_PARTY_NOTICES.md for provenance.
import Cocoa
import AVFoundation
import CoreImage
struct Glyph {var x:Int;var y:Int;var index:Int}
struct OSDFrame {var time:Double;var glyphs:[Glyph];var runs:[Set<Int>]=[]}
struct Region:Codable {
 var name:String;var col:Int;var row:Int;var columns:Int;var rows:Int
 var dx:Double=0;var dy:Double=0;var hidden=false
 func contains(_ g:Glyph)->Bool{g.x>=col && g.x<col+columns && g.y>=row && g.y<row+rows}
}
func osdAt(_ t:Double,_ frames:[OSDFrame])->[Glyph]{
 var l=0;var h=frames.count
 while l<h{let m=(l+h)/2;if frames[m].time<=t+0.001{l=m+1}else{h=m}}
 return l>0 ? frames[l-1].glyphs:[]
}
func readOSD(_ url:URL)throws->[OSDFrame] {
 let b=[UInt8](try Data(contentsOf:url));guard b.count>=40,(b.count-40)%2124==0 else{throw NSError(domain:"OSD",code:1,userInfo:[NSLocalizedDescriptionKey:"Unrecognised OSD file format."])}
 var frames=[OSDFrame]()
 for p in stride(from:40,to:b.count,by:2124){
  let ts=(0..<4).reduce(UInt32(0)){$0 | UInt32(b[p+$1]) << ($1*8)}
  var glyphs=[Glyph]()
  for i in 0..<1060{let j=p+4+i*2;let n=Int(b[j])+Int(b[j+1])*256;if n != 0 && n != 32{glyphs.append(Glyph(x:i%53,y:i/53,index:n))}}
  frames.append(OSDFrame(time:Double(ts)/1000,glyphs:glyphs))
 };return frames.sorted{$0.time<$1.time}
}
func parseArtlynk(_ raw:[UInt8],runs:inout [Set<Int>])->[Glyph]{
 let d=raw.enumerated().compactMap{($0.offset+1)%3 == 0 ? nil:$0.element}
 guard d.count>=10 else{return []}
 let offsets=(0..<d.count-1).filter{d[$0]==0xb6 && d[$0+1]==3}
 var glyphs=[Glyph]()
 for (i,p) in offsets.enumerated(){
  guard p+5<=d.count else{continue};let row=Int(d[p+2]),col=Int(d[p+3]),page=Int(d[p+4]&3)*256
  let end=i+1<offsets.count ? offsets[i+1]-1:d.count
  var run=Set<Int>()
  if p+5<end{for j in p+5..<end{let x=col+j-p-5,n=page+Int(d[j]);if row<20 && x<53 && n != 0 && n != 32{glyphs.append(Glyph(x:x,y:row,index:n));run.insert(row*53+x)}}};if !run.isEmpty{runs.append(run)}
 };return glyphs
}
func extractOSD(_ url:URL)throws->[OSDFrame]{
 let asset=AVURLAsset(url:url);guard let track=asset.tracks(withMediaType:.video).first else{return []}
 let reader=try AVAssetReader(asset:asset);let output=AVAssetReaderTrackOutput(track:track,outputSettings:nil);output.alwaysCopiesSampleData=false;reader.add(output)
 guard reader.startReading() else{throw reader.error ?? NSError(domain:"OSD",code:2)}
 var frames=[OSDFrame]()
 while let sample=output.copyNextSampleBuffer(){
  guard let block=CMSampleBufferGetDataBuffer(sample) else{continue};let count=CMBlockBufferGetDataLength(block);var bytes=[UInt8](repeating:0,count:count)
  CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:count,destination:&bytes)
  var p=0
  while p+4<=bytes.count {
   let n=bytes[p..<p+4].reduce(0){$0*256+Int($1)};p+=4;guard n>0,p+n<=bytes.count else{break}
   if bytes[p]&31 == 6{
    // H.264 SEI RBSP, remove emulation-prevention bytes.
    var rbsp=[UInt8]();var zeros=0
    for v in bytes[p+1..<p+n]{if zeros>=2 && v==3{zeros=0;continue};rbsp.append(v);zeros=v==0 ? zeros+1:0}
    var q=0
    while q+2<=rbsp.count{
     var type=0;while q<rbsp.count && rbsp[q]==255{type+=255;q+=1};guard q<rbsp.count else{break};type+=Int(rbsp[q]);q+=1
     var size=0;while q<rbsp.count && rbsp[q]==255{size+=255;q+=1};guard q<rbsp.count else{break};size+=Int(rbsp[q]);q+=1
     guard q+size<=rbsp.count else{break}
     if type==5 && size>16{var runs=[Set<Int>]();let glyphs=parseArtlynk(Array(rbsp[q+16..<q+size]),runs:&runs);if !glyphs.isEmpty{frames.append(OSDFrame(time:CMSampleBufferGetPresentationTimeStamp(sample).seconds,glyphs:glyphs,runs:runs))}}
     q+=size
    }
   };p+=n
  }
 }
 if reader.status == .failed{throw reader.error ?? NSError(domain:"OSD",code:3)}
 return frames.sorted{$0.time<$1.time}
}
struct CellStyle:Codable {
 var dx:Double=0;var dy:Double=0;var scale:Double=1;var hidden=false
 var aspectX:Double?;var tint:[Double]?
}
func cellRect(_ id:Int,_ styles:[String:CellStyle])->CGRect {
 let s=styles[String(id)] ?? CellStyle()
 return CGRect(x:Double(id%53)*36/1920+s.dx,y:Double(id/53)/20+s.dy,width:36/1920*s.scale*(s.aspectX ?? 1),height:0.05*s.scale)
}
func cellBounds(_ ids:Set<Int>,_ styles:[String:CellStyle])->CGRect{
 ids.reduce(CGRect.null){$0.union(cellRect($1,styles))}
}
func scaleCells(_ ids:Set<Int>,_ styles:inout [String:CellStyle],_ requested:Double){
 guard !ids.isEmpty else{return}
 let bounds=cellBounds(ids,styles);let cx=bounds.midX,cy=bounds.midY
 let minimum=ids.map{(styles[String($0)] ?? CellStyle()).scale}.min()!
 let maximum=ids.map{(styles[String($0)] ?? CellStyle()).scale}.max()!
 let factor=max(0.1/minimum,min(8/maximum,requested))
 for id in ids {
  var s=styles[String(id)] ?? CellStyle();let r=cellRect(id,styles)
  s.dx=cx+(r.minX-cx)*factor-Double(id%53)*36/1920
  s.dy=cy+(r.minY-cy)*factor-Double(id/53)/20
  s.scale *= factor;styles[String(id)]=s
 }
}
func moveCells(_ ids:Set<Int>,_ styles:inout [String:CellStyle],_ dx:Double,_ dy:Double){
 for id in ids{var s=styles[String(id)] ?? CellStyle();s.dx+=dx;s.dy+=dy;styles[String(id)]=s}
}
func detectedGroups(_ ids:Set<Int>,_ styles:[String:CellStyle],includeHidden:Bool=false)->[Set<Int>]{
 var remaining=ids.filter{includeHidden || !(styles[String($0)]?.hidden ?? false)};var result=[Set<Int>]()
 while let first=remaining.first{
  var group:Set<Int>=[first];remaining.remove(first);var queue=[first]
  while let id=queue.popLast(){
   let box=cellRect(id,styles)
   let neighbours=remaining.filter{
    let other=cellRect($0,styles)
    let sameRow=abs(box.midY-other.midY)<min(box.height,other.height)*0.2
    let gap=max(0,max(box.minX-other.maxX,other.minX-box.maxX))
    return sameRow && gap<=max(box.width,other.width)*1.05
   }
   for n in neighbours{remaining.remove(n);group.insert(n);queue.append(n)}
  };result.append(group)
 };return result
}
func recordingElements(_ frames:[OSDFrame])->[Set<Int>]{
 var runs=[Int:Set<Int>]()
 for frame in frames{for run in frame.runs{guard let first=run.min() else{continue};runs[first,default:[]].formUnion(run)}}
 if !runs.isEmpty{return runs.values.sorted{($0.min() ?? 0)<($1.min() ?? 0)}}
 return detectedGroups(Set(frames.flatMap{$0.glyphs.map{$0.y*53+$0.x}}),[:],includeHidden:true)
}
final class OSDRenderer {
 let glyphs:[CIImage];let context=CIContext(options:[.cacheIntermediates:false])
 init(_ url:URL)throws{
  guard let source=NSImage(contentsOf:url),let cg=source.cgImage(forProposedRect:nil,context:nil,hints:nil) else{throw NSError(domain:"Font",code:1,userInfo:[NSLocalizedDescriptionKey:"Couldn’t open the PNG font."])}
  let widths=[18,24,36,48,72].sorted{($0==cg.width ? 0:1)<($1==cg.width ? 0:1)};var cell=0
  for w in widths where cg.width%w==0 && cg.width/w<=4 && cg.height%(w*3/2*256)==0{cell=w;break}
  guard cell>0 else{throw NSError(domain:"Font",code:2,userInfo:[NSLocalizedDescriptionKey:"Choose a Walksnail font PNG such as WS_BTFL_Nexus_36.png."])}
  let height=cell*3/2,rows=cg.height/height,pages=cg.width/cell
  var images=[CIImage]()
  for page in 0..<pages{for row in 0..<rows{
   let crop=cg.cropping(to:CGRect(x:page*cell,y:row*height,width:cell,height:height))!
   images.append(CIImage(cgImage:crop).transformed(by:CGAffineTransform(scaleX:36/CGFloat(cell),y:54/CGFloat(height))))
  }};glyphs=images
 }
 func layer(_ time:Double,_ frames:[OSDFrame],_ styles:[String:CellStyle],_ width:CGFloat,_ height:CGFloat,showHidden:Bool=false)->CIImage {
  var image=CIImage.empty();let cw=width/1920*36,ch=height/1080*54
  for g in osdAt(time,frames) where g.index<glyphs.count{
   let style=styles[String(g.y*53+g.x)] ?? CellStyle();if style.hidden && !showHidden{continue}
   let x=CGFloat(g.x)*cw+style.dx*width
   let y=height-CGFloat(g.y)*ch-style.dy*height-ch*style.scale
   var glyph=glyphs[g.index]
   if let tint=style.tint,tint.count==3{
    glyph=glyph.applyingFilter("CIColorMatrix",parameters:[
     "inputRVector":CIVector(x:0.2126*tint[0],y:0.7152*tint[0],z:0.0722*tint[0],w:0),
     "inputGVector":CIVector(x:0.2126*tint[1],y:0.7152*tint[1],z:0.0722*tint[1],w:0),
     "inputBVector":CIVector(x:0.2126*tint[2],y:0.7152*tint[2],z:0.0722*tint[2],w:0)])
   }
   if style.hidden{
    glyph=glyph.applyingFilter("CIColorControls",parameters:["inputSaturation":0]).applyingFilter("CIColorMatrix",parameters:["inputAVector":CIVector(x:0,y:0,z:0,w:0.25)])
   }
   glyph=glyph.transformed(by:CGAffineTransform(scaleX:cw/36*style.scale*(style.aspectX ?? 1),y:ch/54*style.scale)).transformed(by:CGAffineTransform(translationX:x,y:y))
   image=glyph.composited(over:image)
  };return image
 }
 func customLayer(_ visual:TelemetryVisual?,_ size:CGSize,_ showHidden:Bool=false)->CIImage {
  guard let v=visual,v.enabled else{return .empty()};let text=v.text ?? "MY DRONE";var styles=[String:CellStyle]();var glyphs=[Glyph]()
  for (i,c) in text.unicodeScalars.enumerated(){guard i<32,(32...90).contains(Int(c.value)) else{continue};glyphs.append(Glyph(x:i,y:0,index:Int(c.value)));styles[String(i)]=CellStyle(dx:v.x+Double(i)*36/1920*(v.scale-1),dy:v.y,scale:v.scale,hidden:v.hidden ?? false,tint:v.tint)}
  return layer(0,[OSDFrame(time:0,glyphs:glyphs)],styles,size.width,size.height,showHidden:showHidden)
 }
 func preview(_ time:Double,_ frames:[OSDFrame],_ styles:[String:CellStyle],_ size:NSSize,custom:TelemetryVisual?=nil)->NSImage?{
  let image=customLayer(custom,size,true).composited(over:layer(time,frames,styles,size.width,size.height,showHidden:true))
  guard let cg=context.createCGImage(image,from:CGRect(origin:.zero,size:size)) else{return nil}
  return NSImage(cgImage:cg,size:size)
 }
}
