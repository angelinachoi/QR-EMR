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
    

    
    @IBAction func initiateQRReader(sender: UIBarButtonItem) { // Screen Button initiates camera and scan.
        if isReading == false {
            self.startReading()
            self.bbitemStart.title = "Stop"
            self.lblStatus.text = "Scanning for Code..."
            isReading = true

        } else {
            self.stopReading()
            self.bbitemStart.title = "Start"
            self.lblStatus.text = "Code Reader is not running."
            isReading = false

        }
        }
    var isReading = Bool()
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var audioPlayer: AVAudioPlayer?
    var qrCodeFrameView:UIView?
    var JSONsent = Bool()

    
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
                println(self.JSONsent)

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
        
        let informationSource = qrDict["infoSrce"] as! String!
        
        let fName = qrDict["patient"]?.valueForKey("fName") as! String!
        let mName = qrDict["patient"]?.valueForKey("mName") as! String!
        let lName = qrDict["patient"]?.valueForKey("lName") as! String!
        println(fName)
        println(mName)
        println(lName)
        
        let DOB = qrDict["patient"]?.valueForKey("dob") as! String!
        let gender = qrDict["patient"]?.valueForKey("gender") as! String!
        let idTYPE = qrDict["patient"]?.valueForKey("id-type") as! String!
        let id = qrDict["patient"]?.valueForKey("id") as! String!
        
        let unitNumber = qrDict["patient"]?.valueForKey("uNo") as! String!
        let streetNumber = qrDict["patient"]?.valueForKey("sNo") as! String!
        let streetName = qrDict["patient"]?.valueForKey("sName") as! String!
        let POBox = qrDict["patient"]?.valueForKey("POB") as! String!
        let city = qrDict["patient"]?.valueForKey("city") as! String!
        let pCode = qrDict["patient"]?.valueForKey("pCode") as! String! // Address Fields
        
        let email = qrDict["patient"]?.valueForKey("email") as! String!
        let phone = qrDict["patient"]?.valueForKey("phone") as! String!
        
        let school = qrDict["patient"]?.valueForKey("sch") as! String!
        let grade = qrDict["patient"]?.valueForKey("gr") as! String!
        // Patient Fields
        
        let immsDate = qrDict["immunization"]?.valueForKey("date") as! String!
        let immsCode = qrDict["immunization"]?.valueForKey("code") as! String!
        let agent = qrDict["immunization"]?.valueForKey("agent") as! String!
        let status = qrDict["immunization"]?.valueForKey("status") as! String!
        let lotNumber = qrDict["immunization"]?.valueForKey("lotNo") as! String!
        let expDate = qrDict["immunization"]?.valueForKey("expDate") as! String!
        let site = qrDict["immunization"]?.valueForKey("site") as! String!
        let route = qrDict["immunization"]?.valueForKey("route") as! String!
        let dose = qrDict["immunization"]?.valueForKey("dose") as! String!
        let manufacture = qrDict["immunization"]?.valueForKey("manufacture") as! String!
        let location = qrDict["immunization"]?.valueForKey("location") as! String!
        let disease = qrDict["immunization"]?.valueForKey("disease") as! String! // Disease Field: Newly Added
        // Immunization Fields
        println(immsCode) // NIL VALUE!!
        
        let conDate = qrDict["consent"]?.valueForKey("date") as! String!
        let conType = qrDict["consent"]?.valueForKey("type") as! String! // Consent Fields
        
        let relationship = qrDict["relation"]?.valueForKey("relationship") as! String!
        let rfName = qrDict["relation"]?.valueForKey("fName") as! String!
        let rmName = qrDict["relation"]?.valueForKey("mName") as! String!
        let rlName = qrDict["relation"]?.valueForKey("lName") as! String! // Relationship Fields
        
        let pName = qrDict["provider"]?.valueForKey("name") as! String!
        let pID = qrDict["provider"]?.valueForKey("ID") as! String!
        let pOrg = qrDict["provider"]?.valueForKey("org") as! String! // Provider Fields
        
        let date = NSDate()
        let dateFormatter = NSDateFormatter()
        let timeFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        var dateinformat: String = dateFormatter.stringFromDate(date)
        // Date and Time Fields
        
        let patientJSON: [NSString : AnyObject] = ["resource":["resourceType":"patient",
            "id":"patient1",
            "identifier":[["type":idTYPE,
                "value":id]],
            "name":["text":"\(fName) \(mName) \(lName)"],
            "telecom":[["system":"email","value":email],
                ["system":"phone","value":phone]],
            "gender":gender,
            "organization":school,
            "period":grade,
            
            "address":[["use":"home","line":["\(unitNumber) \(streetNumber) \(streetName) \(city) \(pCode) \(POBox)"],
                "city": city,
                "postalCode":pCode
                ]],
            
            "birthDate":DOB]]
        
        let vaccineJSON: [NSString : AnyObject] = ["resource":["resourceType":"immunization",
            "date":immsDate,
            "vaccineType":["coding":[["code":immsCode]],
                "text":agent],
            "patient":["reference":"#patient1"],
            "wasNotGiven":false,
            "reported":"false",
            "performer":["reference":"#practitioner1"],
            "manufacture":["reference":"#organization2"],
            "location":["reference":"#location1"],
            "lotNumber":lotNumber,
            "expirationDate":expDate,
            "site":["coding":[["code":site]]],
            "route":["coding":[["code":route]]],
            "doseQuantity":["value":dose]],
            "vaccinationProtocol": [["doseTarget":[["code":disease]]]],
            "description":status
        ]
        let consentJSON: [NSString : AnyObject] = ["resource":["resourceType":"ConsentDirective",
            "issued":conDate,
            "subject":["reference":"#patient1"],
            "signer":["type":["coding":[["code":conType]]],
                "party":["reference":"#RelatedPerson1"]]]]
        
        let relatedJSON: [NSString : AnyObject] = ["resource":["resourceType":"RelatedPerson",
            "id":"RelatedPerson1",
            "relationship":["coding":[["code":relationship]],
                "text":relationship],
            "name":[
                "text":"\(rfName) \(rmName) \(rlName)"]]]
        let orgJSON: [NSString : AnyObject] = ["resource":["resourceType":"Organization",
            "id":"organization1",
            "name":pOrg]]
        println(patientJSON)
        println(vaccineJSON)
        println(consentJSON)
        println(relatedJSON)
        println(orgJSON)
        
        var mainJSON: [NSString : AnyObject] = ["resourceType":"Bundle",
        "type":"document",
            "entry":[
            ["resource":["resourceType":"Composition",
            "date":dateinformat,
                "author":[["reference":"#practitioner1"],["reference":"#device1"]],
            "status":"final",
            "subject":[["reference":"#patient1"]],
                "author":[["reference":"#practitioner1"],
                    ["reference":"#device1"]]
            ]],
                ["resource":["resourceType":"practitioner",
                    "id":"practitioner1",
                    "identifier": [["value":pID]],
                    "name":["text":pName],
                    "practitionerRole":[
                "managineOrganization":[
                    "reference":"#organization1"]
                ]]],
                patientJSON,
                vaccineJSON,
                consentJSON,
                relatedJSON,
                orgJSON,
                ["resource":["resourceType":"Organization",
                    "id":"organization2",
                    "name":manufacture]
                ],
                ["resource":["resourceType":"location",
                    "id":"location1",
                    "name":location]
                ],
                ["resource":["resourceType":"Device",
                    "id":"#device1",
                    "identifier":[["value":"QR-EMR v1.0"]]]]]]
        
        // See outline of main JSON for FHIR
        println(mainJSON)
        println(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")

        /* Convert the dictionary into a data structure
        var error: NSError?
        let jsonData = NSJSONSerialization.dataWithJSONObject(mainJSON,
            options: .PrettyPrinted,
            error: &error)
        
        if let data = jsonData {
            if data.length > 0 && error == nil {
                println("Successfully serialized the dictionary into data")
                
                /* Then convert the data into a string */
                let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding)
                println("JSON String = \(jsonString)")
                
            }}

        */
        var err: NSError?
        var request = NSMutableURLRequest(URL: NSURL(string: "http://irfhir.mybluemix.net/rest/fhir/receipt/")!)
        var session = NSURLSession.sharedSession()
        request.HTTPMethod = "POST"
        
        request.HTTPBody = NSJSONSerialization.dataWithJSONObject(mainJSON, options: nil, error: &err)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let jsonData = NSJSONSerialization.dataWithJSONObject(mainJSON, options: .PrettyPrinted, error: &err)
        if let data = jsonData {
            if data.length > 0 && err == nil {
                println("Successfully serialized the dictionary into data")
                
                let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding)
                println("JSON String = \(jsonString)")
            } else if data.length == 0 && err == nil {
                println("No data was returned after serialization")
            } else if err != nil {
                println("Ann error happened = \(err)")
            }
        }
       // var json: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves, error: &err)
        var task = session.dataTaskWithRequest(request, completionHandler: {data, response, error -> Void in
            println("Response: \(response)")
            var strData = NSString(data: data, encoding: NSUTF8StringEncoding)
            println("Body: \(strData)")
            var err: NSError?
            var json: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: .MutableLeaves, error: &err)
            let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding)
            println("JSON String = \(jsonString)")
            if (err != nil) { // Did the JSONOBjectData constructor return an error?
                println(err!.localizedDescription)
                let jsonStr = NSString(data: data, encoding: NSUTF8StringEncoding)
                println("Error could not parse JSON: '\(jsonStr)'")
                
                let alert: UIAlertController = UIAlertController(title: "Error", message: "JSON could not be parsed.", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
            }
            else { // The JSONObjectWithData constructor didn't return an error.
                // Should still check to ensure that json has a value using optional binding.
                if let parseJSON: AnyObject = json {
                    // The parsedJSON is here, let's get the value for success out of it.
                    var success = parseJSON["success"] as? Int
                    println("Success: \(success)")
                    self.JSONsent = true
                    
                    let alert: UIAlertController = UIAlertController(title: "Success", message: "JSON was parsed and sent.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                    
                }
                else {
                    // json object was nil, something went wrong. Maybe server isn't running?
                    let jsonStr = NSString(data: data, encoding: NSUTF8StringEncoding)
                    println("Error could not parse JSON: \(jsonStr)")
                    self.JSONsent = false
                    
                    let alert: UIAlertController = UIAlertController(title: "Error", message: "JSON could not be parsed.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            }
        })
        task.resume()
    }
    
    func stopReading () { // Stops the QR Reader camera process
        captureSession?.stopRunning()
        captureSession = nil

        videoPreviewLayer?.removeFromSuperlayer()
    }
    
}