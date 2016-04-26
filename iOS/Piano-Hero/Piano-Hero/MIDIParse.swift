//
//  MIDIParse.swift
//  Piano-Hero
//
//  Created by Da Shen on 4/21/16.
//  Copyright © 2016 UIUC. All rights reserved.
//

import Foundation
import AudioToolbox

import UIKit

// code adapted from http://ericjknapp.com/blog/2014/04/05/midi-events/

class MIDINotes {
    var data:[MIDINote] = []
    var beatsPerBar:UInt16 = 0
    var dataOut:[MIDINoteOutput] = []
    var speed:UInt16 = 120
    var durationQuarterNote:Float = 0.5

    
    func addNote(n:MIDINote) {
        data.append(n)
        if n.beat > beatsPerBar {
            beatsPerBar = n.beat
        }
    }
    func updateSpeed(newSpeed:UInt16) {
        self.speed = newSpeed
        self.durationQuarterNote = 60/Float(speed)
    }
    
    
    
    //call this function to generate dataout to Arduino
    func generateDataOut() {
        var timestampArray:[UInt32] = []
        for eachNote in data{
//            var newNote:MIDINoteOutput = MIDINoteOutput()
            timestampArray.append(eachNote.realTimeStampNoteOn(durationQuarterNote, beatsPerBar: UInt8(beatsPerBar)))
            timestampArray.append(eachNote.realTimeStampNoteOff(durationQuarterNote, beatsPerBar: UInt8(beatsPerBar)))
        }
        timestampArray.sortInPlace()
        for eachSlot in timestampArray {
            if dataOut.indexOf({$0.timeStamp == eachSlot}) == nil {
                let tempNote:MIDINoteOutput = MIDINoteOutput()
                tempNote.timeStamp = eachSlot
                dataOut.append(tempNote)
            }
            
        }
        for eachNote in data{
            if let found = dataOut.indexOf({$0.timeStamp == eachNote.noteOnTime}) {
                let obj = dataOut[found]
                // if found duplicated note in off notes
                if let found = obj.notesOff.indexOf(eachNote.note)  {
                    obj.notesOff.removeAtIndex(found)
                } else {
                    obj.notesOn.append(eachNote.note)
                }
                
            }
            if let found = dataOut.indexOf({$0.timeStamp == eachNote.noteOffTime}) {
                let obj = dataOut[found]
                if let found = obj.notesOn.indexOf(eachNote.note) {
                    obj.notesOn.removeAtIndex(found)
                } else {
                    obj.notesOff.append(eachNote.note)
                }
                
            }
        }
        
        // remove duplicated off/on notes
        var timeEmpty:[UInt32] = []
        for each in dataOut {
            if each.notesOff.count == 0 && each.notesOn.count == 0 {
                timeEmpty.append(each.timeStamp)
                
            }
        }
        for eachEmptyTime in timeEmpty{
            let found = dataOut.indexOf({$0.timeStamp == eachEmptyTime})
            dataOut.removeAtIndex(found!)
        }
    }
    
    func inspectElementsInDataOut() {
        for eachTime in dataOut {
            print("time: \(eachTime.timeStamp), notesOn: \(eachTime.notesOn), notesOff: \(eachTime.notesOff)")
        }
    }
}

class MIDINoteOutput {
    var timeStamp:UInt32 = 0 // should in millisecond
    var notesOn:[UInt8] = []
    var notesOff:[UInt8] = []
}

class MIDINote {
    var note:UInt8 = 0
    var timeResolution:UInt32 = 0
    var measure:Int32 = 0
    var beat:UInt16 = 0
    var subBeat:Float32 = 0
    var duration:Float32 = 0.0
    
    var noteOnTime: UInt32 = 0
    var noteOffTime: UInt32 = 0
    
    init(note:UInt8,timeReso:UInt32,meas:Int32,beat:UInt16,subBeat:UInt16,duration:Float32){
        self.note = note
        self.timeResolution = timeReso
        self.measure = meas
        self.beat = beat
        if timeReso != 0 {
            self.subBeat = snapNumToQuarter(Float32(Float32(subBeat)/Float32(timeResolution)))
        }
        self.duration = snapNumToQuarter(duration)
    }
    
