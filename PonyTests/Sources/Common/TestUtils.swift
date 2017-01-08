//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import KeychainSwift
import Quick
import Nimble

@testable import Pony

class TestUtils {

    static func cleanAll() {
        cleanFiles()
        cleanUserDefaults()
        cleanKeychain()
    }

    static func cleanFiles() {

        let fileManager = FileManager.default

        for item in try! fileManager.contentsOfDirectory(atPath: FileUtils.documentsPath) {
            _ = try? fileManager.removeItem(atPath: NSString(string: FileUtils.documentsPath).appendingPathComponent(item))
        }
        for item in try! fileManager.contentsOfDirectory(atPath: FileUtils.cachePath) {
            _ = try? fileManager.removeItem(atPath: NSString(string: FileUtils.cachePath).appendingPathComponent(item))
        }
        for item in try! fileManager.contentsOfDirectory(atPath: FileUtils.temporaryPath) {
            _ = try? fileManager.removeItem(atPath: NSString(string: FileUtils.temporaryPath).appendingPathComponent(item))
        }
    }

    static func cleanUserDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()
    }

    static func cleanKeychain() {
        KeychainSwift().clear()
    }
    
    static func describe(_ description: String, flags: FilterFlags = [:], closure: @escaping () throws -> ()) {
        let notThrowingClosure = {
            do {
                try closure()
            } catch let error {
                fail("Exception thrown: \(error).")
            }
        }
        Quick.describe(description, closure: notThrowingClosure)
    }
    
    static func it(_ description: String, flags: FilterFlags = [:], file: String = #file, line: UInt = #line, closure: @escaping () throws -> ()) {
        let notThrowingClosure = {
            do {
                try closure()
            } catch let error {
                fail("Exception thrown: \(error).")
            }
        }
        Quick.it(description, flags: flags, file: file, line: line, closure: notThrowingClosure)
    }
}
