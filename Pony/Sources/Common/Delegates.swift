//
// Created by Denis Dorokhov on 26/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import OrderedSet

class Delegates<T> {

    private var values: OrderedSet<NSValue> = []

    func add(_ delegate: T) {
        values.append(NSValue(nonretainedObject: delegate))
    }

    func remove(_ delegate: T) {
        values.remove(NSValue(nonretainedObject: delegate))
    }

    func fetch() -> [T] {
        return values.map { $0.nonretainedObjectValue as! T }
    }
}
