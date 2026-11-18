// SPDX-License-Identifier: GPL-3.0-or-later
import Cocoa
import AVFoundation
import CoreImage

let primaryFields = ["ISO","Shutter","EV","CT","Colour Profile"]
let knownCameraFields = primaryFields + ["Aperture","AE metering mode","Frame number","Frame interval","Recording date","Recording time"]
private let names = ["iso":"ISO","shutter":"Shutter","ev":"EV","ct":"CT","color_md":"Colour Profile","colour_md":"Colour Profile","fnum":"Aperture","ae_meter_md":"AE metering mode"]
private let bracket = try! NSRegularExpression(pattern: #"(?i)\[\s*([a-z][a-z0-9_]*)\s*:\s*([^\]]*)\]"#)
private let frame = try! NSRegularExpression(pattern: #"(?i)\b(FrameCnt|DiffTime):\s*([\d.]+(?:ms)?)"#)
private let stamp = try! NSRegularExpression(pattern: #"\b(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d(?:\.\d+)?)"#)

func orderedCameraFields(_ keys:Set<String>) -> [String] {
    knownCameraFields.filter(keys.contains) + keys.subtracting(knownCameraFields).sorted()
}
func djiValues(_ body:String) -> [String:String]? {
    let ns = body as NSString
    let range = NSRange(location:0,length:ns.length)
    let matches = bracket.matches(in:body,range:range)
    guard !matches.isEmpty, body.localizedCaseInsensitiveContains("FrameCnt:") || matches.contains(where:{ names[ns.substring(with:$0.range(at:1)).lowercased()] != nil }) else { return nil }
    var values = [String:String]()
    for match in matches {
        let key=ns.substring(with:match.range(at:1)).lowercased()
        let field=names[key] ?? key
        var value=ns.substring(with:match.range(at:2)).trimmingCharacters(in:.whitespaces)
        guard !value.isEmpty else { continue }
        if field=="Shutter" { value=value.replacingOccurrences(of:#"\.0+$"#,with:"",options:.regularExpression) }
        if field=="CT", Double(value) != nil { value += " K" }
        if field=="Colour Profile", value.lowercased()=="dlog_m" { value="D-Log M" }
        if field=="Aperture", Double(value) != nil { value="f/"+value }
        values[field]=value
    }
    for m in frame.matches(in:body,range:range) {
        values[ns.substring(with:m.range(at:1)).lowercased()=="framecnt" ? "Frame number":"Frame interval"]=ns.substring(with:m.range(at:2))
    }
    if let m=stamp.firstMatch(in:body,range:range) {
        values["Recording date"]=ns.substring(with:m.range(at:1))
        values["Recording time"]=ns.substring(with:m.range(at:2)).split(separator:".",maxSplits:1)[0].description
    }
    return values
}

func isCamera(_ values:[String:String]) -> Bool { knownCameraFields.contains { values[$0] != nil } }

extension Layout {
    func cameraFieldEnabled(_ field:String) -> Bool {
        if primaryFields.contains(field) {
            return hiddenCameraFields?.contains(field) != true && (field != "Colour Profile" || hiddenCameraFields?.contains("Colour mode") != true)
        }
        return enabledCameraExtras?.contains(field) == true
    }
    func displayLine(_ values:[String:String],time:Double=0) -> String {
        guard isCamera(values) else { return telemetryLine(values,widgets) }
        var fields=orderedCameraFields(Set(values.keys))
        if !fields.contains("Elapsed") { fields.append("Elapsed") }
        return fields.filter(cameraFieldEnabled).compactMap { field in
            if field=="Elapsed" {let seconds=max(0,Int(time.rounded(.down)));return String(format:"Elapsed: %02d:%02d:%02d",seconds/3600,seconds/60%60,seconds%60)}
            return values[field].map { "\(field): \($0)" }
        }.joined(separator:"   ")
    }
}

extension App {
    func refreshCameraControls() {
        let camera=selectedExtra.map{additionalTelemetry[$0].camera} ?? cameraSource
        let fields=selectedExtra.map{i in camera ? orderedCameraFields(additionalTelemetry[i].cues.reduce(into:Set<String>()){$0.formUnion($1.values.keys)})+["Elapsed"]:labels} ?? (cameraSource ? importedFields:labels)
        if fields != pickerFields {
            pickerFields=fields
            for row in fieldRows.arrangedSubviews { fieldRows.removeArrangedSubview(row);row.removeFromSuperview() }
            checks.removeAll()
            for i in stride(from:0,to:fields.count,by:2) {
                let row=NSStackView()
                row.spacing=8
                for j in i..<min(i+2,fields.count) {
                    let check=NSButton(checkboxWithTitle:fields[j],target:self,action:#selector(toggle(_:)))
                    check.tag=j
                    check.font = .systemFont(ofSize:12)
                    check.toolTip=fields[j]
                    check.widthAnchor.constraint(equalToConstant:150).isActive=true
                    row.addArrangedSubview(check)
                    checks.append(check)
                }
                fieldRows.addArrangedSubview(row)
            }
        }
        for check in checks {
            check.state=(camera ? telemetryStyle.cameraFieldEnabled(fields[check.tag]) : telemetryStyle.widgets[check.tag].enabled) ? .on:.off
        }
        cameraExport.isHidden = false
        cameraExport.isEnabled = !writingCamera && (!cues.isEmpty || additionalTelemetry.contains{$0.enabled})
    }

    @objc func exportCameraLine() {
        guard !writingCamera else { return }
        pausePlayback()
        let tracks=additionalTelemetry
        var options=[(String,String)]()
        if !cues.isEmpty && settings.layout.telemetryHidden != true {options.append(("T1","T1 – \(lastSRT?.lastPathComponent ?? "Primary telemetry")"))}
        for (i,track) in tracks.enumerated() where track.enabled && track.style.telemetryHidden != true {options.append(("T\(i+2)","T\(i+2) – \(track.url.lastPathComponent)"))}
        if !osdFrames.isEmpty && osdRenderer != nil {options.append(("OSD","Recorded OSD"))}
        if (settings.layout.visuals ?? []).contains(where:{$0.enabled && $0.hidden != true}) {options.append(("Visuals","Visuals"))}
        guard !options.isEmpty else{status.stringValue="No visible overlay layers to export.";return}
        guard let choice=AlphaExportPanel(options:options).run(),!choice.0.isEmpty else{return}
        let panel=NSSavePanel();panel.allowedContentTypes=[.quickTimeMovie]
        let stem=(url ?? lastSRT)?.deletingPathExtension().lastPathComponent ?? "Overlay"
        panel.nameFieldStringValue=stem+"_Overlay.mov"
        guard panel.runModal() == .OK,let chosen=panel.url else{return}
        let layout=settings.layout,samples=cues,frames=osdFrames,renderer=osdRenderer,extras=additionalTelemetry
        let dimensions=asset.map { exportDimensions($0,layout.outputSize ?? "Original",aspect:layout.aspectRatio) } ?? preview.canvasSize
        let end=asset.map {CMTimeGetSeconds($0.duration)} ?? max(duration,samples.last?.end ?? 0)
        let groups=choice.1 ? options.filter{choice.0.contains($0.0)}.map{Set([$0.0])} : [choice.0]
        let outputs=groups.map { keys -> (Set<AlphaLayer>,URL,[AdditionalTelemetry],Bool) in
            var layers=Set<AlphaLayer>()
            let selected=extras.enumerated().filter{keys.contains("T\($0.offset+2)")}.map{$0.element}
            if keys.contains("T1") || !selected.isEmpty{layers.insert(.telemetry)}
            if keys.contains("OSD"){layers.insert(.osd)}
            if keys.contains("Visuals"){layers.insert(.visuals)}
            let destination=choice.1 ? chosen.deletingLastPathComponent().appendingPathComponent(chosen.deletingPathExtension().lastPathComponent+"_"+(keys.first ?? "Overlay")+".mov") : chosen
            return (layers,uniqueExportURL(destination),selected,keys.contains("T1"))
        }
        writingCamera=true;alphaExporting=true;bar.doubleValue=0;exportPercent.stringValue="0%";refreshCameraControls();updateEnabled();status.stringValue="Exporting transparent overlay…"
        DispatchQueue.global(qos:.userInitiated).async {
            let result=Result { for (index,item) in outputs.enumerated() {try writeAlphaMovie(samples,layout,dimensions,item.1,item.0,frames,renderer,end,extras:item.2,includePrimary:item.3,fixedDuration:true) { progress in DispatchQueue.main.async {let total=(Double(index)+progress)/Double(outputs.count);self.bar.doubleValue=total*100;self.exportPercent.stringValue=String(format:"%.0f%%",total*100);self.status.stringValue="Exporting alpha \(index+1)/\(outputs.count): \(item.1.lastPathComponent)"} } } }
            DispatchQueue.main.async {self.writingCamera=false;self.alphaExporting=false;self.refreshCameraControls();self.updateEnabled();switch result {case .success:self.bar.doubleValue=100;self.status.stringValue="Saved "+outputs.map{$0.1.lastPathComponent}.joined(separator:", ");NSWorkspace.shared.activateFileViewerSelecting(outputs.map{$0.1});case .failure(let error):self.status.stringValue="Alpha export failed: "+error.localizedDescription}}
        }
    }
}

struct Problem: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum AlphaLayer: String, CaseIterable { case telemetry="Telemetry", osd="OSD", visuals="Visuals" }

final class AlphaExportPanel: NSObject, NSWindowDelegate {
    let options:[(String,String)]
    private var checks=[String:NSButton]()
    private var headers=[NSButton]()
    private var categories=[[String]]()
    private let allButton=NSButton(title:"Deselect all",target:nil,action:nil)
    private let summary=NSTextField(labelWithString:"")
    private let combined=NSButton(title:"Export Combined",target:nil,action:nil)
    private let individual=NSButton(title:"Export Individual Files",target:nil,action:nil)
    private var panel:NSPanel?
    private var result:(Set<String>,Bool)?
    init(options:[(String,String)]){self.options=options;super.init()}
    private var selected:Set<String>{Set(checks.filter{$0.value.state == .on}.map{$0.key})}
    private func refresh(){
        let keys=selected
        for (i,header) in headers.enumerated(){let ids=categories[i];let count=ids.filter{keys.contains($0)}.count;header.state=count==0 ? .off:(count==ids.count ? .on:.mixed)}
        allButton.title=keys.count==options.count ? "Deselect all":"Select all"
        summary.stringValue="\(keys.count) of \(options.count) layers selected"
        combined.isEnabled = !keys.isEmpty;individual.isEnabled = !keys.isEmpty
    }
    @objc private func changed(){refresh()}
    @objc private func toggleAll(){let state:NSControl.StateValue=selected.count==options.count ? .off:.on;for check in checks.values{check.state=state};refresh()}
    @objc private func toggleGroup(_ sender:NSButton){let ids=categories[sender.tag];let state:NSControl.StateValue=ids.allSatisfy{selected.contains($0)} ? .off:.on;for id in ids{checks[id]?.state=state};refresh()}
    @objc private func cancel(){result=nil;NSApp.stopModal();panel?.orderOut(nil)}
    @objc private func exportCombined(){finish(false)}
    @objc private func exportIndividual(){finish(true)}
    private func finish(_ separate:Bool){guard !selected.isEmpty else{return};result=(selected,separate);NSApp.stopModal();panel?.orderOut(nil)}
    func windowShouldClose(_ sender:NSWindow)->Bool{cancel();return false}
    func run()->(Set<String>,Bool)? {
        let groups=[("OSD",options.filter{$0.0=="OSD"}),("TELEMETRY",options.filter{$0.0.hasPrefix("T")}),("VISUALS",options.filter{$0.0=="Visuals"})]
        let listHeight=CGFloat(min(220,max(74,(groups.map{$0.1.count}.max() ?? 0)*28+12)))
        let width:CGFloat=780, height:CGFloat=244+listHeight
        let window=NSPanel(contentRect:NSRect(x:0,y:0,width:width,height:height),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title="Export transparent overlay";window.isReleasedWhenClosed=false;window.delegate=self;panel=window
        let host=FlippedView(frame:NSRect(x:0,y:0,width:width,height:height));window.contentView=host
        func label(_ value:String,_ frame:NSRect,_ font:NSFont)->NSTextField{let l=NSTextField(labelWithString:value);l.frame=frame;l.font=font;host.addSubview(l);return l}
        let title=label("Export transparent overlay",NSRect(x:20,y:18,width:740,height:28),.boldSystemFont(ofSize:20));title.alignment = .center
        let subtitle=label("Choose the layers you want to export.",NSRect(x:20,y:48,width:740,height:20),.systemFont(ofSize:13));subtitle.alignment = .center;subtitle.textColor = .secondaryLabelColor
        _=label("Overlay layers",NSRect(x:20,y:82,width:300,height:22),.boldSystemFont(ofSize:13))
        allButton.frame=NSRect(x:635,y:78,width:125,height:28);allButton.bezelStyle = .rounded;allButton.target=self;allButton.action=#selector(toggleAll);host.addSubview(allButton)
        let widths:[CGFloat]=[176,324,216];var x:CGFloat=20
        for (i,group) in groups.enumerated(){
            let w=widths[i];let ids=group.1.map{$0.0};categories.append(ids)
            let box=NSBox(frame:NSRect(x:x,y:112,width:w,height:listHeight+38));box.boxType = .custom;box.titlePosition = .noTitle;box.cornerRadius=8;box.borderColor = .separatorColor;box.fillColor = .controlBackgroundColor;box.contentViewMargins = .zero
            let column=FlippedView(frame:NSRect(x:0,y:0,width:w,height:listHeight+38));box.contentView=column;host.addSubview(box)
            let header=NSButton(checkboxWithTitle:group.0,target:self,action:#selector(toggleGroup(_:)));header.frame=NSRect(x:10,y:7,width:w-20,height:24);header.font = .boldSystemFont(ofSize:12);header.tag=i;header.allowsMixedState=true;header.isEnabled = !ids.isEmpty;column.addSubview(header);headers.append(header)
            let scroll=NSScrollView(frame:NSRect(x:8,y:36,width:w-16,height:listHeight-4));scroll.drawsBackground=false;scroll.hasVerticalScroller=CGFloat(group.1.count*28+8)>listHeight-4;scroll.autohidesScrollers=true
            let doc=FlippedView(frame:NSRect(x:0,y:0,width:scroll.contentSize.width,height:max(listHeight-4,CGFloat(group.1.count*28+8))));doc.autoresizingMask = [.width];scroll.documentView=doc;column.addSubview(scroll)
            if ids.isEmpty{let empty=NSTextField(labelWithString:"No visible layers");empty.textColor = .secondaryLabelColor;empty.frame=NSRect(x:3,y:4,width:w-24,height:22);doc.addSubview(empty)}
            for (j,option) in group.1.enumerated(){let check=NSButton(checkboxWithTitle:option.1,target:self,action:#selector(changed));check.frame=NSRect(x:3,y:CGFloat(j*28+2),width:max(20,scroll.contentSize.width-6),height:24);check.autoresizingMask = [.width];check.toolTip=option.1;check.state = .on;checks[option.0]=check;doc.addSubview(check)}
            x += w+12
        }
        summary.frame=NSRect(x:20,y:height-61,width:740,height:19);summary.textColor = .secondaryLabelColor;host.addSubview(summary)
        let cancelButton=NSButton(title:"Cancel",target:self,action:#selector(cancel));cancelButton.keyEquivalent="\u{1b}"
        combined.target=self;combined.action=#selector(exportCombined);combined.keyEquivalent="\r"
        individual.target=self;individual.action=#selector(exportIndividual)
        for (button,frame) in [(cancelButton,NSRect(x:20,y:height-34,width:140,height:28)),(combined,NSRect(x:306,y:height-34,width:210,height:28)),(individual,NSRect(x:526,y:height-34,width:234,height:28))]{button.frame=frame;button.bezelStyle = .rounded;host.addSubview(button)}
        refresh();window.center();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil);panel=nil;return result
    }
}

func writeCameraMovie(_ cues:[Cue], _ layout:Layout, _ size:CGSize, _ output:URL) throws {
    try writeAlphaMovie(cues,layout,size,output,Set([.telemetry]),[],nil,cues.last?.end ?? 0)
}

func writeAlphaMovie(_ cues:[Cue], _ layout:Layout, _ size:CGSize, _ output:URL, _ layers:Set<AlphaLayer>, _ frames:[OSDFrame], _ renderer:OSDRenderer?, _ timelineEnd:Double, extras:[AdditionalTelemetry]=[], includePrimary:Bool=true, fixedDuration:Bool=false, _ reportProgress:((Double)->Void)?=nil) throws {
    guard !layers.isEmpty else { throw Problem("Choose at least one overlay type.") }
    let w=Int(size.width.rounded()), h=Int(size.height.rounded())
    let bounds=CGRect(x:0,y:0,width:w,height:h)
    let context=CIContext(), cache=TextCache()
    let end=fixedDuration ? Int((timelineEnd*1000).rounded()) : max(Int((timelineEnd*1000).rounded()),Int(((cues.last?.end ?? 0)*1000).rounded()),Int(((frames.last?.time ?? 0)*1000).rounded()))
    var times=Set<Int>([0])
    if layers.contains(.telemetry) && includePrimary {
        var previous=""
        for cue in cues { let text=layout.displayLine(cue.values,time:cue.start);if text != previous {times.insert(Int((cue.start*1000).rounded()));previous=text};times.insert(Int((cue.end*1000).rounded())+3) }
    }
    if layers.contains(.visuals) { for cue in cues { times.insert(Int((cue.start*1000).rounded())) } }
    if layers.contains(.osd) { for frame in frames { times.insert(Int((frame.time*1000).rounded())) } }
    if layers.contains(.telemetry) && isCamera(cues.first?.values ?? [:]) && (layout.enabledCameraExtras?.contains("Elapsed") == true) { for tick in stride(from:0,through:end,by:1000) {times.insert(tick)} }
    if layers.contains(.telemetry){
        for track in extras where track.enabled && track.style.telemetryHidden != true {
            for cue in track.cues {for t in [cue.start+track.offset,cue.end+track.offset] where t>=0 && t<Double(end)/1000 {times.insert(Int((t*1000).rounded()))}}
            if track.style.enabledCameraExtras?.contains("Elapsed") == true {for t in stride(from:0,through:end,by:1000){times.insert(t)}}
        }
    }
    let changes=times.filter{$0>=0 && $0<end}.sorted()
    guard end > 0 else { throw Problem("No overlay timing available.") }
    if layers.contains(.telemetry) && layout.telemetryHidden != true && cues.isEmpty && !extras.contains(where:{$0.enabled}) { throw Problem("No telemetry is loaded.") }
    if layers.contains(.osd) && (frames.isEmpty || renderer==nil) { throw Problem("No recorded OSD is loaded.") }
    if layers.contains(.visuals) && !(layout.visuals ?? []).contains(where:{$0.enabled}) { throw Problem("No visual is enabled.") }
    
    let tmp = output.deletingLastPathComponent().appendingPathComponent(UUID().uuidString+".mov")
    defer { try? FileManager.default.removeItem(at:tmp) }
    let writer = try AVAssetWriter(outputURL:tmp,fileType:.mov)
    let input = AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.proRes4444,AVVideoWidthKey:w,AVVideoHeightKey:h])
    input.mediaTimeScale = 1000
    writer.movieTimeScale = 1000
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:w,kCVPixelBufferHeightKey as String:h])
    guard writer.canAdd(input) else { throw Problem("ProRes 4444 encoder unavailable.") }
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? Problem("Cannot start writer.") }
    writer.startSession(atSourceTime:.zero)
    guard let pool = adaptor.pixelBufferPool else { throw Problem("Cannot allocate video buffers.") }
    for (index,milliseconds) in changes.enumerated() {
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw writer.error ?? Problem("Encoding stopped.") }
            Thread.sleep(forTimeInterval:0.002)
        }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer) == kCVReturnSuccess, let buffer else { throw Problem("Buffer allocation failed.") }
        var image=CIImage(color:.clear).cropped(to:bounds)
        let time=Double(milliseconds)/1000
        let values=valuesAt(time,cues)
        if layers.contains(.osd),let renderer { image=renderer.layer(time,frames,layout.cells ?? [:],size.width,size.height).composited(over:image) }
        if layers.contains(.telemetry),includePrimary,layout.telemetryHidden != true {
            let textValue=layout.displayLine(values,time:time)
            if !textValue.isEmpty {
            let glyphs=cache.image(layout.line,textValue,size.height,styled:layout.styledLine(values,time:time,height:size.height))
            let pad=max(3,size.height/360)
            let x=lineX(layout,textValue,size.width,size.height)-pad
            let y=size.height-layout.line.y*size.height-glyphs.extent.height+pad
            image=glyphs.transformed(by:CGAffineTransform(translationX:x,y:y)).composited(over:image)
            }
        }
        if layers.contains(.telemetry){for track in extras where track.enabled && track.style.telemetryHidden != true{image=extraTelemetryImage(track,time,bounds,cache,image)}}
        if layers.contains(.visuals) {
            if let renderer { image=renderer.customLayer(layout.visuals?.first{$0.kind=="Custom"},size).composited(over:image) }
            if let cards=visualsLayer(layout,values,cues,time,size) { image=cards.composited(over:image) }
        }
        context.render(image,to:buffer,bounds:bounds,colorSpace:CGColorSpaceCreateDeviceRGB())
        guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(milliseconds),timescale:1000)) else { throw writer.error ?? Problem("Cannot append frame.") }
        if index % 8 == 0 || index+1 == changes.count { reportProgress?(Double(index+1)/Double(changes.count)) }
    }
    writer.endSession(atSourceTime:CMTime(value:Int64(end),timescale:1000))
    input.markAsFinished()
    let done = DispatchSemaphore(value:0)
    writer.finishWriting { done.signal() }
    done.wait()
    guard writer.status == .completed else { throw writer.error ?? Problem("Export failed.") }
    if FileManager.default.fileExists(atPath:output.path) {
        _ = try FileManager.default.replaceItemAt(output,withItemAt:tmp)
    } else { try FileManager.default.moveItem(at:tmp,to:output) }
}
