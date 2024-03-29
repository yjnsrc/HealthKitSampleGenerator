//
//  ExportViewController.swift
//  HealthKitSampleGenerator
//
//  Created by Michael Seemann on 02.10.15.
//  Copyright © 2015 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import HealthKit
import HealthKitSampleGenerator

class ExportViewController : UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var tfProfileName:       UITextField!
    @IBOutlet weak var btnExport:           UIButton!
    @IBOutlet weak var avExporting:         UIActivityIndicatorView!
    @IBOutlet weak var lbOutputFileName:    UILabel!
    @IBOutlet weak var swOverwriteIfExist:  UISwitch!
    @IBOutlet weak var scExportType:        UISegmentedControl!
    @IBOutlet weak var lbExportDescription: UILabel!
    @IBOutlet weak var pvExportProgress:    UIProgressView!
    @IBOutlet weak var lbExportMessages:    UILabel!
    
    let healthStore  = HKHealthStore()
    
    var exportConfigurationValid = false {
        didSet {
            btnExport.isEnabled = exportConfigurationValid
        }
    }
    
    var exportConfiguration : HealthDataFullExportConfiguration? {
        didSet {
            if let config = exportConfiguration {
                switch config.exportType {
                case .ALL:
                    self.lbExportDescription.text = "All accessable health data wil be exported."
                case .ADDED_BY_THIS_APP :
                    self.lbExportDescription.text = "All health data will be exported, that has been added by this app - e.g. they are imported from a profile."
                case .GENERATED_BY_THIS_APP :
                    self.lbExportDescription.text = "All health data will be exported that has been generated by this app - e.g. they are not created through an import of a profile but generated by code. "
                }
            }
        }
    }
    
    var exportTarget : JsonSingleDocAsFileExportTarget? {
        didSet {
            if let target = exportTarget {
                lbOutputFileName.text = target.outputFileName
            }
            
        }
    }
    
    var exportInProgress = false {
        didSet {
            avExporting.isHidden      = !exportInProgress
            btnExport.isEnabled       = !exportInProgress
            pvExportProgress.isHidden = !exportInProgress
        }
    }
    
    var outputFielName: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tfProfileName.text                  = "output" + UIUtil.sharedInstance.formatDateForFileName(date: NSDate())
        tfProfileName.addTarget(self, action: #selector(textFieldDidChange(_:)), for: UIControlEvents.editingChanged)
        tfProfileName.delegate              = self
        
        scExportType.selectedSegmentIndex   = HealthDataToExportType.allValues.index(of:HealthDataToExportType.ALL)!
        
        lbExportMessages.text               = ""
        
        exportInProgress = false
        createAndAnalyzeExportConfiguration()
    }
    
    @IBAction func scEpxortDataTypeChanged(sender: AnyObject) {
        createAndAnalyzeExportConfiguration()
    }
    
    @IBAction func doExport(_: AnyObject) {
        exportInProgress = true
        self.pvExportProgress.progress = 0.0
        
        HealthKitDataExporter(healthStore:healthStore).export(
            
            exportTargets: [exportTarget!],
            exportConfiguration: exportConfiguration!,
            
            onProgress: {(message: String, progressInPercent: NSNumber?)->Void in
                DispatchQueue.main.async {
                    self.lbExportMessages.text = message
                    if let progress = progressInPercent {
                        self.pvExportProgress.progress = progress.floatValue
                    }
                }
            },
            
            onCompletion: {(error: Error?)-> Void in
                DispatchQueue.main.async {
                    if let exportError = error {
                        self.lbExportMessages.text = "Export error: \(exportError)"
                        print(exportError)
                    }
                    
                    self.exportInProgress = false
                }
            }
        )
    }
    
    @IBAction func swOverwriteIfExistChanged(sender: AnyObject) {
        createAndAnalyzeExportConfiguration()
    }
    
    func createAndAnalyzeExportConfiguration(){
        var fileName = "output"
        if let text = tfProfileName.text, !text.isEmpty {
            fileName = FileNameUtil.normalizeName(text)
        }
        
        let documentsUrl    = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        print(documentsUrl)
        let outputFileName  = documentsUrl.appendingPathComponent(fileName+".json.hsg").path
        
        exportTarget = JsonSingleDocAsFileExportTarget(
            outputFileName: outputFileName,
            overwriteIfExist: swOverwriteIfExist.isOn)
        
        exportConfiguration = HealthDataFullExportConfiguration(profileName: tfProfileName.text!, exportType: HealthDataToExportType.allValues[scExportType.selectedSegmentIndex])

        
        exportConfigurationValid = exportTarget!.isValid()
    }

    @objc func textFieldDidChange(_: UITextField) {
       createAndAnalyzeExportConfiguration()
    }

    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
