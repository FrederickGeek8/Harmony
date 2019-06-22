//
//  ViewController.swift
//  Harmony Desktop
//
//  Created by Frederick Morlock on 7/20/17.
//  Copyright © 2017 Frederick Morlock. All rights reserved.
//

import Cocoa
import PeerTalk
import AVFoundation
import CocoaAsyncSocket

class ViewController: NSViewController, GCDAsyncUdpSocketDelegate {
    
    @IBOutlet weak var imageView: NSImageView!
    private(set) var connectedDeviceID: NSNumber?
    private let PTAppReconnectDelay: TimeInterval = 1.0
    var connectingToDeviceID_: NSNumber?
    var connectedDeviceID_: NSNumber?
    var connectedDeviceProperties_ = [AnyHashable: Any]()
    var remoteDeviceInfo_ = [AnyHashable: Any]()
    var notConnectedQueue_ = DispatchQueue(label: "PTExample.notConnectedQueue")
    var notConnectedQueueSuspended_: Bool = false
    var connectedChannel_: PTChannel?
    var consoleTextAttributes_ = [AnyHashable: Any]()
    var consoleStatusTextAttributes_ = [AnyHashable: Any]()
    var pings_ = [AnyHashable: Any]()
    var scaleX = Float()
    var scaleY = Float()
    
