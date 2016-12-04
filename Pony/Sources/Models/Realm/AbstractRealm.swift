//
// Created by Denis Dorokhov on 02/05/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import RealmSwift

class AbstractRealm: Object {

    dynamic var id: Int64 = 0

    override static func primaryKey() -> String? {
        return "id"
    }
}
