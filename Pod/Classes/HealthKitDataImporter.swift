//
//  Import.swift
//  Pods
//
//  Created by Michael Seemann on 22.10.15.
//
//

import Foundation
import HealthKit

// {"metaData":{"creationDate":1445344592172.305,"profileName":"output","version":"1.0.0","type":"JsonSingleDocExportTarget"},
/**
    A Json Output Handler that reads the metadata from a profle file
*/
class MetaDataOutputJsonHandler: DefaultJsonHandler {
    
    var name:String?
    var collectProperties = false
    var metaDataDict:Dictionary<String,AnyObject> = [:]
    var cancel = false
    
    func getMetaData() -> Dictionary<String,AnyObject> {
        return metaDataDict
    }
    
    override func name(_ name: String) {
        self.name = name
    }
    
    override func startObject() {
        collectProperties = name == "metaData"
    }
    
    override func endObject() {
        if collectProperties {
            collectProperties = false
            cancel = true
        }
    }
    
    override func stringValue(_ value: String){
        if collectProperties {
            metaDataDict[name!] = value as AnyObject
        }
    }
    override func numberValue(_ value: NSNumber){
        if collectProperties {
            metaDataDict[name!] = value
        }
    }
    
    override func shouldCancelReadingTheJson() -> Bool {
        return cancel;
    }
}

///JsonProtocollHandler that reads every HealthKitSampletype from the json stream
class SampleOutputJsonHandler: JsonHandlerProtocol {

    class SampleContext : CustomStringConvertible {
        
        let type: JsonContextType
        var parent: SampleContext?
        var dict:Dictionary<String, AnyObject> = [:]
        var name:String? = nil
        var childs : [SampleContext] = []
        
        var description: String {
            return "name:\(name) type:\(type) dict:\(dict) childs:\(childs)"
        }
        
        init(parent: SampleContext? ,type: JsonContextType){
            self.type = type
            self.parent = parent
        }
        
        func put(_ key:String, value: AnyObject?) {
            dict[key] = value
        }
        
        func createArrayContext(_ name: String) -> SampleContext {
            let sc = SampleContext(parent: self, type: .array)
            sc.name = name
            childs.append(sc)
            return sc
        }
        
        func createObjectContext() -> SampleContext {
            let sc = SampleContext(parent: self, type: .object)
            childs.append(sc)
            return sc
        }
        
        func getStructureAsDict() -> AnyObject {
            
            if type == .array {
                var result:[AnyObject] = []
                for child in childs {
                    result.append(child.getStructureAsDict())
                }
                return result as AnyObject;
            }
            
            
            var resultDict = dict
            for child in childs {
                if child.type == .array {
                    resultDict[child.name!] =  child.getStructureAsDict() as AnyObject?
                }
            }
            
            return resultDict as AnyObject
        }
    }
    
    internal func printWithLevel(_ level:Int, string:String){
        var outString = "\(level)"
        for i in 0 ..< level {
            outString += " "
        }
        outString += string
        print(outString)
    }
    
    /// callback for every found HealthKitSample
    let onSample : (_ sample: AnyObject, _ typeName:String) -> Void
    /// save the lastname to decide what is a sample and what is the name of a value
    var lastName = ""
    /// a samplecontext - created for evenry new sample
    var sampleContext: SampleContext? = nil
    /// the level in the json file
    var level = 0
    /// the healthkit sample type that is currently processed
    var hkTypeName: String? = nil
    
    init(onSample: @escaping (_ sample: AnyObject, _ typeName:String) -> Void) {
        self.onSample = onSample
    }
    
    func name(_ name: String) {
        lastName = name
    }
    
    func startArray() {
        level += 1
        if level == 2 && lastName.hasPrefix("HK") {
            hkTypeName = lastName
        }
        
        if level > 3 {
            sampleContext = sampleContext!.createArrayContext(lastName)
        }
    }
    
    func endArray() {
        if level == 2 {
            hkTypeName = nil
        }
        level -= 1
        
        sampleContext = sampleContext == nil ? nil : sampleContext!.parent
    }
    
    func startObject() {
        level += 1
        
        if level == 3 {
            // a new HKSample starts
            sampleContext = SampleContext(parent: nil, type: .object)
            sampleContext?.name = hkTypeName
        }
        
        if level > 3 {
             sampleContext = sampleContext!.createObjectContext()
        }
    }
    
    func endObject() {
        if level == 3 {
            // the HKSample ends
            onSample(sampleContext!.getStructureAsDict(), hkTypeName!)
            sampleContext = nil
        }
        sampleContext = sampleContext == nil ? nil : sampleContext!.parent
        level -= 1
    }
    
    func stringValue(_ value: String){
        if sampleContext != nil {
            sampleContext!.put(lastName, value:value as AnyObject)
        }
    }
    
    func boolValue(_ value: Bool){
        if sampleContext != nil {
            sampleContext!.put(lastName, value:value as AnyObject)
        }
    }
    
    func numberValue(_ value: NSNumber){
        if sampleContext != nil {
            sampleContext!.put(lastName, value:value)
        }
    }
    
    func nullValue(){
        if sampleContext != nil {
            sampleContext!.put(lastName, value:nil)
        }
    }
    
    func shouldCancelReadingTheJson() -> Bool {
        return false
    }
}