    var udpSocket: GCDAsyncUdpSocket?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.startListeningForDevices()
        self.enqueueConnectToLocalIPv4Port()
        self.ping()
        
        
        udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        try! udpSocket?.bind(toPort: 4000)
        try! udpSocket?.enableBroadcast(true)
        try! udpSocket?.beginReceiving()
        
        
//        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(transmit), userInfo: nil, repeats: true)
        
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        sendImage(data: data)
    }
    
    func sendImage(data: Data) {
        if ((connectedChannel_) != nil) {
            let dataLoad = data as NSData
            let payload = dataLoad.createReferencingDispatchData()
            connectedChannel_?.sendFrame(ofType: UInt32(PTExampleFrameTypeData), tag: PTFrameNoTag, withPayload: payload, callback: {(_ error: Error?) -> Void in
                if error != nil {
                    print("Failed to send message: \(error!)")
                }
            })
        }
    }
    
    @objc func transmit() {
    }
    
    func interpretMessage(message: String) {
        let splitString = message.components(separatedBy: ",")
        
        if (splitString[0] == "d") {
            MouseController.moveTo(x: Int(Float(splitString[1])! * scaleX), y: Int(Float(splitString[2])! * scaleY))
            MouseController.mouseDown()
        } else if (splitString[0] == "m") {
            MouseController.dragTo(x: Int(Float(splitString[1])! * scaleX), y: Int(Float(splitString[2])! * scaleY))
        } else if (splitString[0] == "u") {
            MouseController.dragTo(x: Int(Float(splitString[1])! * scaleX), y: Int(Float(splitString[2])! * scaleY))
            MouseController.mouseUp()
        }
        
    }
    
    func setScale(message: String) {
        let splitString = message.components(separatedBy: "x")
        let x = Float(splitString[0])!
        let y = Float(splitString[1])!
        
        let screenSize = NSScreen.main?.frame;
        scaleX = Float(screenSize!.width) / x
        scaleY = Float(screenSize!.height) / y
        
    }
    
    func setConnectedChannel(connectedChannel: PTChannel?) {
        connectedChannel_ = connectedChannel
        
        if (connectedChannel_ == nil && notConnectedQueueSuspended_) {
            notConnectedQueue_.resume()
            notConnectedQueueSuspended_ = false;
        } else if (connectedChannel_ != nil && !notConnectedQueueSuspended_) {
            notConnectedQueue_.suspend()
            notConnectedQueueSuspended_ = true;
        }
        
        if (connectedChannel_ == nil && (connectingToDeviceID_ != nil)) {
            self.enqueueConnectToUSBDevice()
        }
    }
    
    // MARK: Ping
    
    func pong(withTag tagno: UInt32, error: Error?) {
        let tag = Int(tagno)
        var pingInfo = pings_[tag] as? [AnyHashable: Any] ?? [AnyHashable: Any]()
        if ((pingInfo) != nil) {
            let now = Date()
            pingInfo["date ended"] = now
            pings_.removeValue(forKey: tag)
            print(String(format: "Ping total roundtrip time: %.3f ms", now.timeIntervalSince(pingInfo["date created"] as! Date) * 1000.0))
        }
    }
    
    @objc func ping() {
        if connectedChannel_ != nil {
            
            if !pings_.isEmpty {
                pings_ = [AnyHashable: Any]()
            }
            
            let tagno = connectedChannel_?.protocol.newTag()
            let tag = Int(tagno!)
            var pingInfo: [AnyHashable: Any] = [
                "date created" : Date()
            ]
            
            pings_[tag] = pingInfo
            connectedChannel_!.sendFrame(ofType: UInt32(PTExampleFrameTypePing), tag: tagno!, withPayload: nil, callback: {(_ error: Error?) -> Void in
                self.perform(#selector(self.ping), with: nil, afterDelay: 1.0)
                pingInfo["date sent"] = Date()
                if error != nil {
                    self.pings_.removeValue(forKey: tag)
                }
            })
        } else {
            perform(#selector(self.ping), with: nil, afterDelay: 1.0)
        }
    }
    
    // MARK: Wired device connections
    
    func startListeningForDevices() {
        let nc = NotificationCenter.default
        
        nc.addObserver(forName: NSNotification.Name.PTUSBDeviceDidAttach, object: PTUSBHub.shared(), queue: nil, using: {(_ note: Notification) -> Void in
            let deviceID = note.userInfo?["DeviceID"]
            print("PTUSBDeviceDidAttachNotification: \(deviceID)")
            
            self.notConnectedQueue_.async(execute: {() -> Void in
                if !(self.connectingToDeviceID_ != nil) || !(deviceID as! NSNumber == self.connectingToDeviceID_) {
                    self.disconnectFromCurrentChannel()
                    self.connectingToDeviceID_ = deviceID as! NSNumber
                    self.connectedDeviceProperties_ = note.userInfo?["Properties"] as! [AnyHashable : Any]
                    self.enqueueConnectToUSBDevice()
                }
            })
        })
        
        nc.addObserver(forName: NSNotification.Name.PTUSBDeviceDidDetach, object: PTUSBHub.shared(), queue: nil) { (_ note: Notification) -> Void in
            let deviceID = note.userInfo?["DeviceID"]
            print("PTUSBDeviceDidDetachNotification: \(deviceID)")
            if (self.connectingToDeviceID_ == deviceID as? NSNumber) {
                self.connectedDeviceProperties_ = [AnyHashable: Any]()
                self.connectingToDeviceID_ = nil
                if (self.connectedChannel_ != nil) {
                    self.connectedChannel_?.close()
                }
            }
        }
    }
    
    func didDisconnect(fromDevice deviceID: NSNumber) {
        print("Disconnected from device")
        if (connectedDeviceID_ == deviceID) {
            willChangeValue(forKey: "connectedDeviceID")
            connectedDeviceID_ = nil
            didChangeValue(forKey: "connectedDeviceID")
        }
    }
    
    func disconnectFromCurrentChannel() {
        if (connectedDeviceID_ != nil) && (connectedChannel_ != nil) {
            connectedChannel_?.close()
            setConnectedChannel(connectedChannel: nil)
        }
    }
    
    @objc func enqueueConnectToLocalIPv4Port() {
        notConnectedQueue_.async(execute: {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                self.connectToLocalIPv4Port()
            })
        })
    }
    
    func connectToLocalIPv4Port() {
        var channel = PTChannel.init(delegate: self)
        channel?.userInfo = "127.0.0.1:\(PTExampleProtocolIPv4PortNumber)"
        channel?.connect(toPort: in_port_t(PTExampleProtocolIPv4PortNumber), iPv4Address: INADDR_LOOPBACK, callback: {(_ error: Error?, _ address: PTAddress?) -> Void in
            
            let cerror = (error as? NSError)
            if error != nil {
                if cerror?.domain == NSPOSIXErrorDomain && (cerror?.code == Int(ECONNREFUSED) || cerror?.code == Int(ETIMEDOUT)) {
                    // this is an expected state
                } else {
                    print("Failed to connect to 127.0.0.1:\(PTExampleProtocolIPv4PortNumber): \(error)")
                }
            } else {
                self.disconnectFromCurrentChannel()
                self.setConnectedChannel(connectedChannel: channel)
                channel?.userInfo = address
                print("Connected to \(address)")
            }
            self.perform(#selector(self.enqueueConnectToLocalIPv4Port), with: nil, afterDelay: self.PTAppReconnectDelay)
        })
    }

    @objc func enqueueConnectToUSBDevice() {
        notConnectedQueue_.async(execute: {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                self.connectToUSBDevice()
            })
        })
    }
    
    func connectToUSBDevice() {
        var channel = PTChannel.init(delegate: self)
        channel?.userInfo = connectingToDeviceID_
        channel?.delegate = self
        
        channel?.connect(toPort: PTExampleProtocolIPv4PortNumber, overUSBHub: PTUSBHub.shared(), deviceID: connectingToDeviceID_, callback: {(_ error: Error?) -> Void in
            let cerror = (error as? NSError)
            if error != nil {
                if cerror?.domain == PTUSBHubErrorDomain && PTUSBHubError(UInt32((cerror?.code)!)) == PTUSBHubErrorConnectionRefused {
                    print("Failed to connect to device #\(channel?.userInfo): \(error)")
                } else {
                    print("Failed to connect to device #\(channel?.userInfo): \(error)")
                }
                if channel?.userInfo as? NSNumber == self.connectingToDeviceID_ {
                    self.perform(#selector(self.enqueueConnectToUSBDevice), with: nil, afterDelay: self.PTAppReconnectDelay)
                }
            }
            else {
                self.connectedDeviceID_ = self.connectingToDeviceID_
                self.setConnectedChannel(connectedChannel: channel)
                //NSLog(@"Connected to device #%@\n%@", connectingToDeviceID_, connectedDeviceProperties_);
                //infoTextField_.stringValue = [NSString stringWithFormat:@"Connected to device #%@\n%@", deviceID, connectedDeviceProperties_];
            }
        })
    }

}

