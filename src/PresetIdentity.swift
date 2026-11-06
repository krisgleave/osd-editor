// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2026 Kris Gleave (KrisTalksTech) — original Swift implementation and modifications.
import Cocoa
func presetStorageKey(_ title:String,_ aspect:String)->String{"\(title) (\(aspect))"}
func presetDisplayTitle(_ key:String,_ layout:Layout?)->String{
 guard key != "Default" else{return key}
 if let title=layout?.presetTitle,!title.isEmpty{return title}
 let ratio=layout.map{presetAspect($0)} ?? "16:9";let suffix=" (\(ratio))"
 return key.hasSuffix(suffix) ? String(key.dropLast(suffix.count)):key
}
extension App{
 func displayPresetName(_ key:String)->String{presetDisplayTitle(key,settings.presets[key])}
 func existingPreset(named title:String,aspect:String)->String?{settings.presets.keys.sorted().first{presetAspect(settings.presets[$0]!)==aspect && displayPresetName($0).caseInsensitiveCompare(title) == .orderedSame}}
 @discardableResult func storePreset(named title:String,layout:Layout,replace:Bool=false)throws->String{
  let clean=title.trimmingCharacters(in:.whitespacesAndNewlines)
  guard !clean.isEmpty,clean.caseInsensitiveCompare("Default") != .orderedSame,clean != "Last settings" else{throw NSError(domain:"Preset",code:1,userInfo:[NSLocalizedDescriptionKey:"Choose a name other than Default."])}
  let existing=existingPreset(named:clean,aspect:presetAspect(layout));if existing != nil && !replace{throw NSError(domain:"Preset",code:2,userInfo:[NSLocalizedDescriptionKey:"A preset with this name and aspect ratio already exists."])}
  let key=existing ?? presetStorageKey(clean,presetAspect(layout));var value=layout;value.presetTitle=clean;value.referenceAspect=presetAspect(layout);settings.presets[key]=value;return key
 }
 func migratePresetIdentities(){
  let original=settings.presets;var migrated=[String:Layout]();var keys=[String:String]()
  for old in original.keys.sorted(){var value=original[old]!;if old=="Default"{migrated[old]=value;continue};let ratio=presetAspect(value);let base=presetDisplayTitle(old,value);var title=base;var n=2;while migrated[presetStorageKey(title,ratio)] != nil{title="\(base) (\(n))";n+=1};let key=presetStorageKey(title,ratio);value.presetTitle=title;value.referenceAspect=ratio;migrated[key]=value;keys[old]=key}
  let changed=original.keys.sorted() != migrated.keys.sorted()
  if changed,FileManager.default.fileExists(atPath:settingsURL.path){let backup=settingsURL.deletingLastPathComponent().appendingPathComponent("settings-before-ratio-identities.json");if !FileManager.default.fileExists(atPath:backup.path){try? FileManager.default.copyItem(at:settingsURL,to:backup)}}
  settings.presets=migrated;if let startup=keys[settings.startup]{settings.startup=startup}
 }
}
