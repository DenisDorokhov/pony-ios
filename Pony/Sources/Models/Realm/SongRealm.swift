//
// Created by Denis Dorokhov on 02/05/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import RealmSwift

class SongRealm: AbstractRealm {

    dynamic var updateDate: Date?

    dynamic var size: Int64 = 0

    dynamic var duration: Int = 0
    let discNumber = RealmOptional<Int>()
    let trackNumber = RealmOptional<Int>()

    dynamic var artistName: String?
    dynamic var name: String?

    dynamic var album: AlbumRealm!
    dynamic var genre: GenreRealm!

    convenience init(song: Song) {
        self.init()

        id = song.id
        updateDate = song.updateDate
        size = song.size
        duration = song.duration
        discNumber.value = song.discNumber
        trackNumber.value = song.trackNumber
        artistName = song.artistName
        name = song.name
        album = AlbumRealm(album: song.album)
        genre = GenreRealm(genre: song.genre)
    }

    func toSong(artworkUrl: (Int64?) -> String?, songUrl: (Int64) -> String) -> Song {
        let song = Song(id: id, url: songUrl(id), size: size, duration: duration,
                album: album.toAlbum(artworkUrl: artworkUrl),
                genre: genre.toGenre(artworkUrl: artworkUrl))
        song.updateDate = updateDate
        song.size = size
        song.duration = duration
        song.discNumber = discNumber.value
        song.trackNumber = trackNumber.value
        song.artistName = artistName
        song.name = name
        return song
    }
}
