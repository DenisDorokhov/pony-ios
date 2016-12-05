//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import ObjectMapper

class Album: Mappable {

    var id: Int64!
    var name: String?
    var year: Int?
    var artwork: Int64?
    var artworkUrl: String?
    var artist: Artist!

    init(id: Int64, artist: Artist) {
        self.id = id
        self.artist = artist
    }

    required init?(map: Map) {}

    func mapping(map: Map) {
        id <- (map["id"], Int64Transform())
        name <- map["name"]
        year <- map["year"]
        artwork <- (map["artwork"], Int64Transform())
        artworkUrl <- map["artworkUrl"]
        artist <- map["artist"]
    }
}
