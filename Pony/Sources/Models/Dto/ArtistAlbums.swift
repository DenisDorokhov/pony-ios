//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import ObjectMapper

class ArtistAlbums: Mappable {

    var artist: Artist!
    var albums: [AlbumSongs]!

    init(artist: Artist, albums: [AlbumSongs]) {
        self.artist = artist
        self.albums = albums
    }

    required init?(map: Map) {}

    func mapping(map: Map) {
        artist <- map["artist"]
        albums <- map["albums"]
    }
}
