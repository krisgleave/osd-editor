// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech) — original Swift implementation and modifications.
import Cocoa
import CoreText
struct LibraryFont:Codable{
 var id:String;var name:String;var kind:String;var file:String;var postScriptName:String?
}
struct SharedPreset:Codable{
 var format="OSDEditorPreset";var version=1;var name:String;var layout:Layout
 var osdFontName:String?;var textFontName:String?
}
func presetIsValid(_ l:Layout)->Bool{
 if let visuals=l.visuals{guard (visuals.count==3 && Set(visuals.map{$0.kind})==Set(["Battery","Signal","Bitrate"])) || (visuals.count==4 && visuals.map{$0.kind}==["SBat","Signal","Bitrate","GBat"]) || (visuals.count==5 && visuals.map{$0.kind}==["SBat","Signal","Bitrate","GBat","Distance"]) || (visuals.count==6 && visuals.map{$0.kind}==["SBat","Signal","Bitrate","GBat","Distance","Custom"]) else{return false};for v in visuals{if let text=v.text,text.count>32 || !text.unicodeScalars.allSatisfy({(32...90).contains(Int($0.value))}){return false};if let tint=v.tint,tint.count != 3 || !tint.allSatisfy({$0.isFinite && (0...1).contains($0)}){return false};guard v.x.isFinite,v.y.isFinite,(0...1).contains(v.x),(0...1).contains(v.y),v.scale.isFinite,(0.2...2.5).contains(v.scale) else{return false}}}
 if let source=l.batterySource,!["SBat","GBat"].contains(source){return false}
 if let cells=l.batteryCells,!(1...8).contains(cells){return false}
 let thresholds=[l.batteryRed ?? 3.5,l.batteryGreen ?? 3.75,l.bitrateRed ?? 4,l.bitrateGreen ?? 12];guard thresholds.allSatisfy({$0.isFinite && $0>0}),thresholds[0]<thresholds[1],thresholds[2]<thresholds[3] else{return false}

 if let aspect=l.referenceAspect,!["4:3","16:9","Source"].contains(aspect){return false}
 if let aspect=l.aspectRatio,!["4:3","16:9"].contains(aspect){return false}
 if let size=l.outputSize,!["Original","2K · 1440p","4K · 2160p"].contains(size){return false}
 let fields=Set(l.widgets.map{$0.field})
 guard l.widgets.count==8,fields==Set(fieldNames),["H.264","HEVC"].contains(l.codec),["Light","Dark","System"].contains(l.theme) else{return false}
 for w in l.widgets+[l.line]{
  guard w.x.isFinite,w.y.isFinite,abs(w.x)<=10,abs(w.y)<=10,w.size.isFinite,(1...200).contains(w.size),[w.red,w.green,w.blue].allSatisfy({$0.isFinite && (0...1).contains($0)}) else{return false}
 }
 for (key,c) in l.cells ?? [:]{
  guard let id=Int(key),(0..<1060).contains(id),c.dx.isFinite,c.dy.isFinite,abs(c.dx)<=10,abs(c.dy)<=10,c.scale.isFinite,(0.1...8).contains(c.scale) else{return false}
  if let aspect=c.aspectX, !aspect.isFinite || !(0.05...20).contains(aspect){return false}
  if let tint=c.tint{guard tint.count==3,tint.allSatisfy({$0.isFinite && (0...1).contains($0)}) else{return false}}
 }
 for r in l.regions{
  guard r.col>=0,r.row>=0,r.columns>0,r.rows>0,r.col+r.columns<=53,r.row+r.rows<=20,r.dx.isFinite,r.dy.isFinite else{return false}
 }
 if let n=l.gridColumns,![16,24,32,48,64,96].contains(n){return false}
 return true
}
func libraryTextFont(_ name:String?,_ size:CGFloat)->NSFont{
 switch name ?? "builtin:mono" {
 case "builtin:mono":return .monospacedSystemFont(ofSize:size,weight:.semibold)
 case "builtin:sans":return .systemFont(ofSize:size,weight:.semibold)
 case "builtin:serif":return NSFont(name:"Georgia",size:size) ?? .systemFont(ofSize:size)
 default:return NSFont(name:name!,size:size) ?? .monospacedSystemFont(ofSize:size,weight:.semibold)
 }
}
func registerTextFont(_ url:URL)throws->String{
 var error:Unmanaged<CFError>?
 if !CTFontManagerRegisterFontsForURL(url as CFURL,.process,&error){
  if let names=CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],let first=names.first,let name=CTFontDescriptorCopyAttribute(first,kCTFontNameAttribute) as? String,NSFont(name:name,size:12) != nil{return name}
  throw error?.takeRetainedValue() ?? NSError(domain:"Font",code:1,userInfo:[NSLocalizedDescriptionKey:"Couldn’t register this text font."])
 }
 guard let descriptors=CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],let first=descriptors.first,let name=CTFontDescriptorCopyAttribute(first,kCTFontNameAttribute) as? String else{throw NSError(domain:"Font",code:2,userInfo:[NSLocalizedDescriptionKey:"No usable typeface found in this file."])}
 return name
}
func snappedOrigin(_ point:CGPoint,_ columns:Int,_ aspect:Double)->CGPoint{
 let dx=1/Double(columns),dy=aspect/Double(columns)
 return CGPoint(x:(point.x/dx).rounded()*dx,y:(point.y/dy).rounded()*dy)
}
