//
//  ControlCenter.swift
//  Piano-Hero
//
//  Created by Da Shen on 4/27/16.
//  Copyright © 2016 UIUC. All rights reserved.
//

import Foundation
import AudioToolbox


// part of the code is adapted from http://ericjknapp.com/blog/2014/04/05/midi-events/

struct Constants {
    struct MIDI {
        static let NoteOnByteHeader:UInt8 = 0b01
        static let NoteOffByteHeader:UInt8 = 0b11
        static let TimeByteHeader:UInt8 = 0b00
        
    }
    
    struct BTFunctionCode {
        static let FUNC_START_LOADING:UInt8 = 0x97
        static let FUNC_STOP_LOADING:UInt8 = 0x98
        static let FUNC_START_OF_DATA_TRANSMISSION:UInt8 = 0x99
        static let FUNC_END_OF_DATA_TRANSMISSION:UInt8 = 0x9A
        static let FUNC_START_PLAYBACK:UInt8 = 0x9B
        static let FUNC_PAUSE_PLAYBACK:UInt8 = 0x9C
        static let FUNC_TOGGLE_METRONOME:UInt8 = 0x9D
        static let FUNC_METRONOME_VOL_UP:UInt8 = 0x9E
        static let FUNC_METRONOME_VOL_DOWN:UInt8 = 0x9F
        static let FUNC_CLR_SCREEN:UInt8 = 0xAF
        static let FUNC_TEMP_ADJUST_UP:UInt8 = 0x91
        static let FUNC_TEMP_ADJUST_DOWN:UInt8 = 0x90
    }
    
    struct BTResponseCode {
        static var RESP_ACKNOWLEDGE:UInt8 = 0xE5
        static var RESP_DECLINE:UInt8 = 0xE6
        static var RESP_START_CONNECTION:UInt8 = 0xE7
        static var RESP_END_CONNECTION:UInt8 = 0xE8
        static var RESP_START_PLAYBACK:UInt8 = 0xE9
        static var RESP_END_PLAYBACK:UInt8 = 0xEA
        static var RESP_TOGGLE_METRONOME:UInt8 = 0xEB
        
        static var RESP_TEMP_ADJUST_UP:UInt8 = 0xA1
        static var RESP_TEMP_ADJUST_DOWN:UInt8 = 0xA0
    }
}

class ControlCenter: BLEDelegate{
    var bleShield:BLE = BLE()
    
    //SYSState - current System State
    //  0 - initial/normal state
    //  1 - bluetooth data transmission
    //  2 - playback state
    var SYSState:UInt8 = 0
    
    init() {
        bleShield.delegate = self
    }
    
    func connectToPianoHero() {
        if bleShield.startScanning(2.0) {
            NSTimer.scheduledTimerWithTimeInterval(1.0, target: self.bleShield, selector: #selector(BLE.connectToFirstPeripheral), userInfo: nil, repeats: false)
        }
    }
    
    func loadMIDI(fileURL:NSURL, speed: UInt16, keyboardOffset: UInt8) {
        let newMIDIFile = MIDIRaw(fileURL: fileURL)
        SYSState = 1
        newMIDIFile.sendDataToArduino(&(self.bleShield), speed: speed, keyboardOffset: keyboardOffset)
        SYSState = 0
    }

    
    // ----- Playback Control -----
    func startPlaybackOrPause() {
        if self.SYSState == 0 {
            bleShield.sendBytesWaitingForResponse([Constants.BTFunctionCode.FUNC_START_PLAYBACK],needWrap: false)
        } else if self.SYSState == 2 {
            bleShield.sendBytesWaitingForResponse([Constants.BTFunctionCode.FUNC_PAUSE_PLAYBACK],needWrap: false)
        }
        
    }
    
    func BTHandler(data:NSData?) {
        let count = (data?.length)!/sizeof(UInt8)
        var array = [UInt8](count: count, repeatedValue:0)
        data?.getBytes(&array, length: count * sizeof(UInt8))
        
        print("[DEBUG] received data length: " + String(count))
        for idx in 0..<count {
            print(String(format:"%2X",array[idx]))
        }
        for byte in array{            
            switch byte {
            case Constants.BTResponseCode.RESP_END_CONNECTION:
                if SYSState == 1 {
                    SYSState = 0
                }
                break
            case Constants.BTResponseCode.RESP_START_CONNECTION:
                if SYSState == 0 {
                    SYSState = 1
                }
                break
            case Constants.BTResponseCode.RESP_START_PLAYBACK:
                if SYSState == 0 {
                    SYSState = 2
                }
                break
            case Constants.BTResponseCode.RESP_END_PLAYBACK:
                if SYSState == 2 {
                    SYSState = 0
                }
                break
            case Constants.BTResponseCode.RESP_ACKNOWLEDGE:
                
                break
            case Constants.BTResponseCode.RESP_TOGGLE_METRONOME:
                break
            default:
                break
            }
            
            bleShield.additionalReceivedByteHandler(byte)
        }
        
    }
    
    // BLEDelegate Protocol
    func bleDidUpdateState() {
        print("BLE did update state")
        return
    }
    func bleDidConnectToPeripheral() {
        print("BLE did connect to peripheral")
        
    }
    func bleDidDisconenctFromPeripheral(){
        print("BLE did disconnect from peripheral")
    }
    func bleDidReceiveData(data: NSData?){
        print("BLE did receive data")
        self.BTHandler(data)
    }
}

class MIDIRaw {
    var musicSequence:MusicSequence = nil
    var timeResolution:UInt32 = 0
    var tempoTrack:MusicTrack = nil
    
