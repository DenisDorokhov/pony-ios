//
// Created by Denis Dorokhov on 30/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import ObjectMapper

class Int64Transform: TransformType {

    typealias Object = Int64
    typealias JSON = NSNumber

    init() {

    }

    func transformFromJSON(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        return nil
    }

    func transformToJSON(_ value: Int64?) -> NSNumber? {
        if let number = value {
            return NSNumber(value: number)
        }
        return nil
    }
}
