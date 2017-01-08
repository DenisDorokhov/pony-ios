//
// Created by Denis Dorokhov on 26/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import SQLite
import Regex

protocol SearchService: class {

    func createIndex(forArtist: Artist) throws
    func createIndex(forAlbum: Album) throws
    func createIndex(forSong: Song) throws

    func removeIndex(forArtist: Int64) throws
    func removeIndex(forAlbum: Int64) throws
    func removeIndex(forSong: Int64) throws

    func clearIndex() throws

    func searchArtists(_: String, limit: Int) throws -> [Int64]
    func searchAlbums(_: String, limit: Int) throws -> [Int64]
    func searchSongs(_: String, limit: Int) throws -> [Int64]
}

class SearchServiceImpl: SearchService {

    private struct Context {

        let db: Connection

        let artistsTable: VirtualTable
        let albumsTable: VirtualTable
        let songsTable: VirtualTable

        let docIdColumn: Expression<Int64>
        let termsColumn: Expression<String>
    }

    private let filePath: String

    private var context: Context?

    convenience init() {
        self.init(fileName: "Pony.sqlite3")
    }

    init(fileName: String) {
        filePath = FileUtils.pathInDocuments(fileName)
    }

    func createIndex(forArtist artist: Artist) throws {
        let context = try createContextIfNeeded()
        let terms = artist.name ?? ""
        Log.debug("Creating index for artist '\(artist.id)'.")
        _ = try context.db.run(
                context.artistsTable.insert(or: .replace,
                        context.docIdColumn <- artist.id, context.termsColumn <- terms))
    }

    func createIndex(forAlbum album: Album) throws {
        let context = try createContextIfNeeded()
        var terms = album.name ?? "" + " "
        terms += album.artist.name ?? "" + " "
        Log.debug("Creating index for album '\(album.id)'.")
        _ = try context.db.run(
                context.albumsTable.insert(or: .replace,
                        context.docIdColumn <- album.id, context.termsColumn <- terms))
    }

    func createIndex(forSong song: Song) throws {
        let context = try createContextIfNeeded()
        var terms = song.name ?? "" + " "
        terms += song.artistName ?? "" + " "
        terms += song.album.artist.name ?? "" + " "
        terms += song.album.name ?? "" + " "
        Log.debug("Creating index for song '\(song.id)'.")
        _ = try context.db.run(
                context.songsTable.insert(or: .replace,
                        context.docIdColumn <- song.id, context.termsColumn <- terms))
    }

    func removeIndex(forArtist artist: Int64) throws {
        let context = try createContextIfNeeded()
        Log.debug("Removing index for artist '\(artist)'.")
        _ = try context.db.run(
                context.artistsTable
                        .filter(context.docIdColumn == artist)
                        .delete())
    }

    func removeIndex(forAlbum album: Int64) throws {
        let context = try createContextIfNeeded()
        Log.debug("Removing index for album '\(album)'.")
        _ = try context.db.run(
                context.albumsTable
                        .filter(context.docIdColumn == album)
                        .delete())
    }

    func removeIndex(forSong song: Int64) throws {
        let context = try createContextIfNeeded()
        Log.debug("Removing index for song '\(song)'.")
        _ = try context.db.run(
                context.songsTable
                        .filter(context.docIdColumn == song)
                        .delete())
    }

    func clearIndex() throws {
        let context = try createContextIfNeeded()
        Log.debug("Clearing index.")
        _ = try context.db.run(context.artistsTable.delete())
        _ = try context.db.run(context.albumsTable.delete())
        _ = try context.db.run(context.songsTable.delete())
    }

    func searchArtists(_ query: String, limit: Int) throws -> [Int64] {
        let context = try createContextIfNeeded()
        return try runQuery(query, "artists", context.artistsTable, context, limit)
    }

    func searchAlbums(_ query: String, limit: Int) throws -> [Int64] {
        let context = try createContextIfNeeded()
        return try runQuery(query, "albums", context.albumsTable, context, limit)
    }

    func searchSongs(_ query: String, limit: Int) throws -> [Int64] {
        let context = try createContextIfNeeded()
        return try runQuery(query, "songs", context.songsTable, context, limit)
    }
    
    private func buildQuery(_ query: String) -> String {
        return Regex("[^\\s]+").allMatches(query).map {
            $0.matchedString + "*"
        }.reduce("") {
            $0 + " " + $1
        }
    }
    
    private func runQuery(_ query: String, _ tableName: String, _ table: VirtualTable, _ context: Context, _ limit: Int) throws -> [Int64] {
        
        let matchQuery = buildQuery(query)
        Log.verbose("Running search query '\(matchQuery)' on '\(tableName)'.")
        
        let selectQuery = table.select(context.docIdColumn)
                .filter(context.termsColumn.match(matchQuery)).limit(limit)
        return try context.db.prepare(selectQuery).map { $0[context.docIdColumn] }
    }

    private func createContextIfNeeded() throws -> Context {
        if let context = context {
            return context
        }
        Log.debug("Creating search database context.")

        let db = try Connection(filePath)
        
        let artistsTable = VirtualTable("artists")
        let albumsTable = VirtualTable("albums")
        let songsTable = VirtualTable("songs")

        let docIdColumn = Expression<Int64>("docid")
        let termsColumn = Expression<String>("terms")

        let config = FTS4Config().column(termsColumn)

        try db.run(artistsTable.create(.FTS4(config), ifNotExists: true))
        try db.run(albumsTable.create(.FTS4(config), ifNotExists: true))
        try db.run(songsTable.create(.FTS4(config), ifNotExists: true))

        context = Context(db: db,
                artistsTable: artistsTable, albumsTable: albumsTable, songsTable: songsTable,
                docIdColumn: docIdColumn, termsColumn: termsColumn)
        
        return context!
    }
}
