//
//  ViewController.swift
//  Duet
//
//  Created by Frederick Morlock on 7/19/17.
//  Copyright © 2017 Frederick Morlock. All rights reserved.
//

import UIKit
import PeerTalk.PTChannel

class ViewController: UIViewController {
    
    @IBOutlet var movieView: UIView!
    weak var serverChannel_: PTChannel?
    weak var peerChannel_: PTChannel?
    
    struct Streams {
        let input: InputStream
        let output: OutputStream
    }
    
    var boundStreams: Streams?
    var canWrite = false
    
    var mediaPlayer = VLCMediaPlayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let channel = PTChannel.init(delegate: self)
        channel?.listen(onPort: in_port_t(PTExampleProtocolIPv4PortNumber), iPv4Address: INADDR_LOOPBACK, callback: {(error: Error?) -> Void in
            if (error) != nil {
                print("Failed to listen on 127.0.0.1:" + String(PTExampleProtocolIPv4PortNumber))
                print("Error: " + String(describing: error))
            } else {
                print("Listening on 127.0.0.1:" + String(PTExampleProtocolIPv4PortNumber))
                self.serverChannel_ = channel
            }
        })
        
        var inputOrNil: InputStream? = nil
        var outputOrNil: OutputStream? = nil
        Stream.getBoundStreams(withBufferSize: 8096,
                               inputStream: &inputOrNil,
                               outputStream: &outputOrNil)
        guard let input = inputOrNil, let output = outputOrNil else {
            fatalError("On return of `getBoundStreams`, both `inputStream` and `outputStream` will contain non-nil streams.")
        }
        // configure and open output stream
        
        output.schedule(in: .current, forMode: .default)
        output.open()
        boundStreams = Streams(input: input, output: output)
        
        
        let media = VLCMedia(stream: boundStreams!.input)
        mediaPlayer.media = media
        mediaPlayer.drawable = movieView
        mediaPlayer.play()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        if ((serverChannel_) != nil) {
            serverChannel_?.close()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let aTouch = touches.first
        let point = aTouch!.location(in: self.view)
        let message: String = "d," + String(describing: point.x) + "," + String(describing: point.y)
        let payload: DispatchData = PTExampleTextDispatchDataWithString(message) as DispatchData
        
        peerChannel_?.sendFrame(ofType: UInt32(PTExampleFrameTypeTextMessage), tag: PTFrameNoTag, withPayload: payload as __DispatchData, callback: {(_ error: Error?) -> Void in
            if error != nil {
                print("Failed to send message: \(error)")
            }
        })
        print(point)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let aTouch = touches.first
        let point = aTouch!.location(in: self.view)
        let message: String = "m," + String(describing: point.x) + "," + String(describing: point.y)
        let payload: DispatchData = PTExampleTextDispatchDataWithString(message) as DispatchData
        
        peerChannel_?.sendFrame(ofType: UInt32(PTExampleFrameTypeTextMessage), tag: PTFrameNoTag, withPayload: payload as __DispatchData, callback: {(_ error: Error?) -> Void in
            if error != nil {
                print("Failed to send message: \(error)")
            }
        })
        print(point)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let aTouch = touches.first
        let point = aTouch!.location(in: self.view)
        let message: String = "u," + String(describing: point.x) + "," + String(describing: point.y)
        let payload: DispatchData = PTExampleTextDispatchDataWithString(message) as DispatchData
        
        peerChannel_?.sendFrame(ofType: UInt32(PTExampleFrameTypeTextMessage), tag: PTFrameNoTag, withPayload: payload as __DispatchData, callback: {(_ error: Error?) -> Void in
            if error != nil {
                print("Failed to send message: \(error)")
            }
        })
        print(point)
        // point.x and point.y have the coordinates of the touch
    }
    
    // MARK: Communicating
    func sendDeviceInfo() {
        if (peerChannel_ == nil) {
            return
        }
        
        print("Sending device info")
        
        // TODO
        let screenSize = UIScreen.main.bounds
        let dimString = String(describing: screenSize.width) + "x" + String(describing: screenSize.height)
        let payload: DispatchData = PTExampleTextDispatchDataWithString(dimString) as DispatchData
        
        peerChannel_?.sendFrame(ofType: UInt32(PTExampleFrameTypeDeviceInfo), tag: PTFrameNoTag, withPayload: payload as __DispatchData, callback: {(_ error: Error?) -> Void in
            if error != nil {
                print("Failed to send message: \(error)")
            }
        })
    }
    
    
}
// MARK: PTChannelDelegate
extension ViewController: PTChannelDelegate {
    func ioFrameChannel(_ channel: PTChannel, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        if channel != peerChannel_ {
            // A previous channel that has been canceled but not yet ended. Ignore.
            return false
        } else if type != UInt32(PTExampleFrameTypeTextMessage) && type != UInt32(PTExampleFrameTypePing) && type != UInt32(PTExampleFrameTypeData) {
            print("Unexpected frame of type \(type)")
            channel.close()
            return false
        }
        return true
    }
    
    func ioFrameChannel(_ channel: PTChannel, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
/* if (type == PTExampleFrameTypeTextMessage) {
         PTExampleTextFrame *textFrame = (PTExampleTextFrame*)payload.data;
         textFrame->length = ntohl(textFrame->length);
         NSString *message = [[NSString alloc] initWithBytes:textFrame->utf8text length:textFrame->length encoding:NSUTF8StringEncoding];
         [self appendOutputMessage:[NSString stringWithFormat:@"[%@]: %@", channel.userInfo, message]];
 } else if (type == PTExampleFrameTypePing && peerChannel_) {
         [peerChannel_ sendFrameOfType:PTExampleFrameTypePong tag:tag withPayload:nil callback:nil];
 }
 */
        if type == UInt32(PTExampleFrameTypeTextMessage) {
            let textFrame = PayloadConverter().convert(toString: payload);
            print(textFrame)
        } else if type == UInt32(PTExampleFrameTypeData) {
            if ((boundStreams?.output.hasSpaceAvailable)!) {
                let data = NSData.init(bytes: payload.data, length: payload.length)
                boundStreams?.output.write([UInt8](data), maxLength: payload.length)
            }
        } else if type == UInt32(PTExampleFrameTypePing) && (peerChannel_ != nil) {
            peerChannel_?.sendFrame(ofType: UInt32(PTExampleFrameTypePong), tag: tag, withPayload: nil, callback: nil)
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel, didEndWithError error: NSError) {
        if (error != nil) {
            print("Ended with error " + String(describing: error))
        } else {
            print("Disconnect from <add user info here>")
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel, didAcceptConnection otherChannel: PTChannel, from address: PTAddress) {
        if ((peerChannel_) != nil) {
            peerChannel_?.cancel()
        }
        
        peerChannel_ = otherChannel
        peerChannel_?.userInfo = address
        
        print("Connected to new user")
        
        self.sendDeviceInfo()
    }
 
 
}

