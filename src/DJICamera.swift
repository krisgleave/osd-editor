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
        let available:[AlphaLayer]=[.telemetry,.osd,.visuals]
        let availability:[AlphaLayer:Bool]=[.telemetry:!cues.isEmpty || additionalTelemetry.contains{$0.enabled},.osd:!osdFrames.isEmpty && osdRenderer != nil,.visuals:(settings.layout.visuals ?? []).contains(where:{$0.enabled})]
        guard let choice=AlphaExportPanel(available:availability).run() else{return}
        let layers=choice.0
        guard !layers.isEmpty else {status.stringValue="Choose at least one overlay type.";return}
        let panel=NSSavePanel();panel.allowedContentTypes=[.quickTimeMovie]
        let stem=(url ?? lastSRT)?.deletingPathExtension().lastPathComponent ?? "Overlay"
        panel.nameFieldStringValue=stem+"_Overlay.mov"
        guard panel.runModal() == .OK,let chosen=panel.url else{return}
        let layout=settings.layout,samples=cues,frames=osdFrames,renderer=osdRenderer,extras=additionalTelemetry
        let dimensions=asset.map { exportDimensions($0,layout.outputSize ?? "Original",aspect:layout.aspectRatio) } ?? preview.canvasSize
        let end=asset.map {CMTimeGetSeconds($0.duration)} ?? max(duration,samples.last?.end ?? 0)
        let outputs:[(Set<AlphaLayer>,URL)]
        if !choice.1 {outputs=[(layers,uniqueExportURL(chosen))]}
        else {outputs=layers.sorted{$0.rawValue<$1.rawValue}.map { layer in
            let name=chosen.deletingPathExtension().lastPathComponent+"_"+layer.rawValue.replacingOccurrences(of:" ",with:"")+".mov"
            return (Set([layer]),uniqueExportURL(chosen.deletingLastPathComponent().appendingPathComponent(name)))
        }}
        writingCamera=true;alphaExporting=true;bar.doubleValue=0;exportPercent.stringValue="0%";refreshCameraControls();updateEnabled();status.stringValue="Exporting transparent overlay…"
        DispatchQueue.global(qos:.userInitiated).async {
            let result=Result { for (index,item) in outputs.enumerated() {try writeAlphaMovie(samples,layout,dimensions,item.1,item.0,frames,renderer,end,extras:extras) { progress in DispatchQueue.main.async {let total=(Double(index)+progress)/Double(outputs.count);self.bar.doubleValue=total*100;self.exportPercent.stringValue=String(format:"%.0f%%",total*100);self.status.stringValue="Exporting alpha \(index+1)/\(outputs.count): \(item.1.lastPathComponent)"} } } }
            DispatchQueue.main.async {self.writingCamera=false;self.alphaExporting=false;self.refreshCameraControls();self.updateEnabled();switch result {case .success:self.bar.doubleValue=100;self.status.stringValue="Saved "+outputs.map{$0.1.lastPathComponent}.joined(separator:", ");case .failure(let error):self.status.stringValue="Alpha export failed: "+error.localizedDescription}}
        }
    }
}

struct Problem: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum AlphaLayer: String, CaseIterable { case telemetry="Telemetry", osd="OSD", visuals="Visuals" }

