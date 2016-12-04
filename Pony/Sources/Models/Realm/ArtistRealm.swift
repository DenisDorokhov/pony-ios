//
// Created by Denis Dorokhov on 02/05/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import RealmSwift

class ArtistRealm: AbstractRealm {

    dynamic var name: String?

    let artwork = RealmOptional<Int64>()

    let albums = LinkingObjects(fromType: AlbumRealm.self, property: "artist")

    convenience init(artist: Artist) {
        self.init()

        id = artist.id
        name = artist.name
        artwork.value = artist.artwork
    }

    func toArtist(artworkUrl: (Int64?) -> String?) -> Artist {
        let artist = Artist(id: id)
        artist.name = name
        artist.artwork = artwork.value
        artist.artworkUrl = artworkUrl(artist.artwork)
        return artist
    }

    override static func indexedProperties() -> [String] {
        return ["name", "artwork"]
    }
}
