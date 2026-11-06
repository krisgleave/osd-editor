// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech) — original Swift implementation and modifications.
import Cocoa
import CoreText
import UniformTypeIdentifiers
extension App{
 var fontDirectory:URL{settingsURL.deletingLastPathComponent().appendingPathComponent("Fonts",isDirectory:true)}
 func fontURL(_ f:LibraryFont)->URL{fontDirectory.appendingPathComponent(URL(fileURLWithPath:f.file).lastPathComponent)}
 func fonts(_ kind:String)->[LibraryFont]{(settings.fonts ?? []).filter{$0.kind==kind}.sorted{$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}}
 func libraryError(_ message:String){let a=NSAlert();a.messageText=message;a.runModal()}
 func uniqueName(_ base:String,_ existing:[String])->String{
  let stem=base.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "Untitled":String(base.prefix(120))
  var result=stem;var n=2
  while existing.contains(where:{$0.caseInsensitiveCompare(result) == .orderedSame}){result="\(stem) (\(n))";n+=1};return result
 }
 func bootstrapFontLibrary(){
  try? FileManager.default.createDirectory(at:fontDirectory,withIntermediateDirectories:true)
  if settings.fonts==nil{settings.fonts=[]}
  for f in fonts("text"){_ = try? registerTextFont(fontURL(f))}
  if fonts("osd").isEmpty,let path=settings.fontPath,FileManager.default.fileExists(atPath:path){
   let id=UUID().uuidString;let file=id+".png";let destination=fontDirectory.appendingPathComponent(file)
   do{try Data(contentsOf:URL(fileURLWithPath:path)).write(to:destination);settings.fonts?.append(LibraryFont(id:id,name:"Imported OSD font",kind:"osd",file:file));settings.layout.osdFontID=id;settings.fontPath=destination.path}catch{}
  }
  if settings.legacyOSDFontID==nil{settings.legacyOSDFontID=fonts("osd").first?.id}
  if settings.layout.osdFontID==nil{settings.layout.osdFontID=settings.legacyOSDFontID}
 }
 func selectedFont(_ kind:String)->LibraryFont?{
  let popup=kind=="osd" ? osdFontPopup:textFontPopup
  guard let id=popup.selectedItem?.representedObject as? String else{return nil}
  return (settings.fonts ?? []).first{$0.id==id && $0.kind==kind}
 }
 func refreshFontMenus(){
  osdFontPopup.removeAllItems()
  for f in fonts("osd"){osdFontPopup.addItem(withTitle:FileManager.default.fileExists(atPath:fontURL(f).path) ? f.name:f.name+" (file missing)");osdFontPopup.lastItem?.representedObject=f.id}
  if osdFontPopup.numberOfItems==0{osdFontPopup.addItem(withTitle:"Import an OSD PNG…")}
  if let id=settings.layout.osdFontID,let i=osdFontPopup.itemArray.firstIndex(where:{$0.representedObject as? String==id}){osdFontPopup.selectItem(at:i)}
  textFontPopup.removeAllItems()
  for (name,id) in [("Monospaced (default)","builtin:mono"),("Sans serif","builtin:sans"),("Georgia (serif)","builtin:serif")]{textFontPopup.addItem(withTitle:name);textFontPopup.lastItem?.representedObject=id}
  for (name,id) in extraTextChoices where NSFont(name:id,size:12) != nil{textFontPopup.addItem(withTitle:name);textFontPopup.lastItem?.representedObject=id}
  for f in fonts("text"){textFontPopup.addItem(withTitle:f.name);textFontPopup.lastItem?.representedObject=f.id}
  let textName=settings.layout.line.fontName ?? "builtin:mono"
  if let f=fonts("text").first(where:{$0.postScriptName==textName}),let i=textFontPopup.itemArray.firstIndex(where:{$0.representedObject as? String==f.id}){textFontPopup.selectItem(at:i)}
  else if let i=textFontPopup.itemArray.firstIndex(where:{$0.representedObject as? String==textName}){textFontPopup.selectItem(at:i)}
  osdRename.isEnabled=selectedFont("osd") != nil;osdDelete.isEnabled=osdRename.isEnabled
  textRename.isEnabled=selectedFont("text") != nil;textDelete.isEnabled=textRename.isEnabled
  for (menu,kind) in [(osdFontMenu,"osd"),(textFontMenu,"text")]{for item in menu.itemArray where ["Rename…","Delete"].contains(item.title){item.isEnabled=selectedFont(kind) != nil}}
 }
 func applyOSDFont(){
  let chosen=fonts("osd").first{$0.id==settings.layout.osdFontID} ?? fonts("osd").first
  osdRenderer=nil
  if let f=chosen{do{osdRenderer=try OSDRenderer(fontURL(f));settings.fontPath=fontURL(f).path;fontStatus.stringValue="OSD font: "+f.name}catch{osdRenderer=nil;status.stringValue="OSD font unavailable: "+f.name+". Reimport its PNG from the Fonts menu."}}
  else if let path=settings.fontPath{osdRenderer=try? OSDRenderer(URL(fileURLWithPath:path))}
  refreshFontMenus();syncPreview();updateEnabled()
 }
 @objc func osdFontChanged(){guard let f=selectedFont("osd") else{return};settings.layout.osdFontID=f.id;applyOSDFont();save()}
 @objc func textFontChanged(){
  if let f=selectedFont("text"){settings.layout.line.fontName=f.postScriptName}
  else{settings.layout.line.fontName=textFontPopup.selectedItem?.representedObject as? String}
  refreshFontMenus();save();syncPreview()
 }
 @objc func importFont(){importLibraryFont("osd")}
 @objc func importTextFont(){importLibraryFont("text")}
 func importLibraryFont(_ kind:String){
  guard session==nil else{return};pausePlayback();let p=NSOpenPanel()
  p.allowedContentTypes=kind=="osd" ? [.png]:["ttf","otf"].compactMap{UTType(filenameExtension:$0)}
  guard p.runModal() == .OK,let source=p.url else{return}
  do{
   var postScript:String?
   if kind=="osd"{_ = try OSDRenderer(source)}else{
    postScript=try registerTextFont(source)
    if let existing=fonts("text").first(where:{$0.postScriptName==postScript}){settings.layout.line.fontName=existing.postScriptName;refreshFontMenus();save();syncPreview();status.stringValue="This typeface is already in your library.";return}
   }
   let id=UUID().uuidString,file=id+"."+source.pathExtension.lowercased(),destination=fontDirectory.appendingPathComponent(file)
   try Data(contentsOf:source).write(to:destination,options:.atomic)
   if kind=="text"{var error:Unmanaged<CFError>?;CTFontManagerUnregisterFontsForURL(source as CFURL,.process,&error);postScript=try registerTextFont(destination)}
   let name=uniqueName(source.deletingPathExtension().lastPathComponent,fonts(kind).map{$0.name})
   let f=LibraryFont(id:id,name:name,kind:kind,file:file,postScriptName:postScript);settings.fonts?.append(f)
   if kind=="osd"{settings.layout.osdFontID=id;applyOSDFont()}else{settings.layout.line.fontName=postScript}
   refreshFontMenus();save();syncPreview()
  }catch{libraryError(error.localizedDescription)}
 }
 func promptName(_ title:String,_ initial:String)->String?{
  let a=NSAlert();a.messageText=title;let field=NSTextField(frame:NSRect(x:0,y:0,width:280,height:24));field.stringValue=initial;a.accessoryView=field;a.addButton(withTitle:"Rename");a.addButton(withTitle:"Cancel")
  guard a.runModal() == .alertFirstButtonReturn else{return nil};let name=field.stringValue.trimmingCharacters(in:.whitespacesAndNewlines);return name.isEmpty ? nil:String(name.prefix(120))
 }
 func renameLibraryFont(_ kind:String){
  guard let f=selectedFont(kind),let name=promptName("Rename font",f.name),let i=settings.fonts?.firstIndex(where:{$0.id==f.id}) else{return}
  guard !fonts(kind).contains(where:{$0.id != f.id && $0.name.caseInsensitiveCompare(name) == .orderedSame}) else{libraryError("A font with that name already exists.");return}
  settings.fonts?[i].name=name;refreshFontMenus();save()
 }
 func deleteLibraryFont(_ kind:String){
  guard session==nil,let f=selectedFont(kind) else{return}
  let a=NSAlert();a.messageText="Delete ‘\(f.name)’ from the font library?";a.informativeText="The original imported file is kept. Presets using this font may need another font selected.";a.addButton(withTitle:"Delete");a.addButton(withTitle:"Cancel")
  guard a.runModal() == .alertFirstButtonReturn else{return}
  do{
   if kind=="text"{var error:Unmanaged<CFError>?;CTFontManagerUnregisterFontsForURL(fontURL(f) as CFURL,.process,&error)}
   if FileManager.default.fileExists(atPath:fontURL(f).path){try FileManager.default.trashItem(at:fontURL(f),resultingItemURL:nil)}
   settings.fonts?.removeAll{$0.id==f.id}
   if kind=="osd"{settings.layout.osdFontID=fonts("osd").first?.id;settings.fontPath=nil;osdRenderer=nil;applyOSDFont()}
   else if settings.layout.line.fontName==f.postScriptName{settings.layout.line.fontName=nil}
   refreshFontMenus();save();syncPreview()
  }catch{libraryError(error.localizedDescription)}
 }
 @objc func renameOSDFont(){renameLibraryFont("osd")}
 @objc func renameTextFont(){renameLibraryFont("text")}
 @objc func deleteOSDFont(){deleteLibraryFont("osd")}
 @objc func deleteTextFont(){deleteLibraryFont("text")}
 @discardableResult func renamePresetValue(_ old:String,_ name:String)throws->String{
  guard var value=settings.presets[old],!name.isEmpty,name != "Last settings",name.caseInsensitiveCompare("Default") != .orderedSame else{throw NSError(domain:"Preset",code:1,userInfo:[NSLocalizedDescriptionKey:"Choose a unique preset name."])}
  let ratio=presetAspect(value);if let collision=existingPreset(named:name,aspect:ratio),collision != old{throw NSError(domain:"Preset",code:1,userInfo:[NSLocalizedDescriptionKey:"A preset with this name and ratio already exists."])}
  let key=presetStorageKey(name,ratio);value.presetTitle=name;settings.presets.removeValue(forKey:old);settings.presets[key]=value;if settings.startup==old{settings.startup=key};if activePresetName==old{activePresetName=key;settings.layout.presetTitle=name};return key
 }
 @objc func renamePreset(){
  let old=activePresetName;guard settings.presets[old] != nil,let name=promptName("Rename preset",displayPresetName(old)) else{return}
  do{let key=try renamePresetValue(old,name);activePresetName=key;save();refreshPresets();selectPresetNamed(key,in:preset);updatePresetSaveState()}catch{libraryError(error.localizedDescription)}
 }
 func removePresetValue(_ name:String){
  guard name != "Default" else{return};settings.presets.removeValue(forKey:name)
  if settings.startup==name{settings.startup="Default"}
  if activePresetName==name{applyPreset("Default")}else{save();refreshPresets()}
 }
 @objc func deletePreset(){
  let name=activePresetName;guard name != "Default",settings.presets[name] != nil else{return}
  let a=NSAlert();a.messageText="Delete preset ‘\(displayPresetName(name))’?";a.informativeText="Default will be loaded.";a.addButton(withTitle:"Delete");a.addButton(withTitle:"Cancel")
  guard a.runModal() == .alertFirstButtonReturn else{return};removePresetValue(name)
 }
 func packagePreset(_ name:String)throws->Data{
  guard let layout=presetDefinition(name) else{throw NSError(domain:"Preset",code:2)}
  let osdName=fonts("osd").first{$0.id==(layout.osdFontID ?? settings.legacyOSDFontID)}?.name
  let textName=fonts("text").first{$0.postScriptName==layout.line.fontName}?.name
  let package=SharedPreset(name:displayPresetName(name),layout:layout,osdFontName:osdName,textFontName:textName)
  let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];return try encoder.encode(package)
 }
 func acceptPreset(_ data:Data)throws->String{
  guard data.count<=2_000_000 else{throw NSError(domain:"Preset",code:3,userInfo:[NSLocalizedDescriptionKey:"This preset file is too large."])}
  let package=try JSONDecoder().decode(SharedPreset.self,from:data)
  guard ["P1OSDStudioPreset","OSDEditorPreset"].contains(package.format),package.version==1,presetIsValid(package.layout) else{throw NSError(domain:"Preset",code:4,userInfo:[NSLocalizedDescriptionKey:"This is not a supported OSD Editor preset."])}
  var layout=package.layout;migrateLayout(&layout)
  if let name=package.osdFontName{layout.osdFontID=fonts("osd").first{$0.name.caseInsensitiveCompare(name) == .orderedSame}?.id}
  if let name=package.textFontName,let f=fonts("text").first(where:{$0.name.caseInsensitiveCompare(name) == .orderedSame}){layout.line.fontName=f.postScriptName}
  let ratio=presetAspect(layout);let occupied=settings.presets.keys.filter{presetAspect(settings.presets[$0]!)==ratio}.map{displayPresetName($0)};let name=uniqueName(package.name,occupied+["Default"]);return try storePreset(named:name,layout:layout)
 }
 @objc func exportPreset(){
  let name=activePresetName;guard presetDefinition(name) != nil else{return}
  let p=NSSavePanel();p.allowedContentTypes=[.json];p.nameFieldStringValue=displayPresetName(name)+" ("+presetAspect(presetDefinition(name)!)+").p1preset.json";p.message="Exports the saved preset settings. Font files are not included."
  guard p.runModal() == .OK,let url=p.url else{return}
  do{try packagePreset(name).write(to:url,options:.atomic);status.stringValue="Exported saved preset: "+displayPresetName(name)}catch{libraryError(error.localizedDescription)}
 }
 @objc func importPreset(){
  let p=NSOpenPanel();p.allowedContentTypes=[.json];guard p.runModal() == .OK,let url=p.url else{return}
  do{let name=try acceptPreset(Data(contentsOf:url));save();refreshPresets();requestPreset(name);status.stringValue="Imported preset ‘\(displayPresetName(name))’. Matching fonts must be available in your library."}catch{libraryError(error.localizedDescription)}
 }
}
