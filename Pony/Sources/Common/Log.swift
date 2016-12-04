//
// Created by Denis Dorokhov on 30/10/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

protocol LogDelegate: class {

    func verbose(message: @escaping () -> String,
                 functionName: StaticString, fileName: StaticString, lineNumber: Int)

    func debug(message: @escaping () -> String,
               functionName: StaticString, fileName: StaticString, lineNumber: Int)

    func info(message: @escaping () -> String,
              functionName: StaticString, fileName: StaticString, lineNumber: Int)

    func warn(message: @escaping () -> String,
              functionName: StaticString, fileName: StaticString, lineNumber: Int)

    func error(message: @escaping () -> String,
               functionName: StaticString, fileName: StaticString, lineNumber: Int)
}

class NSLogDelegate: LogDelegate {

    enum Level: Int, CustomStringConvertible {

        case verbose, debug, info, warn, error

        var description: String {
            switch self {
            case .verbose:
                return "Verbose"
            case .debug:
                return "Debug"
            case .info:
                return "Info"
            case .warn:
                return "Warn"
            case .error:
                return "Error"
            }
        }
    }

    let name: String?
    let level: Level

    init(_ name: String? = nil, level: Level = .verbose) {
        self.name = name
        self.level = level
    }

    func verbose(message: @escaping () -> String,
                 functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        output(message: message, level: .verbose,
                functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func debug(message: @escaping () -> String,
               functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        output(message: message, level: .debug,
                functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func info(message: @escaping () -> String,
              functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        output(message: message, level: .info,
                functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func warn(message: @escaping () -> String,
              functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        output(message: message, level: .warn,
                functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func error(message: @escaping () -> String,
               functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        output(message: message, level: .error,
                functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    private func output(message: @escaping () -> String, level: Level,
                        functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        if level.rawValue >= self.level.rawValue {
            let formattedName: String
            if let name = name, name.characters.count > 0 {
                formattedName = name + " "
            } else {
                formattedName = ""
            }
            NSLog("%@[%@] [%@:%d] %@ > %@",
                    formattedName, level.description,
                    (String(describing: fileName) as NSString).lastPathComponent, lineNumber, String(describing: functionName),
                    message())
        }
    }
}

class Log {

    static private(set) var `default` = Log()

    static func configureDefault(delegate: LogDelegate) {
        `default` = Log(delegate: delegate)
    }

    let delegate: LogDelegate?

    init(delegate: LogDelegate) {
        self.delegate = delegate
    }

    init() {
        self.delegate = NSLogDelegate()
    }

    func verbose(_ message: @autoclosure @escaping () -> String,
                 functionName: StaticString = #function,
                 fileName: StaticString = #file,
                 lineNumber: Int = #line) {
        delegate?.verbose(message: message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func debug(_ message: @autoclosure @escaping () -> String,
               functionName: StaticString = #function,
               fileName: StaticString = #file,
               lineNumber: Int = #line) {
        delegate?.debug(message: message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func info(_ message: @autoclosure @escaping () -> String,
              functionName: StaticString = #function,
              fileName: StaticString = #file,
              lineNumber: Int = #line) {
        delegate?.info(message: message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func warn(_ message: @autoclosure @escaping () -> String,
              functionName: StaticString = #function,
              fileName: StaticString = #file,
              lineNumber: Int = #line) {
        delegate?.warn(message: message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func error(_ message: @autoclosure @escaping () -> String,
               functionName: StaticString = #function,
               fileName: StaticString = #file,
               lineNumber: Int = #line) {
        delegate?.error(message: message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    static func verbose(_ message: @autoclosure @escaping () -> String,
                        functionName: StaticString = #function,
                        fileName: StaticString = #file,
                        lineNumber: Int = #line) {
        `default`.verbose(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    static func debug(_ message: @autoclosure @escaping () -> String,
                      functionName: StaticString = #function,
                      fileName: StaticString = #file,
                      lineNumber: Int = #line) {
        `default`.debug(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    static func info(_ message: @autoclosure @escaping () -> String,
                     functionName: StaticString = #function,
                     fileName: StaticString = #file,
                     lineNumber: Int = #line) {
        `default`.info(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    static func warn(_ message: @autoclosure @escaping () -> String,
                     functionName: StaticString = #function,
                     fileName: StaticString = #file,
                     lineNumber: Int = #line) {
        `default`.warn(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    static func error(_ message: @autoclosure @escaping () -> String,
                      functionName: StaticString = #function,
                      fileName: StaticString = #file,
                      lineNumber: Int = #line) {
        `default`.error(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }
}
