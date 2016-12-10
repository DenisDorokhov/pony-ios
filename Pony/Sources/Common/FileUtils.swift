//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

class FileUtils {

    static var documentsPath: String = {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return try! FileUtils.createDirectory(atPath: paths[0])
    }()

    static var cachePath: String = {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return try! FileUtils.createDirectory(atPath: paths[0])
    }()

    static var temporaryPath: String = {
        return try! FileUtils.createDirectory(atPath: FileUtils.generateRandomPath(atPath: NSTemporaryDirectory()))
    }()

    static func generateTemporaryPath() -> String {
        return FileUtils.generateRandomPath(atPath: temporaryPath)
    }

    static func createTemporaryDirectory() throws -> String {
        let path = generateTemporaryPath()
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        return path
    }

    static func createTemporaryFile() throws -> String {
        let path = generateTemporaryPath()
        FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        return path
    }

    static func pathInDocuments(_ path: String) -> String {
        return (documentsPath as NSString).appendingPathComponent(path)
    }

    static func pathInCache(_ path: String) -> String {
        return (cachePath as NSString).appendingPathComponent(path)
    }

    @discardableResult
    static func createDirectory(atPath: String) throws -> String {
        if !FileManager.default.fileExists(atPath: atPath) {
            try FileManager.default.createDirectory(atPath: atPath, withIntermediateDirectories: true, attributes: nil)
        }
        return atPath
    }

    static func generateRandomPath(atPath: String) -> String {
        var result: String
        repeat {
            result = (atPath as NSString).appendingPathComponent(RandomUtils.uuid())
        } while FileManager.default.fileExists(atPath: result)
        return result
    }
}
