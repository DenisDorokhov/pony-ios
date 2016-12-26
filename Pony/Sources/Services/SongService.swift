//
// Created by Denis Dorokhov on 08/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift
import RealmSwift

class SongService {

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
    
    init(context: Context, storageUrlProvider: StorageUrlProvider) {
        self.context = context
        self.storageUrlProvider = storageUrlProvider
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
        }.observeOn(MainScheduler.instance)
    }

    func delete(song: Int64) -> Observable<Song> {
        return Observable.just(song).observeOn(context.scheduler).map {
            do {
                let realm = try self.context.createRealm()
                let songRealm = realm.objects(SongRealm.self).filter("id == \($0)").first
                var deletedSong: Song?
                if let songRealm = songRealm {
                    deletedSong = songRealm.toSong(artworkUrl: self.buildArtworkUrl, songUrl: self.buildSongUrl)
                    try realm.write {
                        self.doDelete(song: songRealm, realm: realm)
                    }
                }
                if let deletedSong = deletedSong {
                    Log.info("Song '\($0)' deleted.")
                    return deletedSong
                } else {
                    Log.error("Could not delete song '\($0)': song not found.")
                    throw PonyError.notFound
                }
            } catch let error {
                Log.error("Could not delete song: \(error).")
                throw error
            }
        }.observeOn(MainScheduler.instance)
    }

    private func doDelete(song: SongRealm, realm: Realm) {
        var albumToDelete: AlbumRealm?, artistToDelete: ArtistRealm?
        if song.album.songs.count == 1 {
            albumToDelete = song.album
            if song.album.artist.albums.count == 1 {
                artistToDelete = song.album.artist
            }
        }
        realm.delete(song)
        if let albumToDelete = albumToDelete {
            realm.delete(albumToDelete)
        }
        if let artistToDelete = artistToDelete {
            realm.delete(artistToDelete)
        }
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
