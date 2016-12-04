//
// Created by Denis Dorokhov on 15/08/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import RealmSwift

protocol RealmContext: class {

    var queue: DispatchQueue { get }

    func createRealm() throws -> Realm
}

class RealmContextImpl: RealmContext {

    var realmFileName: String = "library.realm"

    lazy var queue: DispatchQueue = DispatchQueue(label: "LibraryService.realmQueue")

    func createRealm() throws -> Realm {
        let config = Realm.Configuration(fileURL: URL(fileURLWithPath: FileUtils.pathInDocuments(realmFileName)))
        return try Realm(configuration: config)
    }
}