    init(){
        
    }
    
    init(fileURL:NSURL){
        //        let MIDIURL:NSURL = NSURL(fileURLWithPath: fileName)
        //        let MIDIURL2:NSURL = NSURL(fileURLWithPath: "http://ericjknapp.com/parsingMIDI/air-tromb.mid")
        //        print(UIApplication.sharedApplication().canOpenURL(MIDIURL))
        var status:OSStatus = NewMusicSequence(&musicSequence)
        let flag:MusicSequenceLoadFlags = MusicSequenceLoadFlags.SMF_PreserveTracks
        let type:MusicSequenceFileTypeID = MusicSequenceFileTypeID.MIDIType
        status = MusicSequenceFileLoad(musicSequence, fileURL, type, flag )
        
        if status != OSStatus(noErr) {
            print("\(#line) bad status \(status) creating sequence - loading file")
            return
            
        }
        self.tempoTrack = parseTempoTrack(musicSequence)
        self.timeResolution = determineTimeResolutionWithTempoTrack(self.tempoTrack)
    }
    
    // *** PUBLIC METHODS ***
    
    func sendDataToArduino(BTConnection:UnsafePointer<BLE>, speed:UInt16, keyboardOffset:UInt8) -> Bool {
        BTConnection.memory.sendBytesWaitingForResponse([Constants.BTFunctionCode.FUNC_START_LOADING],needWrap: false)
        let dataToSend:[MIDINoteOnOffEvent] = self.generateMIDINotesOutputWithSettings(speed)
        // keep the timestamp of the current note
        var prevTime:UInt32 = 0
        for eachTimeSlot in dataToSend {
            self.sendToArduinoHelper(BTConnection, data: eachTimeSlot, keyboardOffset:keyboardOffset, timeDiff: eachTimeSlot.timeStamp-prevTime)
            prevTime = eachTimeSlot.timeStamp
        }
        BTConnection.memory.sendBytesWaitingForResponse([Constants.BTFunctionCode.FUNC_STOP_LOADING],needWrap: false)
        return false
    }
    
    // *** PRIVATE METHODS ***
    
    private func generateMIDINotesOutputWithSettings(speed:UInt16) -> [MIDINoteOnOffEvent] {
        let newNotes:[MIDINote] = parseMIDIEventTracks(musicSequence)
        let tempMIDIData:MIDINotes = MIDINotes(speed: speed)
        tempMIDIData.addNotes(newNotes)
        return tempMIDIData.generateDataOut()
    }
    
    // MIDI Helper Functions
    private func parseTempoTrack(sequence:MusicSequence) -> MusicTrack {
        var newTempoTrack:MusicTrack = nil
        MusicSequenceGetTempoTrack(sequence, &newTempoTrack)
        
        var iterator:MusicEventIterator = nil
        NewMusicEventIterator(newTempoTrack, &iterator)
        
        var hasNext:DarwinBoolean = true
        var timeStamp:MusicTimeStamp = 0
        var eventType:MusicEventType = 0
        var eventData:UnsafePointer<Void> = nil
        var eventDataSize:UInt32 = 0
        
        while hasNext {
            MusicEventIteratorGetEventInfo(iterator, &timeStamp, &eventType, &eventData, &eventDataSize)
            MusicEventIteratorNextEvent(iterator)
            MusicEventIteratorHasCurrentEvent(iterator, &hasNext)
        }
        return newTempoTrack
    }
    
