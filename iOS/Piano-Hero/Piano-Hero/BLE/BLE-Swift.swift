/*
 
 Copyright (c) 2015 Fernando Reynoso
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 */

import Foundation
import CoreBluetooth

protocol BLEDelegate {
    func bleDidUpdateState()
    func bleDidConnectToPeripheral()
    func bleDidDisconenctFromPeripheral()
    func bleDidReceiveData(data: NSData?)
}

class BLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    private let RBL_SERVICE_UUID = "713D0000-503E-4C75-BA94-3148F18D941E"
    private let RBL_CHAR_TX_UUID = "713D0002-503E-4C75-BA94-3148F18D941E"
    private let RBL_CHAR_RX_UUID = "713D0003-503E-4C75-BA94-3148F18D941E"
    
    var delegate: BLEDelegate?
    
    var isConnected: Bool!
    
    private      var centralManager:   CBCentralManager!
    private      var activePeripheral: CBPeripheral?
    private      var characteristics = [String : CBCharacteristic]()
    private      var data:             NSMutableData?
    private(set) var peripherals     = [CBPeripheral]()
    private      var RSSICompletionHandler: ((NSNumber?, NSError?) -> ())?
    
    private var waitingForResponse:Bool = false
    private var byteSendingBuffer:[UInt8] = []
    private var byteSendingWaitingList:[UInt8] = []
    private var resendTimer:NSTimer = NSTimer()
    private var resendTimeoutTime:Double = 2.0
    override init() {
        super.init()
        
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.data = NSMutableData()
        isConnected = false
    }
    
    @objc private func scanTimeout() {
        print("[DEBUG] Scanning stopped")
        self.centralManager.stopScan()
    }
    
    // MARK: Custom methods
    
    // assume there is one active peripheral
    func connectToFirstPeripheral() -> Bool{
        // automatically connect the first one in the BT device list
        if self.peripherals.count > 0 {
            self.connectToPeripheral(self.peripherals[0])
            return true
        } else {
            print("[ERROR] No BT device found")
            return false
        }
    }
    
    func sendString(stringToSend: String) -> Bool{
        var textToSend:NSString = NSString(string: stringToSend)
        var flag:Bool = false
        var tempString:String = ""
        if textToSend.length > 16 {
            tempString = textToSend.substringWithRange(NSRange(16...textToSend.length-1))
            textToSend = textToSend.substringToIndex(16)
            flag = true
        }
        let data:NSData = textToSend.dataUsingEncoding(NSUTF8StringEncoding)!
        
        if activePeripheral?.state == CBPeripheralState.Connected {
            write(data: data)
            if flag {
                sendString(tempString)
            }
            
            print( "sent: " + (textToSend as String))
            return true
        } else {
            return false
        }
    }
    
    // maximum 16 bytes at a time
    func sendBytes(bytesToSend: [UInt8]) -> Bool {
        var data:NSData
        if bytesToSend.count == 0 {
            // ignore it
            return true
        } else if bytesToSend.count <= 16 {
            data = NSData(bytes: bytesToSend, length: bytesToSend.count)
            if activePeripheral?.state == CBPeripheralState.Connected {
                write(data: data)
                return true
            } else {
                print("sendBytes Failed")
                return false
            }
            
        } else {
            data = NSData(bytes: bytesToSend, length: 16)
            if activePeripheral?.state == CBPeripheralState.Connected {
                write(data: data)
            } else {
                print("sendBytes Failed")
                return false
            }
            var trimmedData:[UInt8] = []
            for idx in 16...(bytesToSend.count-1) {
                trimmedData.append(bytesToSend[idx])
            }
            //recursive calls
            return sendBytes(trimmedData)
        }
    }

    
    // This can only take bytes of 14
    private func wrapBytes(bytesToWrap:[UInt8]) -> [UInt8] {
        if bytesToWrap.count <= 14 {
            return [Constants.BTFunctionCode.FUNC_START_OF_DATA_TRANSMISSION] + bytesToWrap + [Constants.BTFunctionCode.FUNC_END_OF_DATA_TRANSMISSION]
        } else {
            return []
        }
    }
    
    func sendBytesWaitingForResponse(dataToSend:[UInt8], needWrap:Bool){
        if dataToSend.count <= 0 {
            return
        }
        var dataLengthLimit = 14
        if !needWrap {
            dataLengthLimit = 16
        }
        
        if !waitingForResponse && byteSendingWaitingList.count==0{
            self.waitingForResponse = true
            if dataToSend.count <= dataLengthLimit {
                self.byteSendingBuffer = dataToSend
                
            } else {
                let bytesToSend:[UInt8] = Array(ArraySlice<UInt8>(dataToSend[0..<dataLengthLimit]))
                let restBytes:[UInt8] = Array(ArraySlice<UInt8>(dataToSend[dataLengthLimit..<dataToSend.count]))
                self.byteSendingBuffer.removeAll()
                self.byteSendingBuffer = bytesToSend
                self.byteSendingWaitingList += restBytes
            }
            if !needWrap {
                sendBytes(self.byteSendingBuffer)
            } else {
                sendBytes(self.wrapBytes(self.byteSendingBuffer))
            }
            
            self.resendTimer =  NSTimer.scheduledTimerWithTimeInterval(self.resendTimeoutTime, target: self, selector: #selector(BLE.timeOutResend), userInfo: nil, repeats: false)
        } else {
            self.byteSendingWaitingList += dataToSend
        }
    }
    
    func timeOutResend() {
        if waitingForResponse {
            sendBytes(wrapBytes(self.byteSendingBuffer))
//            self.resendTimer =  NSTimer.scheduledTimerWithTimeInterval(self.resendTimeoutTime, target: self, selector: #selector(BLE.timeOutResend), userInfo: nil, repeats: false)
        }
    }
    
    func sendTheFirst14BytesInWaitingListWithoutResendTimer() {
        var dataToSend:[UInt8] = []
        if self.byteSendingWaitingList.count <= 14 {
            dataToSend += self.byteSendingWaitingList
            self.byteSendingWaitingList.removeAll()
        } else { // count > 14
            dataToSend += Array(ArraySlice<UInt8>(self.byteSendingWaitingList[0..<14]))
            let tempData = Array(ArraySlice<UInt8>(self.byteSendingWaitingList[14..<self.byteSendingWaitingList.count]))
            self.byteSendingWaitingList.removeAll()
            self.byteSendingWaitingList += tempData
        }
        self.byteSendingBuffer.removeAll()
        self.byteSendingBuffer += dataToSend
        self.sendBytes(self.wrapBytes(dataToSend))
    }
    
    func additionalReceivedByteHandler(data:UInt8) {
        self.resendTimer.invalidate()   // stop the resend timer
        self.byteSendingBuffer.removeAll()
        self.waitingForResponse = false

        // try the waiting list
        if self.byteSendingWaitingList.count > 0 {
            self.sendTheFirst14BytesInWaitingListWithoutResendTimer()
            self.resendTimer =  NSTimer.scheduledTimerWithTimeInterval(self.resendTimeoutTime, target: self, selector: #selector(BLE.timeOutResend), userInfo: nil, repeats: false)
        }
    }
    

    
    // MARK: Public methods
    func startScanning(timeout: Double) -> Bool {
        
        if self.centralManager.state != .PoweredOn {
            
            print("[ERROR] Couldn´t start scanning")
            return false
        }
        
        print("[DEBUG] Scanning started")
        
        // CBCentralManagerScanOptionAllowDuplicatesKey
        
        NSTimer.scheduledTimerWithTimeInterval(timeout, target: self, selector: #selector(BLE.scanTimeout), userInfo: nil, repeats: false)
#if os(iOS)
        let services:[CBUUID] = [CBUUID(string: RBL_SERVICE_UUID)]
        self.centralManager.scanForPeripheralsWithServices(services, options: nil)
#else
        self.centralManager.scanForPeripheralsWithServices(nil, options: nil)
#endif
        
        return true
    }
    
    func connectToPeripheral(peripheral: CBPeripheral) -> Bool {
        
        if self.centralManager.state != .PoweredOn {
            
            print("[ERROR] Couldn´t connect to peripheral")
            return false
        }
        
        print("[DEBUG] Connecting to peripheral: \(peripheral.identifier.UUIDString)")
        
        self.centralManager.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(bool: true)])
        
        return true
    }
    
    func disconnectFromPeripheral(peripheral: CBPeripheral) -> Bool {
        
        if self.centralManager.state != .PoweredOn {
            
            print("[ERROR] Couldn´t disconnect from peripheral")
            return false
        }
        
        self.centralManager.cancelPeripheralConnection(peripheral)
        
        return true
    }
    
    func read() {
        
        guard let char = self.characteristics[RBL_CHAR_TX_UUID] else { return }
        
        self.activePeripheral?.readValueForCharacteristic(char)
    }
    
    func write(data data: NSData) {
        
        guard let char = self.characteristics[RBL_CHAR_RX_UUID] else { return }
        
        self.activePeripheral?.writeValue(data, forCharacteristic: char, type: .WithoutResponse)
    }
    
    func enableNotifications(enable: Bool) {
        
        guard let char = self.characteristics[RBL_CHAR_TX_UUID] else { return }
        
        self.activePeripheral?.setNotifyValue(enable, forCharacteristic: char)
    }
    
    func readRSSI(completion: (RSSI: NSNumber?, error: NSError?) -> ()) {
        
        self.RSSICompletionHandler = completion
        self.activePeripheral?.readRSSI()
    }
    
    // MARK: CBCentralManager delegate
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        switch central.state {
        case .Unknown:
            print("[DEBUG] Central manager state: Unknown")
            break
            
        case .Resetting:
            print("[DEBUG] Central manager state: Resseting")
            break
            
        case .Unsupported:
            print("[DEBUG] Central manager state: Unsupported")
            break
            
        case .Unauthorized:
            print("[DEBUG] Central manager state: Unauthorized")
            break
            
        case .PoweredOff:
            print("[DEBUG] Central manager state: Powered off")
            break
            
        case .PoweredOn:
            print("[DEBUG] Central manager state: Powered on")
            break
        }
        
        self.delegate?.bleDidUpdateState()
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject],RSSI: NSNumber) {
        print("[DEBUG] Find peripheral: \(peripheral.identifier.UUIDString) RSSI: \(RSSI)")
        
        let index = peripherals.indexOf { $0.identifier.UUIDString == peripheral.identifier.UUIDString }
        
        if let index = index {
            peripherals[index] = peripheral
        } else {
            peripherals.append(peripheral)
        }
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("[ERROR] Could not connecto to peripheral \(peripheral.identifier.UUIDString) error: \(error!.description)")
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
        print("[DEBUG] Connected to peripheral \(peripheral.identifier.UUIDString)")
        
        self.activePeripheral = peripheral
        
        self.activePeripheral?.delegate = self
        self.activePeripheral?.discoverServices([CBUUID(string: RBL_SERVICE_UUID)])
        
        self.delegate?.bleDidConnectToPeripheral()
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        var text = "[DEBUG] Disconnected from peripheral: \(peripheral.identifier.UUIDString)"
        
        if error != nil {
            text += ". Error: \(error!.description)"
        }
        
        print(text)
        
        self.activePeripheral?.delegate = nil
        self.activePeripheral = nil
        self.characteristics.removeAll(keepCapacity: false)
        
        self.delegate?.bleDidDisconenctFromPeripheral()
        self.isConnected = false
    }
    
    
    
    // MARK: CBPeripheral delegate
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        if error != nil {
            print("[ERROR] Error discovering services. \(error!.description)")
            return
        }
        
        print("[DEBUG] Found services for peripheral: \(peripheral.identifier.UUIDString)")
        
        
        for service in peripheral.services! {
            let theCharacteristics = [CBUUID(string: RBL_CHAR_RX_UUID), CBUUID(string: RBL_CHAR_TX_UUID)]
            
            peripheral.discoverCharacteristics(theCharacteristics, forService: service)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        if error != nil {
            print("[ERROR] Error discovering characteristics. \(error!.description)")
            return
        }
        
        print("[DEBUG] Found characteristics for peripheral: \(peripheral.identifier.UUIDString)")
        
        for characteristic in service.characteristics! {
            self.characteristics[characteristic.UUID.UUIDString] = characteristic
        }
        
        enableNotifications(true)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        if error != nil {
            
            print("[ERROR] Error updating value. \(error!.description)")
            return
        }
        if characteristic.UUID.UUIDString == RBL_CHAR_TX_UUID {
            self.delegate?.bleDidReceiveData(characteristic.value)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        self.RSSICompletionHandler?(RSSI, error)
        self.RSSICompletionHandler = nil
    }
    
}