    func realTimeStampNoteOn(quarterNoteDuration:Float,beatsPerBar:UInt8) -> UInt32 {
        let quaterNotesNum = (measure - 1) * Int32(beatsPerBar) + Int32(UInt16(self.beat) - 1)
        let retVal = (Float32(quaterNotesNum) + subBeat) * quarterNoteDuration*1000
        self.noteOnTime = UInt32(retVal)
        return self.noteOnTime
    }
    
    func realTimeStampNoteOff(quarterNoteDuration:Float,beatsPerBar:UInt8) -> UInt32 {
        let quaterNotesNum = (measure - 1) * Int32(beatsPerBar) + Int32(UInt16(self.beat) - 1)
        let retVal = (Float32(quaterNotesNum) + subBeat + duration) * quarterNoteDuration*1000
        self.noteOffTime = UInt32(retVal)
        return self.noteOffTime
    }
    
    func snapNumToQuarter(duration:Float)->Float32{
        let testNum = Int(duration * 100)
        if testNum % 25 != 0 {
            let remainingNum = testNum % 25
            if remainingNum > 13 {
                return Float32(Int(testNum / 25)*25 + 25)/100.0
            } else {
                return Float32(Int(testNum / 25)*25)/100.0
            }
        } else{
            return Float32(Int(testNum / 25)*25)/100.0
        }
    }
    
}

class CentralControl {
    var musicSequence:MusicSequence = nil
    var timeResolution:UInt32 = 0
    var tempoTrack:MusicTrack = nil

    var MIDIdata:MIDINotes = MIDINotes()
    
//    var lastPlayedTimeInMillis:NSTimeInterval = NSDate(timeIntervalSince1970: NSTimeInterval)
    
    // SYS settings
    var offsetMIDINotes:UInt8 = 46;
    
    // Bluetooth state:
    //    0 - initial state, 1 - data transmission
    var BTState:UInt8 = 0
    
    func BTHandler(byte:UInt8) {
        
    }
    
    func remoteControl(){
        // start playing
        
    }
    
    // example file:
    // http://ericjknapp.com/parsingMIDI/air-tromb.mid
    func loadfile(fileName:NSURL){
//        let MIDIURL:NSURL = NSURL(fileURLWithPath: fileName)
//        let MIDIURL2:NSURL = NSURL(fileURLWithPath: "http://ericjknapp.com/parsingMIDI/air-tromb.mid")
//        print(UIApplication.sharedApplication().canOpenURL(MIDIURL))
        var status:OSStatus = NewMusicSequence(&musicSequence)
        let flag:MusicSequenceLoadFlags = MusicSequenceLoadFlags.SMF_PreserveTracks
        let type:MusicSequenceFileTypeID = MusicSequenceFileTypeID.MIDIType
        status = MusicSequenceFileLoad(musicSequence, fileName, type, flag )
        
        if status != OSStatus(noErr) {
            print("\(#line) bad status \(status) creating sequence - loading file")
            displayStatus(status)
            return
            
        }
        
        parseTempoTrack(musicSequence)
        
        determineTimeResolutionWithTempoTrack(tempoTrack)
        
        parseMIDIEventTracks(musicSequence)
        
        MIDIdata.generateDataOut()
//        MIDIdata.inspectElementsInDataOut()
        
//        return MIDIdata.dataOut
    }
    
