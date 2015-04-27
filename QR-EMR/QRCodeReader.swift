//
//  ViewController.swift
//  QRCodeReader
//
//  Created by Angelina Choi on 2015-01-08.
//  Copyright (c) 2015 Angelina Choi. All rights reserved.
//

import UIKit
import AVFoundation // This allows control of the device's camera.

class QRCodeReader: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var bbitemStart: UIBarButtonItem!
    @IBOutlet weak var buttonBar: UIToolbar! // Outlets for QR Reader Screen
    
    @IBOutlet weak var instructionLabel: UITextView!
    
    @IBAction func initiateQRReader(sender: UIBarButtonItem) { // Screen Button initiates camera and scan.
        if isReading == false {
            self.startReading()
            self.bbitemStart.title = "Stop"
            self.lblStatus.text = "Scanning for Code..."
            isReading = true
            instructionLabel.hidden = true
        } else {
            self.stopReading()
            self.bbitemStart.title = "Start"
            self.lblStatus.text = "Code Reader is not running."
            isReading = false
            instructionLabel.hidden = false
        }
        }
    
    let ValidCharacterSet: NSCharacterSet = NSCharacterSet(charactersInString: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890,")
    var isReading = Bool()
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var audioPlayer: AVAudioPlayer?
    var qrCodeFrameView:UIView?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var isReading = false
        var captureSession: AVCaptureSession? = nil
        // initiateQRReader(initiateButton)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) { // keep camera rotation consistent with interface orientation
        switch UIDevice.currentDevice().orientation {
        case UIDeviceOrientation.Portrait:
            self.videoPreviewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.Portrait
        case UIDeviceOrientation.LandscapeLeft:
            self.videoPreviewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
        case UIDeviceOrientation.LandscapeRight:
            self.videoPreviewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.LandscapeLeft
        case UIDeviceOrientation.PortraitUpsideDown:
            self.videoPreviewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.PortraitUpsideDown
        default:
            () // Do nothing
        }
    }

    func startReading () -> Bool {
        var error: NSError?
        let captureDevice = AVCaptureDevice .defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        let input: AnyObject! = AVCaptureDeviceInput.deviceInputWithDevice(captureDevice, error: &error)
        if (error != nil) {
            // If any error occurs, log the description of it and discontinue the program.
            println("\(error?.localizedDescription)")
            return false
        }
        captureSession = AVCaptureSession() // Initialize the captureSessionObject
        captureSession?.addInput(input as! AVCaptureInput) // Set the input device on the capture session.
        
        // Initialize a AVCaptureMetadaOutput object and set it as the output device to the capture session.
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession?.addOutput(captureMetadataOutput)
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        videoPreviewLayer?.bounds = self.view.bounds
        videoPreviewLayer?.frame = view.layer.bounds
        videoPreviewLayer?.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds))
        
        view.layer.addSublayer(videoPreviewLayer)
        captureSession?.startRunning() // Start video capture.
        
        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()
        qrCodeFrameView?.layer.borderWidth = 2
        view.addSubview(qrCodeFrameView!)
        view.bringSubviewToFront(qrCodeFrameView!)
        view.bringSubviewToFront(lblStatus) // Move the message label to the top view
        view.bringSubviewToFront(buttonBar) // And the toolbar as well
        return true
    }
    
    func captureOutput (captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects == nil || metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRectZero
            lblStatus.text = "No code detected"
            return
        }
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObjectTypeQRCode {
            // If the found metadata is equal to the QR code metadata then update the status label
            let qrCodeObject = videoPreviewLayer?.transformedMetadataObjectForMetadataObject(metadataObj as AVMetadataMachineReadableCodeObject) as! AVMetadataMachineReadableCodeObject
            qrCodeFrameView?.frame = qrCodeObject.bounds;
            
            if metadataObj.stringValue != nil {
                var qrCode = metadataObj.stringValue
                analyzeQRLabel(qrCode)
            }
        }
    }
    
    func analyzeQRLabel(qrLabel: String) { // Analyze QR Label to get properties
        if qrLabel.rangeOfString("QR-EMR") != nil { // If QR Label is a valid QR-EMR
            qrCodeFrameView?.layer.borderColor = UIColor.greenColor().CGColor
            lblStatus.text = "Valid QR Label detected"
            
            let alert: UIAlertController = UIAlertController(title: "QR Label Decoded", message: "\(qrLabel)\n\nWould you like to submit this information to the server?", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default, handler: { ( action: UIAlertAction!) in
                self.convertAndSend(qrLabel)
            }))
            alert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)

        } else { // if QR label is invalid for QR-EMR
            
            qrCodeFrameView?.layer.borderColor = UIColor.redColor().CGColor
            lblStatus.text = "Invalid QR Label detected"
        }
    }
    
    func retrieveJsonFromData(data: NSData) -> NSDictionary {
        
        /* Now try to deserialize the JSON object into a dictionary */
        var error: NSError?
        
        let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data,
            options: .AllowFragments,
            error: &error)
        
        if  error == nil {
            
            println("Successfully deserialized...")
            
            if jsonObject is NSDictionary{
                let deserializedDictionary = jsonObject as! NSDictionary
                println("Deserialized JSON Dictionary = \(deserializedDictionary)")
                return deserializedDictionary
            } else {
                /* Some other object was returned. We don't know how to
                deal with this situation because the deserializer only
                returns dictionaries or arrays */
            }
        }
        else if error != nil {
            println("An error happened while deserializing the JSON data.")
        }
        return NSDictionary()
    }
    
    func convertAndSend (stringSubject: String) { // Convert fields in QR into JSON format
        let qrJSON = (stringSubject as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        let qrDict: NSDictionary = retrieveJsonFromData(qrJSON!) // Use JSON to parse code
        
        let fName = qrDict["patient"]?.valueForKey("fName") as! String!
        let mName = qrDict["patient"]?.valueForKey("mName") as! String!
        let lName = qrDict["patient"]?.valueForKey("lName") as! String!
        
        let DOB = qrDict["patient"]?.valueForKey("dob") as! String!
        let gender = qrDict["patient"]?.valueForKey("gender") as! String!
        let idTYPE = qrDict["patient"]?.valueForKey("id-type") as! String!
        let id = qrDict["patient"]?.valueForKey("id") as! String!
        
        let email = qrDict["patient"]?.valueForKey("email") as! String!
        let phone = qrDict["patient"]?.valueForKey("phone") as! String!
        // Patient Fields
        
        let immsDate = qrDict["immunization"]?.valueForKey("date") as! String!
        let immsCode = qrDict["immunization"]?.valueForKey("code") as! String!
        let agent = qrDict["immunization"]?.valueForKey("agent") as! String!
        let lotNumber = qrDict["immunization"]?.valueForKey("lotNo") as! String!
        let expDate = qrDict["immunization"]?.valueForKey("expDate") as! String!
        let site = qrDict["immunization"]?.valueForKey("site") as! String!
        let route = qrDict["immunization"]?.valueForKey("route") as! String!
        let dose = qrDict["immunization"]?.valueForKey("dose") as! String!
        let manufacture = qrDict["immunization"]?.valueForKey("manufacture") as! String!
        let location = qrDict["immunization"]?.valueForKey("location") as! String!
        // Immunization Fields
        
        let conDate = qrDict["consent"]?.valueForKey("date") as! String!
        let conType = qrDict["consent"]?.valueForKey("type") as! String!
        // Consent Fields
        
        let relationship = qrDict["relation"]?.valueForKey("relationship") as! String!
        let rfName = qrDict["relation"]?.valueForKey("fName") as! String!
        let rmName = qrDict["relation"]?.valueForKey("mName") as! String!
        let rlName = qrDict["relation"]?.valueForKey("lName") as! String!
        // Relationship Fields
        
        let pName = qrDict["provider"]?.valueForKey("name") as! String!
        let pID = qrDict["provider"]?.valueForKey("ID") as! String!
        let pOrg = qrDict["provider"]?.valueForKey("org") as! String!
        // Provider Fields
        
        let a: Dictionary = ["resourceType":"Bundle",
        "type":"document",
        "entry": {
            ["resource": ["resourceType":"Composition",
            "date":"DTAESTAMP REQUIRED",
            "status":"final",
            "subject": {["reference": "#patient1"]},
                "author": {["reference": "#practitioner1"], ["reference": "#device1"]}]]
        }]
    }
    
    func stopReading () { // Stops the QR Reader camera process
        captureSession?.stopRunning()
        captureSession = nil
        
        videoPreviewLayer?.removeFromSuperlayer() }
    
}