    private func parseTrackForMIDIEvents(iterator:MusicEventIterator) -> [MIDINote] {
        var timeStamp:MusicTimeStamp = 0
        var eventType:MusicEventType = 0
        var eventData:UnsafePointer<Void> = nil
        var eventDataSize:UInt32 = 0
        var hasNext:DarwinBoolean = true
        
        var midiTrack:[MIDINote] = []
        
        MusicEventIteratorHasCurrentEvent(iterator, &hasNext)
        while hasNext {
            MusicEventIteratorGetEventInfo(iterator, &timeStamp, &eventType, &eventData, &eventDataSize)
            if eventType == MusicEventType(kMusicEventType_MIDINoteMessage) {
                let noteMessage:UnsafePointer<MIDINoteMessage> = UnsafePointer<MIDINoteMessage>(eventData)
                
                
                midiTrack.append(convertNoteWithCalculatedTimeResolution(noteMessage, timeStamp: timeStamp))
            }
            MusicEventIteratorNextEvent(iterator)
            MusicEventIteratorHasNextEvent(iterator, &hasNext)
        }
        
        return midiTrack
    }
    
    private func parseMIDIEventTracks(sequence:MusicSequence) -> [MIDINote] {
        var trackCount:UInt32 = 0
        MusicSequenceGetTrackCount(sequence, &trackCount)
        var track:MusicTrack = nil
        var newMIDINotes:[MIDINote] = []
        
        for idx:UInt32 in 0..<trackCount {
            MusicSequenceGetIndTrack(sequence, idx, &track)
            var iterator:MusicEventIterator = nil
            NewMusicEventIterator(track, &iterator)
            newMIDINotes += parseTrackForMIDIEvents(iterator)
        }
        return newMIDINotes
    }
    
    
    private func determineTimeResolutionWithTempoTrack(tempoTrack:MusicTrack) -> UInt32 {
        var timeResolution:UInt32 = 0
        var propertyLength:UInt32 = 0
        MusicTrackGetProperty(tempoTrack, kSequenceTrackProperty_TimeResolution, nil, &propertyLength)
        MusicTrackGetProperty(tempoTrack, kSequenceTrackProperty_TimeResolution, &timeResolution, &propertyLength)
        return timeResolution
    }
    
    private func convertNoteWithCalculatedTimeResolution(noteMessage:UnsafePointer<MIDINoteMessage>, timeStamp:MusicTimeStamp) -> MIDINote {
        var barBeatTime:CABarBeatTime = CABarBeatTime();
        MusicSequenceBeatsToBarBeatTime(self.musicSequence, timeStamp, self.timeResolution, &barBeatTime)
        
        let retNote:MIDINote = MIDINote(note:noteMessage.memory.note ,timeReso: timeResolution, meas: barBeatTime.bar, beat: barBeatTime.beat, subBeat: barBeatTime.subbeat, duration: noteMessage.memory.duration)
        
        return retNote
    }
    
    
    
    
    // range from 1 to 36
    private func convertNoteToBTMsg(noteNum:UInt8, noteOn:Bool, keyboardOffset:UInt8) -> UInt8 {
        if noteNum < keyboardOffset || noteNum >= keyboardOffset+36 {
            return 0
        }
        let difference:UInt8 = noteNum - keyboardOffset + 1  // +1 makes sure it starts from 1 to 36
        if noteOn {
            return ((difference & 0b00111111) | (Constants.MIDI.NoteOnByteHeader << 6))
        } else {
            return ((difference & 0b00111111) | (Constants.MIDI.NoteOffByteHeader << 6))
        }
    }
    
