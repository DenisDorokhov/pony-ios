//
// Created by Denis Dorokhov on 02/05/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import RealmSwift

class AlbumRealm: AbstractRealm {

    dynamic var name: String?

    let year = RealmOptional<Int>()
    let artwork = RealmOptional<Int64>()

    dynamic var artist: ArtistRealm!

    let songs = LinkingObjects(fromType: SongRealm.self, property: "album")

    convenience init(album: Album) {
        self.init()

        id = album.id
        name = album.name
        year.value = album.year
        artwork.value = album.artwork
        artist = ArtistRealm(artist: album.artist)
    }

    func toAlbum(artworkUrl: (Int64?) -> String?) -> Album {
        let album = Album(id: id, artist: artist.toArtist(artworkUrl: artworkUrl))
        album.name = name
        album.year = year.value
        album.artwork = artwork.value
        album.artworkUrl = artworkUrl(album.artwork)
        return album
    }

    override static func indexedProperties() -> [String] {
        return ["artwork"]
    }
}
