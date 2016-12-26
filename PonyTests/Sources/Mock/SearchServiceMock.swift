//
// Created by Denis Dorokhov on 26/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

@testable import Pony

class SearchServiceMock: SearchService {
    
    var didCallCreateIndexForArtist: Artist?
    var didCallCreateIndexForAlbum: Album?
    var didCallCreateIndexForSong: Song?
    
    var didCallRemoveIndexForArtist: Int64?
    var didCallRemoveIndexForAlbum: Int64?
    var didCallRemoveIndexForSong: Int64?
    
    var didCallClearIndex = false
    
    var didCallSearchArtists: String?
    var didCallSearchAlbums: String?
    var didCallSearchSongs: String?
    
    var searchArtists: [Int64]?
    var searchAlbums: [Int64]?
    var searchSongs: [Int64]?

    func createIndex(forArtist: Artist) throws {
        didCallCreateIndexForArtist = forArtist
    }

    func createIndex(forAlbum: Album) throws {
        didCallCreateIndexForAlbum = forAlbum
    }

    func createIndex(forSong: Song) throws {
        didCallCreateIndexForSong = forSong
    }

    func removeIndex(forArtist: Int64) throws {
        didCallRemoveIndexForArtist = forArtist
    }

    func removeIndex(forAlbum: Int64) throws {
        didCallRemoveIndexForAlbum = forAlbum
    }

    func removeIndex(forSong: Int64) throws {
        didCallRemoveIndexForSong = forSong
    }

    func clearIndex() throws {
        didCallClearIndex = true
    }

    func searchArtists(_ query: String) throws -> [Int64] {
        didCallSearchArtists = query
        if let value = searchArtists {
            return value
        } else {
            throw PonyError.unexpected
        }
    }

    func searchAlbums(_ query: String) throws -> [Int64] {
        didCallSearchAlbums = query
        if let value = searchAlbums {
            return value
        } else {
            throw PonyError.unexpected
        }
    }

    func searchSongs(_ query: String) throws -> [Int64] {
        didCallSearchSongs = query
        if let value = searchSongs {
            return value
        } else {
            throw PonyError.unexpected
        }
    }

}
