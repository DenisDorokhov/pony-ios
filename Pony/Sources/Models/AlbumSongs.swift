//
// Created by Denis Dorokhov on 29/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import ObjectMapper

class AlbumSongs: Mappable {

    var album: Album!
    var songs: [Song]!

    init(album: Album, songs: [Song]) {
        self.album = album
        self.songs = songs
    }

    required init?(map: Map) {}

    func mapping(map: Map) {
        album <- map["album"]
        songs <- map["songs"]
    }
}
