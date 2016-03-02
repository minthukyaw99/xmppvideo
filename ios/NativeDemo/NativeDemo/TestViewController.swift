//
//  NativeDemoViewController.swift
//  NativeDemo
//
//  Created by Min Thu Kyaw on 12/14/15.
//  Copyright © 2015 Ericsson Research. All rights reserved.
//

import UIKit;


class TestViewController: UIViewController,PeerServerHandlerDelegate,OpenWebRTCNativeHandlerDelegate
{
    
    /*
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    */

    
    @IBOutlet var callButtom: UIBarButtonItem!
    @IBOutlet var hangupButtom: UIBarButtonItem!
    
    
    
    @IBOutlet var selfView: OpenWebRTCVideoView!
    @IBOutlet var remoteView: OpenWebRTCVideoView!
    
    
    var nativeHandler:OpenWebRTCNativeHandler!
    var cameras:NSMutableArray = [];
    var currentCameraIndex : Int = 0;
    var roomID:String = "";
    var peerID:String?;
    var peerSever:PeerServerHandler!
    
    @IBAction func callButtonTapped(sender: AnyObject)
    {
        callButtom.enabled = false
        hangupButtom.enabled = true
        nativeHandler.initiateCall()
    }
    
    @IBAction func hangupButtonTapped(sender: AnyObject)
    {
        nativeHandler.terminateCall()
        peerSever.leave()
        callButtom.enabled = false
        hangupButtom.enabled = false
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        
        self.navigationController?.setToolbarHidden(false, animated: false)
        
        nativeHandler = OpenWebRTCNativeHandler.init(delegate: self)
        
        // Setup the video windows.
        self.selfView.hidden = true;
        nativeHandler.setSelfView(self.selfView)
        nativeHandler.setRemoteView(self.remoteView)
        
        nativeHandler.addSTUNServerWithAddress("mmt-stun.verkstad.net", port: 3478)
        
        nativeHandler.addTURNServerWithAddress("mmt-turn.verkstad.net", port: 443, username: "webrtc", password: "secret", isTCP: false)
        
        callButtom.enabled = false
        hangupButtom.enabled = false
        
        peerSever = PeerServerHandler(baseURL: "http://demo.openwebrtc.org:38080")
        peerSever.delegate = self;
        
        
        // Configure OpenWebRTC with media settings.
        
        let attrs: VideoAttributes = VideoAttributes.loadFromSettings();
        print("Video Setting From TestView: \(attrs)")
        
        let settings: OpenWebRTCSettings = OpenWebRTCSettings.init(defaults: ());
        
        settings.videoFramerate = Double(attrs.framerate)
        
        settings.videoBitrate = Int32(attrs.bitrate);
        settings.videoWidth = Int32(attrs.width)
        settings.videoHeight = Int32(attrs.height);
        nativeHandler.settings = settings;
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector(sendCurrentOrientation()), name: UIDeviceOrientationDidChangeNotification, object: nil)
        
        
    }
    
    override func viewDidAppear(animated: Bool) {
        presentRoomInputView()
    }
    
    func presentRoomInputView()
    {
        let alert:UIAlertController = UIAlertController(title: "Enter Room ID", message: "User the same ID to connect 2 clients", preferredStyle: UIAlertControllerStyle.Alert)
        
        let ok : UIAlertAction = UIAlertAction(title: "Done", style: UIAlertActionStyle.Default) { (UIAlertAction) -> Void in
            let roomTextField: UITextField = alert.textFields![0]
            let room : String = roomTextField.text!
            
            if(room != "")
            {
                self.joinButtonTapped(room)
            }
            else
            {
                self.presentRoomInputView()
            }
            
        }
        
        alert.addAction(ok)
        
        alert.addTextFieldWithConfigurationHandler { ( textField:UITextField) -> Void in
            textField.keyboardType = UIKeyboardType.Default
        }
        
        presentViewController(alert, animated: true, completion: nil)
    }
    
    func joinButtonTapped(roomID:String)
    {
        print("Joining room with ID: \(roomID)")
        
        self.roomID = roomID
        
        nativeHandler.startGetCaptureSourcesForAudio(true, video: true)
        
        let deviceID:String = (UIDevice.currentDevice().identifierForVendor?.UUIDString)!
        print(deviceID)
        self.peerSever.joinRoom(roomID, withDeviceID: deviceID)
    }
    
    //pragma mark - OpenWebRTCNativeHandlerDelegate
    func answerGenerated(answer: [NSObject : AnyObject]!) {
        
        print("Answer Generated: \(answer)")
        let d:Dictionary = ["sdp" : answer];
        
        var jsonData : NSData?
        do {
            try jsonData = NSJSONSerialization.dataWithJSONObject(d, options: NSJSONWritingOptions.PrettyPrinted)
        } catch _ {
            let jsonError:String = "jst error"
            print(jsonError)
        }
        
        let answeringString:String = NSString(data: jsonData!, encoding:NSUTF8StringEncoding) as! String
        
        if((self.peerID) != nil)
        {
            peerSever.sendMessage(answeringString, toPeer: self.peerID)
        }
    }
    
    func offerGenerated(offer: [NSObject : AnyObject]!) {
        print("Offer generated: \(offer)")
        let d:Dictionary = ["sdp":offer]
        var jsonData : NSData?
        do {
            try jsonData = NSJSONSerialization.dataWithJSONObject(d, options: NSJSONWritingOptions.PrettyPrinted)
        } catch _ {
            let jsonError: String = "this is just eror"
            print(jsonError)
        }
        let offerString:String = NSString(data: jsonData!, encoding:NSUTF8StringEncoding) as! String
        
        if((self.peerID) != nil)
        {
            peerSever.sendMessage(offerString, toPeer: self.peerID)
        }
        
    }
    
    func candidateGenerate(candidate: String!) {
        print("Candidate generated: \(candidate)")
        if(self.peerID != nil)
        {
            print("sending candidate to peer: \(peerID)")
            peerSever.sendMessage(candidate, toPeer: self.peerID)
        }
    }
    
    func gotLocalSources(sources: [AnyObject]!) {
        print("Get Local Sources: \(sources)")
        cameras = NSMutableArray(capacity: sources.count)
        for source in sources
        {
            if source["mediaType"] as! String == "video"{
                let name = source["name"]
                cameras.addObject(name!!)
            }
        }
        print("Found cameras : \(cameras)")
        
        nativeHandler.videoView(self.selfView, setMirrored: false)
        self.selfView.hidden = false;
    }
    
    func gotRemoteSource(source: [NSObject : AnyObject]!) {
        print("gotRemoteSource : \(source)")
        callButtom.enabled = false
        hangupButtom.enabled = true
        self.sendCurrentOrientation()
    }
    
    func sendCurrentOrientation()
    {
        var orientation: Int
        
        switch(UIDevice.currentDevice().orientation)
        {
            
        case UIDeviceOrientation.LandscapeLeft:
            orientation = 180
            break;
        case UIDeviceOrientation.LandscapeRight:
            orientation = 0;
            break;
        case UIDeviceOrientation.Portrait:
            orientation = 90;
            break;
        case UIDeviceOrientation.PortraitUpsideDown:
            orientation = 270;
            break;
        default:
            orientation = 0;
            break;
        }
        
        
        nativeHandler.videoView(self.selfView, setVideoRotation: -90)
        
        let message = "{\(orientation) : ld}";
        
        if  (self.peerID != nil) {
            print("[PeerServerHandler] Sending orientation msg: \(message)");
            peerSever.sendMessage(message, toPeer: self.peerID!)
        }
    }
    
    
    
    //pragma mark - PeerServerHandlerDelegate
    
    
    func peerServer(peerServer: PeerServerHandler!, failedToJoinRoom roomID: String!, withError error: NSError!) {
        self.presentErrorWithMessageerror(description)
    }
    
    func presentErrorWithMessageerror(message: String)
    {
        let alert: UIAlertController = UIAlertController(title: "Error!", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        
        let ok: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
        
        alert.addAction(ok)
        
        self.presentViewController(alert, animated: true, completion: nil)
        
    }
    
    func peerServer(peerServer: PeerServerHandler!, roomIsFull roomID: String!) {
        print("ROOisFull \(roomID)");
    }
    
    
    func peerServer(peerServer: PeerServerHandler!, peer peerID: String!, joinedRoom roomID: String!) {
        print("peer \(peerID) joinedRoom \(roomID)")
        callButtom.enabled = true
        self.peerID = peerID
        self.sendCurrentOrientation()
    }
    
    func peerServer(peerServer: PeerServerHandler!, peer peerID: String!, leftRoom roomID: String!) {
        print("peer \(peerID) leftRoom: \(roomID)");
        self.peerID = nil
    }
    
    
    func peerServer(peerServer: PeerServerHandler!, peer peerID: String!, sentOffer offer: String!) {
        print("this is Offer >>>>>>>>>>>>\(offer)")
        print("peer : \(peerID) sendOffer: \(offer)")
        nativeHandler.handleOfferReceived(offer)
    }
    
    
    func peerServer(peerServer: PeerServerHandler!, peer peerID: String!, sentAnswer answer: String!) {
        print("peer : \(peerID) sentAnser: \(answer)")
        nativeHandler.handleAnswerReceived(answer)
    }
    
    
    func peerServer(peerServer: PeerServerHandler!, peer peerID: String!, sentCandidate candidate: [NSObject : AnyObject]!) {
        print("peer :\(peerID) sentCandidate: \(candidate)")
        nativeHandler.handleRemoteCandidateReceived(candidate)
    }
    
    
    func peerServer(peerServer: PeerServerHandler!, peer peerID: String!, sentOrientation orientation: Int) {
        print("Rotation remote view to: \(orientation)")
        nativeHandler.videoView(self.remoteView, setVideoRotation: orientation)
    }
    
    func peerServer(peerServer: PeerServerHandler!, failedToSendDataWithError error: NSError!) {
        self.presentErrorWithMessageerror(description)
    }
    
    
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    }
    */
    
}
