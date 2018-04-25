//
//  ViewController.swift
//  CloudKitExample
//
//  Created by Douglas Alexander on 4/20/18.
//  Copyright © 2018 Douglas Alexander. All rights reserved.
//

import UIKit
import CloudKit
import MobileCoreServices

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var commentsField: UITextView!
    @IBOutlet weak var imageView: UIImageView!
    
    let container = CKContainer.default
    var privateDatabase: CKDatabase?
    var currentRecord: CKRecord?
    var photoURL: URL?
    var recordZone: CKRecordZone?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addressField.layer.borderWidth = 1
        addressField.layer.borderColor = UIColor.lightGray.cgColor
        
        commentsField.layer.borderWidth = 1
        commentsField.layer.borderColor = UIColor.lightGray.cgColor
        
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.lightGray.cgColor
        
        performSetup()
    }

    func performSetup() {
        privateDatabase = container().privateCloudDatabase
        
        // init recordZone
        recordZone = CKRecordZone(zoneName: "HouseZone")
        
        // save the record to a private database
        if let zone = recordZone {
            privateDatabase?.save(zone, completionHandler: {(recordZone, error) in
                if (error != nil) {
                    self.notifyUser("Record Zone Error", message: "Failed to create custom record zone.")
                } else {
                    print("Saved record zone")
                }
            })
            let predicate = NSPredicate(format: "TRUEPREDICATE")
            let subscription = CKQuerySubscription(recordType: "Houses", predicate: predicate
                , options: .firesOnRecordCreation)
            
            let notificationInfo = CKNotificationInfo()
            
            notificationInfo.alertBody = " A new House was added!"
            notificationInfo.shouldBadge = true
            
            subscription.notificationInfo = notificationInfo
            
            privateDatabase?.save(subscription, completionHandler: ({returnRecord, error in
                if let err = error {
                    print("subscription failed %@", err.localizedDescription)
                } else {
                    DispatchQueue.main.async {
                        self.notifyUser("Success", message: "subsription set up successfully")
                    }
                }
            }))
        }
    }
    
    func fetchRecord (_ recordID: CKRecordID) -> Void {
        // fetch the record for passed in recordID
        privateDatabase?.fetch(withRecordID: recordID, completionHandler: ({ record, error in
            if let err = error {
                DispatchQueue.main.async {
                    self.notifyUser("Fetch Error", message: err.localizedDescription)
                }
            } else {
                // display the data to the user
                DispatchQueue.main.async() {
                    if let newRecord = record {
                        self.currentRecord = newRecord
                        self.addressField.text = newRecord.object(forKey: "address") as? String
                        self.commentsField.text = newRecord.object(forKey: "comment") as? String
                        let photo = newRecord.object(forKey: "photo") as! CKAsset
                        if let image = UIImage(contentsOfFile: photo.fileURL.path) {
                            self.imageView.image = image
                            self.photoURL = self.saveImageToFile(image)
                        }
                    }
                }
            }
        }))
    }
    
    
    // MARK: Tool Bar Buttons
    @IBAction func saveRecord(_ sender: Any) {
        var asset: CKAsset?
        
        // determine if a valid the photo exists
        if (photoURL == nil) {
            notifyUser("No Photo", message: "Use the Photo option to chose a photo for the record")
            return
        } else {
            // create a new asset with the URL to the photo
            asset = CKAsset(fileURL: photoURL!)
        }
        
        if let zoneID = recordZone?.zoneID {
            // create a new record and assign a record type of Houses
            let myRecord = CKRecord(recordType: "Houses", zoneID: zoneID)
            
            // add objects to the record
            myRecord.setObject(addressField.text as CKRecordValue?, forKey: "address")
            myRecord.setObject(commentsField.text as CKRecordValue?, forKey: "comment")
            myRecord.setObject(asset, forKey: "photo")
            
            // ceate a CK records operation
            let modiyRecordsOpertion = CKModifyRecordsOperation (recordsToSave: [myRecord], recordIDsToDelete: nil)
            
            // create configuration
            let configuration = CKOperationConfiguration()
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 10
            
            modiyRecordsOpertion.configuration = configuration
            
            // create a completion handler
            modiyRecordsOpertion.modifyRecordsCompletionBlock = { records, recordIDs, error in
                if let err = error {
                    self.notifyUser("Save Error", message: err.localizedDescription)
                } else {
                    // dispatch on main que as the CK operation takes place on a separate que
                    DispatchQueue.main.async {
                        self.notifyUser("Success", message: "Record saved sucecssfully")
                    }
                    self.currentRecord = myRecord
                }
            }
            
            // start the add process
            privateDatabase?.add(modiyRecordsOpertion)
        }
    }
    
    @IBAction func queryRecord(_ sender: Any) {
        if let text = addressField.text {
            
            // create the search predicate
            let predicate = NSPredicate(format: "address = %@", text)
            
            // create the query for the record type "houses"
            let query = CKQuery(recordType: "Houses", predicate: predicate)
            
            // perform the query with completion handler
            privateDatabase?.perform(query, inZoneWith: recordZone?.zoneID, completionHandler: ({results, error in
                if let err = error {
                    DispatchQueue.main.async {
                        // notify user of error
                        self.notifyUser("Cloud Access Error", message: err.localizedDescription)
                    }
                } else {
                    // if the results has one of more records then a match was found.
                    if let resultsArray = results, resultsArray.count > 0 {
                        let record = resultsArray[0]
                        self.currentRecord = record
                        DispatchQueue.main.async() {
                            self.commentsField.text = record.object(forKey: "comment") as! String
                            let photo = record.object(forKey: "photo") as! CKAsset
                            let image = UIImage(contentsOfFile: photo.fileURL.path)
                            
                            if let img = image {
                                self.imageView.image = img
                                self.photoURL = self.saveImageToFile(img)
                            }
                            
                        }
                    } else {
                        DispatchQueue.main.async() {
                            // notify user no matches found
                            self.notifyUser("Not Match Found", message: "No record matching the address was found!")
                        }
                    }
                }
            }))
        }
    }
   
    @IBAction func selectPhoto(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        
        imagePicker.delegate = self
        
        // enable the user to select a photo from the library
        imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func updateRecord(_ sender: Any) {
        
        // if a record has been selected
        if let record = currentRecord, let url = photoURL {
            let asset = CKAsset(fileURL: url)

            // update the record entires
            record.setObject(addressField.text as CKRecordValue?, forKey: "address")
            record.setObject(commentsField.text as CKRecordValue?, forKey: "comment")
            record.setObject(asset, forKey: "photo")
            
            // save updated rdecord
            privateDatabase?.save(record, completionHandler: ({returnRecord, error in
                if let err = error {
                    DispatchQueue.main.async() {
                        self.notifyUser("Update Error", message: err.localizedDescription)
                    }
                } else {
                    DispatchQueue.main.async() {
                        self.notifyUser("Success", message: "Record update successfully")
                    }
                }
            }))
        } else {
            notifyUser("No Record Selected", message: "Use Query to elect a record to update")
        }
    }
    
    @IBAction func deleteRecord(_ sender: Any) {
        if let record = currentRecord {
            privateDatabase?.delete(withRecordID: record.recordID, completionHandler: ({returnRecord, error in
                if let err = error {
                    DispatchQueue.main.async() {
                        self.notifyUser("Delete Error", message: err.localizedDescription)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.notifyUser("Success", message: "Record deleted successfully!")
                    }
                }
            }))
        } else {
            notifyUser("No Record Selected", message: "Use Quest to select a recodr to delgte.")
        }
    }
    
    // hide the keyboard
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        addressField.endEditing(true)
        commentsField.endEditing(true)
    }
    
    // MARK: delegate method for photo selection / deletion
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true, completion: nil)
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imageView.image = image
        photoURL = saveImageToFile(image)
    }
    
    // dismiss the image viewer
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // save the image to file
    func saveImageToFile(_ image: UIImage) -> URL {
        
        // construct the file URL
        let fileMgr = FileManager.default
        let dirPaths = fileMgr.urls(for: .documentDirectory, in: .userDomainMask)
        let fileURL = dirPaths[0].appendingPathComponent("currentImage.jpg")
        
        // write the image to the file in JPEG format
        if let renderedJPEGData = UIImageJPEGRepresentation(image, 0.5) {
            try! renderedJPEGData.write(to: fileURL)
        }
        
        return fileURL
    }
    
    //MARK: user notification method
    func notifyUser(_ title: String, message: String) -> Void{
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

