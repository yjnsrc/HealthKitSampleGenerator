//
//  Export.swift
//  Pods
//
//  Created by Michael Seemann on 02.10.15.
//
//

import Foundation
import HealthKit

/// Export errors
public enum ExportError: Error {
    /// if health is not available on the device
    case healthDataNotAvailable
    /// in case of illegal arguments
    case illegalArgumentError(String)
    /// in case of error during output
    case dataWriteError(String?)
}

/// what data should be exported
public enum HealthDataToExportType : String {
    /// all that is accessable
    case ALL                    = "All"
    /// only those that were written be the app
    case ADDED_BY_THIS_APP      = "Added by this app"
    /// only those that were generated by the app
    case GENERATED_BY_THIS_APP  = "Generated by this app"
    
    /// returns all values of this enumeration
    public static let allValues = [ALL, ADDED_BY_THIS_APP, GENERATED_BY_THIS_APP];
}

public typealias ExportCompletion = (Error?) -> Void
public typealias ExportProgress = (_ message: String, _ progressInPercent: NSNumber?) -> Void


class ExportOperation: Operation {
    
    var exportConfiguration: ExportConfiguration
    var exportTargets: [ExportTarget]
    var healthStore: HKHealthStore
    var onProgress: ExportProgress
    var onError: ExportCompletion
    var dataExporter: [DataExporter]
    
    init(
        exportConfiguration: ExportConfiguration,
        exportTargets: [ExportTarget],
        healthStore: HKHealthStore,
        dataExporter: [DataExporter],
        onProgress: @escaping ExportProgress,
        onError: @escaping ExportCompletion,
        completionBlock: (() -> Void)?
        ) {
        
        self.exportConfiguration = exportConfiguration
        self.exportTargets = exportTargets
        self.healthStore = healthStore
        self.dataExporter = dataExporter
        self.onProgress = onProgress
        self.onError = onError
        super.init()
        self.completionBlock = completionBlock
        self.qualityOfService = QualityOfService.userInteractive
    }
    
    override func main() {
        do {
            for exportTarget in exportTargets {
                try exportTarget.startExport();
            }

            
            let exporterCount = Double(dataExporter.count)
            
            for (index, exporter) in dataExporter.enumerated() {
                self.onProgress(exporter.message, Double(index)/exporterCount as NSNumber)
                try exporter.export(healthStore, exportTargets: exportTargets)
            }
            
            for exportTarget in exportTargets {
                try exportTarget.endExport();
            }
            
            self.onProgress("export done", 1.0)
        } catch let err {
            self.onError(err)
        }
        
    }
}

/// exporter for healthkit data
open class HealthKitDataExporter {
    
     let exportQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "export queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    let healthStore: HKHealthStore
    
    /// provide your instance of the HKHealthStore
    public init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }
    
    /**
     Exports the healthkit data to the specified targets with the provided configuration.
     - Parameter exportTargets: an array of EpxortTargets - you can specify more then one target if you need different formats of the data.
     - Parameter exportConfiguration: an object that specifies what and how the export should be done
     - Parameter onProgress: callback for progress informations
     - Parameter onCompletion: callback if the export is done or aborted with an Error.
    */
    open func export(exportTargets: [ExportTarget], exportConfiguration: ExportConfiguration, onProgress: @escaping ExportProgress, onCompletion: @escaping ExportCompletion) -> Void {
        
        if !HKHealthStore.isHealthDataAvailable() {
            onCompletion(ExportError.healthDataNotAvailable)
            return
        }
        
        for exportTarget in exportTargets {
            if(!exportTarget.isValid()){
                onCompletion(ExportError.illegalArgumentError("invalid export target \(exportTarget)"))
                return
            }
        }


 
        healthStore.requestAuthorization(toShare: nil, read: HealthKitConstants.authorizationReadTypes()) {
            (success, error) -> Void in
            /// TODO success error handling
            self.healthStore.preferredUnits(for: HealthKitConstants.healthKitQuantityTypes) {
                (typeMap, error) in
        
                let dataExporter : [DataExporter] = self.getDataExporters(exportConfiguration, typeMap: typeMap)
                        
                let exportOperation = ExportOperation(
                    exportConfiguration: exportConfiguration,
                    exportTargets: exportTargets,
                    healthStore: self.healthStore,
                    dataExporter: dataExporter,
                    onProgress: onProgress,
                    onError: {(err:Error?) -> Void in
                        onCompletion(err)
                    },
                    completionBlock:{
                        onCompletion(nil)
                    }
                )
                
                self.exportQueue.addOperation(exportOperation)
            }
        }
        
    }
    
    internal func getDataExporters(_ exportConfiguration: ExportConfiguration, typeMap: [HKQuantityType : HKUnit]) -> [DataExporter]{
        var result : [DataExporter] = []
        
        result.append(MetaDataExporter(exportConfiguration: exportConfiguration))
        
        // user data are only exported if type is ALL, beacause the app can never write these data!
        if exportConfiguration.exportType == .ALL {
            result.append(UserDataExporter(exportConfiguration: exportConfiguration))
        }
        
        // add all Qunatity types
        for(type, unit) in typeMap {
            result.append(QuantityTypeDataExporter(exportConfiguration: exportConfiguration, type: type , unit: unit))
        }
        
        // add all Category types
        for categoryType in HealthKitConstants.healthKitCategoryTypes {
            result.append(CategoryTypeDataExporter(exportConfiguration: exportConfiguration, type: categoryType))
        }
        
        // add all correlation types
        for correlationType in HealthKitConstants.healthKitCorrelationTypes {
            result.append(CorrelationTypeDataExporter(exportConfiguration: exportConfiguration, type: correlationType, typeMap:typeMap))
        }
        
        // appen the workout data type
        result.append(WorkoutDataExporter(exportConfiguration: exportConfiguration))
        
        return result
    }

}