final class AlphaExportPanel:NSObject {
    let panel:NSPanel
    let checks:[AlphaLayer:NSButton]
    let mode:NSSegmentedControl
    private var accepted=false
    init(available:[AlphaLayer:Bool]) {
        panel=NSPanel(contentRect:NSRect(x:0,y:0,width:520,height:390),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        panel.title="Export transparent overlay";panel.isReleasedWhenClosed=false;panel.standardWindowButton(.zoomButton)?.isHidden=true;panel.standardWindowButton(.miniaturizeButton)?.isHidden=true
        let content=NSView(frame:NSRect(x:0,y:0,width:520,height:390));panel.contentView=content
        if let icon=NSImage(named:NSImage.applicationIconName) {let image=NSImageView(image:icon);image.frame=NSRect(x:228,y:292,width:64,height:64);image.imageScaling = .scaleProportionallyUpOrDown;content.addSubview(image)}
        func label(_ value:String,_ frame:NSRect,_ font:NSFont,_ colour:NSColor = .labelColor,_ alignment:NSTextAlignment = .left)->NSTextField {let field=NSTextField(labelWithString:value);field.frame=frame;field.font=font;field.textColor=colour;field.alignment=alignment;content.addSubview(field);return field}
        _=label("Export transparent overlay",NSRect(x:28,y:250,width:464,height:28),.boldSystemFont(ofSize:20),.labelColor,.center)
        let detail=label("Choose what to include. You can save one combined overlay or separate files.",NSRect(x:42,y:212,width:436,height:34),.systemFont(ofSize:13),.secondaryLabelColor,.center);detail.maximumNumberOfLines=2
        _=label("Overlay layers",NSRect(x:32,y:174,width:456,height:20),.systemFont(ofSize:13,weight:.semibold))
        var built=[AlphaLayer:NSButton]()
        for (index,layer) in AlphaLayer.allCases.enumerated() {let check=NSButton(checkboxWithTitle:layer.rawValue,target:nil,action:nil);check.frame=NSRect(x:38+index*145,y:143,width:125,height:24);check.state=layer == .telemetry ? .on:.off;check.isEnabled=available[layer] == true;built[layer]=check;content.addSubview(check)}
        checks=built
        _=label("Export mode",NSRect(x:32,y:108,width:456,height:20),.systemFont(ofSize:13,weight:.semibold))
        mode=NSSegmentedControl(labels:["One combined file","Separate files"],trackingMode:.selectOne,target:nil,action:nil);mode.selectedSegment=0;mode.frame=NSRect(x:32,y:74,width:456,height:28);content.addSubview(mode)
        let cancel=NSButton(title:"Cancel",target:nil,action:nil);cancel.frame=NSRect(x:32,y:22,width:170,height:32);cancel.bezelStyle = .rounded;content.addSubview(cancel)
        let export=NSButton(title:"Export",target:nil,action:nil);export.frame=NSRect(x:318,y:22,width:170,height:32);export.bezelStyle = .rounded;export.keyEquivalent="\r";content.addSubview(export)
        super.init();cancel.target=self;cancel.action=#selector(cancelExport);export.target=self;export.action=#selector(confirmExport)
    }
    @objc func cancelExport(){NSApp.stopModal(withCode:.cancel)}
    @objc func confirmExport(){accepted=true;NSApp.stopModal(withCode:.OK)}
    func run()->(Set<AlphaLayer>,Bool)? {panel.center();let response=NSApp.runModal(for:panel);panel.orderOut(nil);guard response == .OK,accepted else{return nil};return (Set(checks.compactMap{$0.value.state == .on ? $0.key:nil}),mode.selectedSegment==1)}
}

func writeCameraMovie(_ cues:[Cue], _ layout:Layout, _ size:CGSize, _ output:URL) throws {
    try writeAlphaMovie(cues,layout,size,output,Set([.telemetry]),[],nil,cues.last?.end ?? 0)
}

func writeAlphaMovie(_ cues:[Cue], _ layout:Layout, _ size:CGSize, _ output:URL, _ layers:Set<AlphaLayer>, _ frames:[OSDFrame], _ renderer:OSDRenderer?, _ timelineEnd:Double, extras:[AdditionalTelemetry]=[], _ reportProgress:((Double)->Void)?=nil) throws {
    guard !layers.isEmpty else { throw Problem("Choose at least one overlay type.") }
    let w=Int(size.width.rounded()), h=Int(size.height.rounded())
    let bounds=CGRect(x:0,y:0,width:w,height:h)
    let context=CIContext(), cache=TextCache()
    let end=max(Int((timelineEnd*1000).rounded()),Int(((cues.last?.end ?? 0)*1000).rounded()),Int(((frames.last?.time ?? 0)*1000).rounded()))
    var times=Set<Int>([0])
    if layers.contains(.telemetry) {
        var previous=""
        for cue in cues { let text=layout.displayLine(cue.values,time:cue.start);if text != previous {times.insert(Int((cue.start*1000).rounded()));previous=text} }
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
        if layers.contains(.telemetry),layout.telemetryHidden != true {
            let textValue=layout.displayLine(values,time:time)
            if !textValue.isEmpty {
            let glyphs=cache.image(layout.line,textValue,size.height)
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