extension ViewController: PTChannelDelegate {
    func ioFrameChannel(_ channel: PTChannel, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        if     type != UInt32(PTExampleFrameTypeDeviceInfo)
            && type != UInt32(PTExampleFrameTypeTextMessage)
            && type != UInt32(PTExampleFrameTypePing)
            && type != UInt32(PTExampleFrameTypePong)
            && type != UInt32(PTFrameTypeEndOfStream) {
            print("Unexpected frame of type " + String(type))
            channel.close();
            return false;
        } else {
            return true;
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
        if (type == UInt32(PTExampleFrameTypeDeviceInfo)) {
            let textFrame = PayloadConverter().convert(toString: payload)
            setScale(message: textFrame!)
            print(">> Recieved coordinates: " + textFrame!)
        } else if (type == UInt32(PTExampleFrameTypeTextMessage)) {
            let textFrame = PayloadConverter().convert(toString: payload)
            interpretMessage(message: textFrame!)
        } else if (type == UInt32(PTExampleFrameTypePong)) {
            self.pong(withTag: tag, error: nil)
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel, didEndWithError error: NSError) {
        if ((connectedDeviceID_ != nil) && (connectedDeviceID_ == channel.userInfo as! NSNumber)) {
            self.didDisconnect(fromDevice: connectedDeviceID_!)
        }
        
        if connectedChannel_ == channel {
            print("Disconnected from \(channel.userInfo)")
            setConnectedChannel(connectedChannel: nil)
        }
    }
}
