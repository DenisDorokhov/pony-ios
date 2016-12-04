//
// Created by Denis Dorokhov on 30/10/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import XCGLogger

class XCGLogDelegate: LogDelegate {

    let logger: XCGLogger

    init(_ logger: XCGLogger) {
        self.logger = logger
    }

    func verbose(message: @escaping () -> String,
                 functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        logger.verbose(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func debug(message: @escaping () -> String,
               functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        logger.debug(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func info(message: @escaping () -> String,
              functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        logger.info(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func warn(message: @escaping () -> String,
              functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        logger.warning(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }

    func error(message: @escaping () -> String,
               functionName: StaticString, fileName: StaticString, lineNumber: Int) {
        logger.error(message, functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }
}
