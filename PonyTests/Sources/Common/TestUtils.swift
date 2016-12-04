//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import KeychainSwift

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
}
