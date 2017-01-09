//
// Created by Denis Dorokhov on 09/01/2017.
// Copyright (c) 2017 Denis Dorokhov. All rights reserved.
//

import Foundation
import UIKit

class TestAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
}

let appDelegateClass: String
if let _ = NSClassFromString("XCTest") {
    appDelegateClass = NSStringFromClass(TestAppDelegate.self)
} else {
    appDelegateClass = NSStringFromClass(AppDelegate.self)
}

let argv = UnsafeMutableRawPointer(CommandLine.unsafeArgv)
        .bindMemory(to: UnsafeMutablePointer<Int8>.self, capacity: Int(CommandLine.argc))

UIApplicationMain(CommandLine.argc, argv, nil, appDelegateClass)
