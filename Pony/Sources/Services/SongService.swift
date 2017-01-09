//
// Created by Denis Dorokhov on 08/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift
import RealmSwift

class SongService: ArtworkUsageCountProvider {

    class Context {

        let fileName: String

        let queue: DispatchQueue
        let scheduler: SchedulerType

        convenience init() {
            self.init(fileName: "Pony.realm")
        }

        init(fileName: String) {
            self.fileName = fileName
            self.queue = DispatchQueue(label: "Pony.realmQueue")
            self.scheduler = ConcurrentDispatchQueueScheduler(queue: queue)
        }

        func createRealm() throws -> Realm {
            let config = Realm.Configuration(fileURL: URL(fileURLWithPath: FileUtils.pathInDocuments(fileName)))
            return try Realm(configuration: config)
        }
    }

    let context: Context
    let storageUrlProvider: StorageUrlProvider
    let searchService: SearchService
    
    var searchLimit = 10

    init(context: Context, storageUrlProvider: StorageUrlProvider, searchService: SearchService) {
        self.context = context
        self.storageUrlProvider = storageUrlProvider
        self.searchService = searchService
    }

    func getArtists() -> Observable<[Artist]> {
        return Observable.just().observeOn(context.scheduler).map {
            do {
                let realm = try self.context.createRealm()
                let artists: [Artist] = realm.objects(ArtistRealm.self).sorted(byProperty: "name").map {
                    $0.toArtist(artworkUrl: self.buildArtworkUrl)
                }
                return artists
            } catch let error {
                Log.error("Could not fetch artists: \(error).")
                throw error
            }
        }.observeOn(MainScheduler.instance)
    }

    func getArtistAlbums(forArtist artist: Int64) -> Observable<ArtistAlbums> {
        return Observable.just(artist).observeOn(context.scheduler).map {
            do {
                let realm = try self.context.createRealm()
                var artistAlbums: ArtistAlbums?
                if let artist = realm.objects(ArtistRealm.self).filter("id == \($0)").first {
                    let albums: [AlbumSongs] = artist.albums.map {
                        album in
                        let songs: [Song] = album.songs.map {
                            $0.toSong(artworkUrl: self.buildArtworkUrl, songUrl: self.buildSongUrl)
                        }
                        return AlbumSongs(album: album.toAlbum(artworkUrl: self.buildArtworkUrl), songs: songs)
                    }
                    artistAlbums = ArtistAlbums(artist: artist.toArtist(artworkUrl: self.buildArtworkUrl), albums: albums)
                }
                if let artistAlbums = artistAlbums {
                    return artistAlbums
                } else {
                    throw PonyError.notFound
                }
            } catch let error {
                Log.error("Could not fetch albums: \(error).")
                throw error
            }
        }.observeOn(MainScheduler.instance)
    }

    func save(song: Song) -> Observable<Song> {
        return Observable.just(song).observeOn(context.scheduler).map {
            do {
                let realm = try self.context.createRealm()
                let songRealm = SongRealm(song: $0)
                try realm.write {
                    realm.add(songRealm, update: true)
                }
                return songRealm.toSong(artworkUrl: self.buildArtworkUrl, songUrl: self.buildSongUrl)
            } catch let error {
                Log.error("Could not save song: \(error).")
                throw error
            }
        }.do(onNext: { song in
            do {
                try self.searchService.createIndex(forArtist: song.album.artist)
                try self.searchService.createIndex(forAlbum: song.album)
                try self.searchService.createIndex(forSong: song)
            } catch let error {
                Log.warn("Could not create song index: \(error).")
            }
        }).observeOn(MainScheduler.instance)
    }

    func delete(song: Int64) -> Observable<Song> {
        return Observable.just(song).observeOn(context.scheduler).map { (song) -> (song: Song, deletedAlbum: Int64?, deletedArtist: Int64?) in
            do {
                let realm = try self.context.createRealm()
                let songRealm = realm.objects(SongRealm.self).filter("id == \(song)").first
                var deletedSong: Song?, deletedAlbum: Int64?, deletedArtist: Int64?
                if let songRealm = songRealm {
                    deletedSong = songRealm.toSong(artworkUrl: self.buildArtworkUrl, songUrl: self.buildSongUrl)
                    try realm.write {
                        let deletionResult = self.doDelete(song: songRealm, realm: realm)
                        deletedAlbum = deletionResult.deletedAlbum
                        deletedArtist = deletionResult.deletedArtist
                    }
                }
                if let deletedSong = deletedSong {
                    Log.info("Song '\(song)' deleted.")
                    return (deletedSong, deletedAlbum, deletedArtist)
                } else {
                    Log.error("Could not delete song '\(song)': song not found.")
                    throw PonyError.notFound
                }
            } catch let error {
                Log.error("Could not delete song: \(error).")
                throw error
            }
        }.map { (deletionResult) -> Song in
            let (song, deletedAlbum, deletedArtist) = deletionResult
            do {
                try self.searchService.removeIndex(forSong: song.id)
                if let deletedAlbum = deletedAlbum {
                    try self.searchService.removeIndex(forAlbum: deletedAlbum)
                }
                if let deletedArtist = deletedArtist {
                    try self.searchService.removeIndex(forArtist: deletedArtist)
                }
            } catch let error {
                Log.warn("Could not remove song index: \(error).")
            }
            return song
        }.observeOn(MainScheduler.instance)
    }

