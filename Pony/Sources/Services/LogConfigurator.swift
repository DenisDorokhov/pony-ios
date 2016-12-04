//
// Created by Denis Dorokhov on 12/05/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import XCGLogger

class LogConfigurator {

    let level: XCGLogger.Level

    init(level: XCGLogger.Level) {
        self.level = level
    }

    func configure() {

        let log = XCGLogger(includeDefaultDestinations: false)

        let systemDestination = AppleSystemLogDestination()

        systemDestination.outputLevel = .debug
        systemDestination.showThreadName = true

        log.add(destination: systemDestination)

        Log.configureDefault(delegate: XCGLogDelegate(log))
    }
}
