//
//  ViewController.swift
//  Piano-Hero
//
//  Created by Da Shen on 4/14/16.
//  Copyright © 2016 UIUC. All rights reserved.
//

import UIKit

class ViewController: UIViewController, BLEDelegate, UITextFieldDelegate {


    var bleShield:BLE = BLE()
//    var MIDIDataBuffer:[MIDINoteOutput] = []
    var MIDIData:CentralControl = CentralControl()
    
//    // Bluetooth state
//    // 0 - initial state 
//    // 1 - data transmission
//    var BTState:UInt8 = 0
    var playingBack:Bool = false
    var countOfDataReceived:Int = 0
    
    @IBOutlet weak var textInput: UITextField!
    @IBOutlet weak var scanBtn: UIButton!
    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var loadMIDI: UIButton!
    @IBOutlet weak var metronomeBtn: UIButton!

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        bleShield.delegate = self
        
        
//        let newMIDI:CentralControl = CentralControl()
//        newMIDI.loadfile("/Users/dashen/Desktop/Undertale_-_080_Finale.mid")
        
        MIDIData.loadfile(NSURL(fileReferenceLiteral: "Undertale_-_080_Finale.mid"))
//        MIDIData.loadfile(NSURL(fileReferenceLiteral: "measures_2_4.midi"))
//        MIDIData.sendDataToArduino(&bleShield)

        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: Connection functions
    @IBAction func BLEShieldScan(sender: UIButton){
        if bleShield.startScanning(2.0) {
            NSTimer.scheduledTimerWithTimeInterval(1.0, target: self.bleShield, selector: #selector(BLE.connectToFirstPeripheral), userInfo: nil, repeats: false)
//            if bleShield.connectToCurrentActivePeripheral() == true {
//                scanBtn.setTitle("Connected", forState: .Normal)
//            } else {
//                scanBtn.setTitle("Try again", forState: .Normal)
//            }
            
        }
    }
    
    @IBAction func sendTestByte(sender: UIButton) {
        print("test send byte")
        // set the FSM to "transmitting data"
        self.countOfDataReceived = 0
        MIDIData.BTState = 1;
        bleShield.startTransmissionRequest()
        MIDIData.sendDataToArduino(&bleShield)
        bleShield.endTransmissionRequest()
        
    }
    
    @IBAction func playAndStop(sender: UIButton) {
        if playingBack {
            //pause it
            bleShield.pausePlaybackRequest()
        } else{
            // play it
            bleShield.playbackRequest()
        }
        
    }
    
    @IBAction func toggleMetronome(sender: UIButton) {
        bleShield.toggleMetronome()
    }
    
    
    @IBAction func metronomeVolUp(sender:UIButton){
        bleShield.metronomeVolUp()
//        print("test1")
    }
    
    @IBAction func metronomeVolDown(sender:UIButton){
        bleShield.metronomeVolDown()
//        print("test2")
    }
    
    @IBAction func tempoUp(sender:UIButton) {
        print("FUNC_TEMP_ADJUST_UP")
        bleShield.sendBytesWaitingForResponse([0x91])
    }
    
    @IBAction func tempoDown(sender:UIButton) {
        print("FUNC_TEMP_ADJUST_DOWN")
        bleShield.sendBytesWaitingForResponse([0x90])
    }
    
//    func sendByte(byte:UInt8){
//        bleShield.sendBytes([byte])
//    }
    
    // MARK: UITextFieldDelegate 
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        return bleShield.sendString(textField.text!)
    }
    
    // MARK: BLEDelegate Protocol
    
    func bleDidUpdateState() {
        return
    }
    
    func bleDidDisconenctFromPeripheral() {
//        print("[BLE] Disconnected from peripheral")
        scanBtn.setTitle("Reconnect", forState: .Normal)
    }
    
    func bleDidConnectToPeripheral() {
        scanBtn.setTitle("Connected", forState: .Normal)
    }
    
    // handler for the data recieved
    func bleDidReceiveData(data: NSData?) {
        let count = (data?.length)!/sizeof(UInt8)
        var array = [UInt8](count: count, repeatedValue:0)
        data?.getBytes(&array, length: count * sizeof(UInt8))
        
        print("received data length: " + String(count))
        for idx in 0..<count {
            print(String(format:"%2X",array[idx]))
        }
        

        for eachDatum in array {
            if eachDatum == 0xE9 {    //RESP_START_PLAYBACK
                playingBack = true
                playBtn.setTitle("Pause", forState: .Normal)
            } else if eachDatum == 0xEA {    //RESP_END_PLAYBACK
                playingBack = false
                playBtn.setTitle("Play", forState: .Normal)
            } else if eachDatum == 0xE5 {   //RESP_ACKNOWLEDGE
                let tempCount = MIDIData.MIDIdata.dataOut.count
                if MIDIData.BTState == 1{
                    self.countOfDataReceived += 1
                    loadMIDI.setTitle("Load MIDI("+String(Int(Double(countOfDataReceived)/Double(tempCount)*100.0))+"%)", forState: .Normal)
                }
            } else if eachDatum == 0xE8 {   //RESP_END_CONNECTION
                loadMIDI.setTitle("MIDI Loaded", forState: .Normal)
            } else if eachDatum == 0xEB {
                if metronomeBtn.titleLabel == "Enable Metronome" {
                    metronomeBtn.setTitle("Disable Metronome", forState: .Normal)
                } else {
                    metronomeBtn.setTitle("Enable Metronome", forState: .Normal)
                }
            }
            
            bleShield.receiveByteHandlerHelper(eachDatum, btState: &(MIDIData.BTState))



            
        }
        
    }

}
