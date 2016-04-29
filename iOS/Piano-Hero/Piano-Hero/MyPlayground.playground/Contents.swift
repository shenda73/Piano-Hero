//: Playground - noun: a place where people can play

import UIKit

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

print(convertNoteToBTMsg(30, noteOn: <#T##Bool#>, keyboardOffset: <#T##UInt8#>))