    func parseTempoTrack(sequence:MusicSequence) {
        tempoTrack = nil
        MusicSequenceGetTempoTrack(sequence, &tempoTrack)
        
        var iterator:MusicEventIterator = nil
        NewMusicEventIterator(tempoTrack, &iterator)

        
        var hasNext:DarwinBoolean = true
        var timeStamp:MusicTimeStamp = 0
        var eventType:MusicEventType = 0
        var eventData:UnsafePointer<Void> = nil
        var eventDataSize:UInt32 = 0
        
        while hasNext {
            MusicEventIteratorGetEventInfo(iterator, &timeStamp, &eventType, &eventData, &eventDataSize)
//            print("event found: " + String(eventType))
            MusicEventIteratorNextEvent(iterator)
            MusicEventIteratorHasCurrentEvent(iterator, &hasNext)
        }

    }
    
    
    func parseTrackForMIDIEvents(iterator:MusicEventIterator) {
        var timeStamp:MusicTimeStamp = 0
        var eventType:MusicEventType = 0
        var eventData:UnsafePointer<Void> = nil
        var eventDataSize:UInt32 = 0
        var hasNext:DarwinBoolean = true
        
        MusicEventIteratorHasCurrentEvent(iterator, &hasNext)
        while hasNext {
            MusicEventIteratorGetEventInfo(iterator, &timeStamp, &eventType, &eventData, &eventDataSize)
            var prevTime = 0
            if eventType == MusicEventType(kMusicEventType_MIDINoteMessage) {
                let noteMessage:UnsafePointer<MIDINoteMessage> = UnsafePointer<MIDINoteMessage>(eventData)
                let note = noteMessage.memory
//                print("Note @TimeStamp \(timeStamp),channel: \(note.channel), note: \(note.note), velocity: \(note.velocity), release velocity: \(note.releaseVelocity), duration: \(note.duration)")
                
                showNoteInformationWithNote(noteMessage, timeStamp: timeStamp)
            }
            MusicEventIteratorNextEvent(iterator)
            MusicEventIteratorHasNextEvent(iterator, &hasNext)
        }
    }
    
    func parseMIDIEventTracks(sequence:MusicSequence) {
        var trackCount:UInt32 = 0
        MusicSequenceGetTrackCount(sequence, &trackCount)
        print("track count: \(trackCount)")
        var track:MusicTrack = nil
        
        for idx:UInt32 in 0..<trackCount {
            print("parsing Track\(idx)")
            MusicSequenceGetIndTrack(sequence, idx, &track)
            var iterator:MusicEventIterator = nil
            NewMusicEventIterator(track, &iterator)
            parseTrackForMIDIEvents(iterator)
        }
    }
    
    
    func determineTimeResolutionWithTempoTrack(tempoTrack:MusicTrack) {
        var timeResolution:UInt32 = 0
        var propertyLength:UInt32 = 0
        MusicTrackGetProperty(tempoTrack, kSequenceTrackProperty_TimeResolution, nil, &propertyLength)
        MusicTrackGetProperty(tempoTrack, kSequenceTrackProperty_TimeResolution, &timeResolution, &propertyLength)
        
//        print("time resolution: \(timeResolution)")
//        print("property length: \(propertyLength)")
        
        self.timeResolution = timeResolution
    }
    
    func showNoteInformationWithNote(noteMessage:UnsafePointer<MIDINoteMessage>, timeStamp:MusicTimeStamp) {
        var barBeatTime:CABarBeatTime = CABarBeatTime();
        MusicSequenceBeatsToBarBeatTime(self.musicSequence, timeStamp, self.timeResolution, &barBeatTime)
        
//        print("\(barBeatTime.bar):\(barBeatTime.beat):\(barBeatTime.subbeat) timestamp: \(timeStamp) channel: \(noteMessage.memory.channel) note:\(noteMessage.memory.note) duration: \(noteMessage.memory.duration)")
        
        let newVar:MIDINote = MIDINote(note:noteMessage.memory.note ,timeReso: timeResolution, meas: barBeatTime.bar, beat: barBeatTime.beat, subBeat: barBeatTime.subbeat, duration: noteMessage.memory.duration)
        MIDIdata.addNote(newVar)
        
//        print("\(newVar.measure):\(newVar.beat):\(newVar.subBeat) note:\(newVar.note) duration: \(newVar.duration) realTimeOn: \(newVar.realTimeStampNoteOn(0.5, beatsPerBar: 4)) realTimeOff: \(newVar.realTimeStampNoteOff(0.5, beatsPerBar: 4))")
        
    }
    
    // range from 1 to 36
    func convertNote(data:UInt8, noteOn:Bool) -> UInt8 {
        if data < self.offsetMIDINotes || data >= self.offsetMIDINotes+36 {
            return 0
        }
        let difference:UInt8 = data - self.offsetMIDINotes + 1  // +1 makes sure it starts from 1 to 36
        if noteOn {
            return ((difference & 0b00111111) | 0b01000000)
        } else {
            return ((difference & 0b00111111) | 0b11000000)
        }
    }
    
