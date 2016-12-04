//
// Created by Denis Dorokhov on 02/05/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import RealmSwift

class GenreRealm: AbstractRealm {

    dynamic var name: String?

    let artwork = RealmOptional<Int64>()

    convenience init(genre: Genre) {
        self.init()

        id = genre.id
        name = genre.name
        artwork.value = genre.artwork
    }

    func toGenre(artworkUrl: (Int64?) -> String?) -> Genre {
        let genre = Genre(id: id)
        genre.name = name
        genre.artwork = artwork.value
        genre.artworkUrl = artworkUrl(genre.artwork)
        return genre
    }
}