    // for each time stamp
    private func sendToArduinoHelper(BTConnection:UnsafePointer<BLE>, data:MIDINoteOnOffEvent, keyboardOffset:UInt8 ,timeDiff:UInt32) {
        let BTPort:BLE = BTConnection.memory
        
        // split time stamp into four bytes
        let timeDiffB1:UInt8 = UInt8((timeDiff & 0xfff) >> 6) & 0x3f | (Constants.MIDI.TimeByteHeader << 6)
        let timeDiffB2:UInt8 = UInt8((timeDiff & 0xfff) & 0x3f ) | (Constants.MIDI.TimeByteHeader << 6)
        
        var retArray:[UInt8] = []
//            [Constants.BTFunctionCode.FUNC_START_OF_DATA_TRANSMISSION]   //FUNC_START_OF_DATA_TRANSMISSION
        
        // append two time stamps
        retArray.append(timeDiffB1)
        retArray.append(timeDiffB2)
        
        for each in data.notesOn{
            if each >= keyboardOffset && each < keyboardOffset + 36  {
                retArray.append(convertNoteToBTMsg(each, noteOn: true, keyboardOffset: keyboardOffset))
            }
        }
        for each in data.notesOff{
            if each >= keyboardOffset && each < keyboardOffset + 36  {
                retArray.append(convertNoteToBTMsg(each, noteOn: false, keyboardOffset: keyboardOffset))
            }
        }
//        retArray.append(Constants.BTFunctionCode.FUNC_END_OF_DATA_TRANSMISSION)   //FUNC_END_OF_DATA_TRANSMISSION
        if retArray.count > 16 {
            print("warning! writing more than 16 bytes")
        }
        
        print(retArray)
        
        // replace this with a timed sending
        BTPort.sendBytesWaitingForResponse(retArray,needWrap: true)
    }
    
}

class MIDINotes {
    private var data:[MIDINote] = []
    private var beatsPerBar:UInt16 = 0
    private var speed:UInt16 = 0
    private var durationQuarterNote:Float = 0
    
    init(speed:UInt16) {
        if speed == 0 {
            print("Playback Speed cannot be 0")
            return
        } else {
            self.speed = speed
            self.durationQuarterNote = 60.0/Float(speed)
        }
    }
    
    private func addNote(n:MIDINote) {
        data.append(n)
        if n.beat > beatsPerBar {
            beatsPerBar = n.beat
        }
    }
    
    func addNotes(arrayInput:[MIDINote]) {
        for eachItem in arrayInput {
            addNote(eachItem)
        }
    }
    
    func generateDataOut() -> [MIDINoteOnOffEvent] {
        var dataOut:[MIDINoteOnOffEvent] = []
        var timestampArray:[UInt32] = []
        // put in all time slots with any event
        for eachNote in data{
            timestampArray.append(eachNote.realTimeStampNoteOn(durationQuarterNote, beatsPerBar: UInt8(beatsPerBar)))
            timestampArray.append(eachNote.realTimeStampNoteOff(durationQuarterNote, beatsPerBar: UInt8(beatsPerBar)))
        }
        // sort
        timestampArray.sortInPlace()
        
        for eachSlot in timestampArray {
            if dataOut.indexOf({$0.timeStamp == eachSlot}) == nil {
                let tempNote:MIDINoteOnOffEvent = MIDINoteOnOffEvent()
                tempNote.timeStamp = eachSlot
                dataOut.append(tempNote)
            }
            
        }
        for eachNote in data{
            if let found = dataOut.indexOf({$0.timeStamp == eachNote.realTimeStampNoteOn(durationQuarterNote, beatsPerBar: UInt8(beatsPerBar))}) {
                let obj = dataOut[found]
                // if found duplicated note in off notes
                if let found = obj.notesOff.indexOf(eachNote.note)  {
                    obj.notesOff.removeAtIndex(found)
                } else {
                    obj.notesOn.append(eachNote.note)
                }
                
            }
            if let found = dataOut.indexOf({$0.timeStamp == eachNote.realTimeStampNoteOff(durationQuarterNote, beatsPerBar: UInt8(beatsPerBar))}) {
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
        return dataOut
    }
    
    func inspectElementsInDataOut(dataOut:[MIDINoteOnOffEvent]) {
        for eachTime in dataOut {
            print("time: \(eachTime.timeStamp), notesOn: \(eachTime.notesOn), notesOff: \(eachTime.notesOff)")
        }
    }
}

class MIDINoteOnOffEvent {
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
        return UInt32(retVal)
    }
    
    func realTimeStampNoteOff(quarterNoteDuration:Float,beatsPerBar:UInt8) -> UInt32 {
        let quaterNotesNum = (measure - 1) * Int32(beatsPerBar) + Int32(UInt16(self.beat) - 1)
        let retVal = (Float32(quaterNotesNum) + subBeat + duration) * quarterNoteDuration*1000
        return UInt32(retVal)
    }
    
    private func snapNumToQuarter(duration:Float)->Float32{
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