    // for each time stamp
    func sendToArduinoHelper(BTConnection:UnsafePointer<BLE>, data:MIDINoteOutput, timeDiff:UInt32) -> Bool {
        let BTPort:BLE = BTConnection.memory
        
        // split time stamp into four bytes
//        let timeStamp:UInt32 = data.timeStamp
//        let timeStampB1:UInt8 = UInt8((timeStamp >> 26) & 0x3f)
//        let timeStampB2:UInt8 = UInt8((timeStamp >> 20) & 0x3f)
//        let timeStampB3:UInt8 = UInt8((timeStamp >> 14) & 0x3f)
//        let timeStampB4:UInt8 = UInt8((timeStamp >> 8) & 0x3f)
//        let timeStampB5:UInt8 = UInt8((timeStamp >> 2) & 0x3f)
//        let timeStampB6:UInt8 = UInt8((timeStamp) & 0x3)
        let timeDiffB1:UInt8 = UInt8((timeDiff & 0xfff) >> 6) & 0x3f
        let timeDiffB2:UInt8 = UInt8((timeDiff & 0xfff) & 0x3f )

        var retArray:[UInt8] = [0x99]   //FUNC_START_OF_DATA_TRANSMISSION
        
        // append two time stamps
        retArray.append(timeDiffB1)
        retArray.append(timeDiffB2)
        
        for each in data.notesOn{
            if each >= self.offsetMIDINotes && each < self.offsetMIDINotes + 36  {
                retArray.append(convertNote(each, noteOn: true))
            }
        }
        for each in data.notesOff{
            if each >= self.offsetMIDINotes && each < self.offsetMIDINotes + 36  {
                retArray.append(convertNote(each, noteOn: false))
            }
        }
        retArray.append(0x9A)   //FUNC_END_OF_DATA_TRANSMISSION
        if retArray.count > 16 {
            print("warning! writing more than 16 bytes")
        }
        
        print(retArray)
        
        // replace this with a timed sending
        BTPort.sendBytesWaitingForResponse(retArray)
        
        
        
        return false
    }
    
    func sendDataToArduino(BTConnection:UnsafePointer<BLE>) -> Bool {
        // keep the current time now
        var prevTime:UInt32 = 0
        for eachTimeSlot in self.MIDIdata.dataOut {
            print("sent one note")
            self.sendToArduinoHelper(BTConnection, data: eachTimeSlot, timeDiff: eachTimeSlot.timeStamp-prevTime)
            prevTime = eachTimeSlot.timeStamp

        }
        return false
    }
    
    // this uses millisecond
    func delay(delay:UInt64, closure:()->()) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay/1000 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(), closure)
    }
    
    // DEBUG function
    // Reference: https://github.com/genedelisa/MusicSequence/blob/master/MusicSequence/MIDISequence.swift
    func displayStatus(status:OSStatus) {
        print("Bad status: \(status)")
        let nserror = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        print("\(nserror.localizedDescription)")
        
        switch status {
        // ugly
        case OSStatus(kAudioToolboxErr_InvalidSequenceType):
            print("Invalid sequence type")
            
        case OSStatus(kAudioToolboxErr_TrackIndexError):
            print("Track index error")
            
        case OSStatus(kAudioToolboxErr_TrackNotFound):
            print("Track not found")
            
        case OSStatus(kAudioToolboxErr_EndOfTrack):
            print("End of track")
            
        case OSStatus(kAudioToolboxErr_StartOfTrack):
            print("start of track")
            
        case OSStatus(kAudioToolboxErr_IllegalTrackDestination):
            print("Illegal destination")
            
        case OSStatus(kAudioToolboxErr_NoSequence):
            print("No Sequence")
            
        case OSStatus(kAudioToolboxErr_InvalidEventType):
            print("Invalid Event Type")
            
        case OSStatus(kAudioToolboxErr_InvalidPlayerState):
            print("Invalid Player State")
            
        case OSStatus(kAudioToolboxErr_CannotDoInCurrentContext):
            print("Cannot do in current context")
            
        default:
            print("Something or other went wrong")
        }
    }
    
    
}

