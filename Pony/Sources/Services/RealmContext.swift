//
// Created by Denis Dorokhov on 15/08/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RealmSwift
import RxSwift

class RealmContext {

    let fileName: String
    
    let queue: DispatchQueue
    let scheduler: SchedulerType
    
    convenience init() {
        self.init(fileName: "Pony.realm")
    }
    
    init(fileName: String) {
        self.fileName = fileName
        self.queue = DispatchQueue(label: "Pony.realmQueue")
        self.scheduler = ConcurrentDispatchQueueScheduler(queue: queue)
    }

    func createRealm() throws -> Realm {
        let config = Realm.Configuration(fileURL: URL(fileURLWithPath: FileUtils.pathInDocuments(fileName)))
        return try Realm(configuration: config)
    }
}