    func searchArtists(_ query: String) -> Observable<[Artist]> {
        return Observable.just(query).observeOn(context.scheduler).map {
            try self.searchService.searchArtists($0, limit: self.searchLimit)
        }.map {
            do {
                let realm = try self.context.createRealm()
                let artists: [Artist] = realm.objects(ArtistRealm.self)
                        .filter(self.buildSearchResultsQuery($0)).map {
                            $0.toArtist(artworkUrl: self.buildArtworkUrl)
                        }
                return artists
            } catch let error {
                Log.error("Could not fetch found artists: \(error).")
                throw error
            }
        }.observeOn(MainScheduler.instance)
    }

    func searchAlbums(_ query: String) -> Observable<[Album]> {
        return Observable.just(query).observeOn(context.scheduler).map {
            try self.searchService.searchAlbums($0, limit: self.searchLimit)
        }.map {
            do {
                let realm = try self.context.createRealm()
                let albums: [Album] = realm.objects(AlbumRealm.self)
                        .filter(self.buildSearchResultsQuery($0)).map {
                            $0.toAlbum(artworkUrl: self.buildArtworkUrl)
                        }
                return albums
            } catch let error {
                Log.error("Could not fetch found albums: \(error).")
                throw error
            }
        }.observeOn(MainScheduler.instance)
    }

    func searchSongs(_ query: String) -> Observable<[Song]> {
        return Observable.just(query).observeOn(context.scheduler).map {
            try self.searchService.searchSongs($0, limit: self.searchLimit)
        }.map {
            do {
                let realm = try self.context.createRealm()
                let songs: [Song] = realm.objects(SongRealm.self)
                        .filter(self.buildSearchResultsQuery($0)).map {
                            $0.toSong(artworkUrl: self.buildArtworkUrl, songUrl: self.buildSongUrl)
                        }
                return songs
            } catch let error {
                Log.error("Could not fetch found songs: \(error).")
                throw error
            }
        }.observeOn(MainScheduler.instance)
    }

    func getUsageCount(forArtwork artwork: Int64) -> Observable<Int> {
        return Observable.just(artwork).observeOn(context.scheduler).map {
            do {
                let realm = try self.context.createRealm()
                let albumsCount = realm.objects(AlbumRealm.self).filter("artwork == \($0)").count
                let artistsCount = realm.objects(ArtistRealm.self).filter("artwork == \($0)").count
                return albumsCount + artistsCount
            } catch let error {
                Log.error("Could not fetch artwork usage count: \(error).")
                throw error
            }
        }.observeOn(MainScheduler.instance)
    }

    private func buildSearchResultsQuery(_ results: [Int64]) -> String {
        let ids = results.map { String($0) }.joined(separator: ", ")
        return "id IN {\(ids)}"
    }

    private func doDelete(song: SongRealm, realm: Realm) -> (deletedAlbum: Int64?, deletedArtist: Int64?) {
        var albumToDelete: AlbumRealm?, artistToDelete: ArtistRealm?
        if song.album.songs.count == 1 {
            albumToDelete = song.album
            if song.album.artist.albums.count == 1 {
                artistToDelete = song.album.artist
            }
        }
        realm.delete(song)
        var deletedAlbum: Int64?
        if let albumToDelete = albumToDelete {
            deletedAlbum = albumToDelete.id
            realm.delete(albumToDelete)
        }
        var deletedArtist: Int64?
        if let artistToDelete = artistToDelete {
            deletedArtist = artistToDelete.id
            realm.delete(artistToDelete)
        }
        return (deletedAlbum, deletedArtist)
    }

    private func buildArtworkUrl(_ artwork: Int64?) -> String? {
        if let artwork = artwork {
            return storageUrlProvider.fileUrl(forArtwork: artwork).absoluteString
        }
        return nil
    }

    private func buildSongUrl(_ song: Int64) -> String {
        return storageUrlProvider.fileUrl(forSong: song).absoluteString
    }
}
