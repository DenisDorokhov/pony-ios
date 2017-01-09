//
// Created by Denis Dorokhov on 30/10/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import UIKit
import Swinject
import SwinjectStoryboard

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var assembler: Assembler!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        let container = Container()
        assembler = try! Assembler(assemblies: [ServiceAssembly()], container: container)

        SwinjectStoryboard.defaultContainer = container

        let storyboard = SwinjectStoryboard.create(name: "Main", bundle: nil)

        window = UIWindow(frame: UIScreen.main.bounds)
        window!.rootViewController = storyboard.instantiateInitialViewController()
        window!.makeKeyAndVisible()

        return true
    }
}
