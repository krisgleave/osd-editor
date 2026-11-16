// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

struct SRTChapter {
    let url:URL
    let cues:[Cue]
    let recordingStart:String?
    var lengthMS:Int { Int((cues.last!.end*1000).rounded()) }
}

func readChapters(_ urls:[URL]) throws -> [SRTChapter] {
    guard !urls.isEmpty else { throw Problem("Select at least one SRT.") }
    var result=[SRTChapter]()
    for url in urls {
        var encoding=String.Encoding.utf8
        let source=try String(contentsOf:url,usedEncoding:&encoding)
        let cues=parseSRT(source)
        guard let first=cues.first else { throw Problem("No recognised telemetry in "+url.lastPathComponent) }
        if urls.count>1 {
            guard cues.allSatisfy({isCamera($0.values)}), cues.count==source.components(separatedBy:"-->").count-1 else {
                throw Problem("Each chapter must contain readable DJI camera cues. Check "+url.lastPathComponent)
            }
        }
        var previous=0.0
        for cue in cues {
            guard cue.start.isFinite, cue.end.isFinite, cue.start >= previous, cue.end > cue.start, cue.end < 8640000 else { throw Problem("Invalid or overlapping cue times in "+url.lastPathComponent) }
            previous=cue.end
        }
        let stamp=first.values["Recording date"].flatMap { date in first.values["Recording time"].map {date+" "+$0} }
        result.append(SRTChapter(url:url,cues:cues,recordingStart:stamp))
    }
    let dated=result.allSatisfy{$0.recordingStart != nil}
    return result.sorted {
        if dated, $0.recordingStart != $1.recordingStart {return $0.recordingStart! < $1.recordingStart!}
        return $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
    }
}

func joinedCues(_ chapters:[SRTChapter]) -> [Cue] {
    var offset=0, joined=[Cue]()
    for chapter in chapters {
        for cue in chapter.cues {
            joined.append(Cue(start:Double(offset+Int((cue.start*1000).rounded()))/1000,end:Double(offset+Int((cue.end*1000).rounded()))/1000,values:cue.values))
        }
        offset += chapter.lengthMS
    }
    return joined
}

func chapterListing(_ chapters:[SRTChapter]) -> String {
    var offset=0
    return chapters.map { chapter in
        defer { offset += chapter.lengthMS }
        return String(format:"%02d:%02d:%02d.%03d",offset/3600000,offset/60000%60,offset/1000%60,offset%1000)+"   "+chapter.url.lastPathComponent
    }.joined(separator:"\n")
}

func srtTimestamp(_ seconds:Double) -> String {
    let milliseconds=max(0,Int((seconds*1000).rounded()))
    return String(format:"%02d:%02d:%02d,%03d",milliseconds/3600000,milliseconds/60000%60,milliseconds/1000%60,milliseconds%1000)
}

func combinedSRTText(_ chapters:[SRTChapter]) -> String {
    let cues=joinedCues(chapters)
    return cues.enumerated().map { index,cue in
        let camera=isCamera(cue.values)
        let body:String
        if camera {
            var lines=["FrameCnt: \(index+1)"]
            if let date=cue.values["Recording date"],let time=cue.values["Recording time"] {lines.append(date+" "+time)}
            let mapping=[("ISO","iso"),("Shutter","shutter"),("Aperture","fnum"),("EV","ev"),("CT","ct"),("Colour Profile","color_md"),("AE metering mode","ae_meter_md")]
            let fields=mapping.compactMap { field,key -> String? in
                guard var value=cue.values[field] else{return nil}
                if field=="CT" {value=value.replacingOccurrences(of:" K",with:"")}
                if field=="Colour Profile",value=="D-Log M" {value="dlog_m"}
                return "[\(key): \(value)]"
            }
            body=(lines+fields).joined(separator:"\n")
        } else {
            body=cue.values.keys.sorted().compactMap {key in cue.values[key].map {"\(key): \($0)"} }.joined(separator:" ")
        }
        return "\(index+1)\n\(srtTimestamp(cue.start)) --> \(srtTimestamp(cue.end))\n\(body)"
    }.joined(separator:"\n\n")+"\n"
}
