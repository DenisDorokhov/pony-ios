//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import ObjectMapper

class Genre: Mappable {

    var id: Int64!
    var name: String?
    var artwork: Int64?
    var artworkUrl: String?

    init(id: Int64) {
        self.id = id
    }

    required init?(map: Map) {}

    func mapping(map: Map) {
        id <- (map["id"], Int64Transform())
        name <- map["name"]
        artwork <- (map["artwork"], Int64Transform())
        artworkUrl <- map["artworkUrl"]
    }
}
