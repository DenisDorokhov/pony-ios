//
// Created by Denis Dorokhov on 08/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble
import RxSwift
import RxBlocking
import ObjectMapper

@testable import Pony

class SongServiceSpec: QuickSpec {
    override func spec() {
        TestUtils.describe("SongService") {

            var searchServiceMock: SearchServiceMock!
            var service: SongService!
            beforeEach {
                TestUtils.cleanAll()
                searchServiceMock = SearchServiceMock()
                service = SongService(context: SongService.Context(), storageUrlProvider: StorageUrlProvider(), searchService: searchServiceMock)
            }
            afterEach {
                TestUtils.cleanAll()
            }

            TestUtils.it("should save song and create index") {
                let songMock = MockBuilders.buildSongMock()
                let song = try service.save(song: songMock).toBlocking().first()
                expect(song).toNot(beNil())
                expect(searchServiceMock.didCallCreateIndexForArtist).to(be(song?.album.artist))
                expect(searchServiceMock.didCallCreateIndexForAlbum).to(be(song?.album))
                expect(searchServiceMock.didCallCreateIndexForSong).to(be(song))
            }

            TestUtils.it("should fetch artists") {
                let songMock = MockBuilders.buildSongMock()
                _ = try service.save(song: songMock).toBlocking().first()
                let artists = try service.getArtists().toBlocking().first()
                expect(artists).to(haveCount(1))
            }

            TestUtils.it("should fetch artist albums") {
                let songMock = MockBuilders.buildSongMock()
                _ = try service.save(song: songMock).toBlocking().first()
                let artistAlbums = try service.getArtistAlbums(forArtist: songMock.album.artist.id).toBlocking().first()
                expect(artistAlbums?.artist).toNot(beNil())
                expect(artistAlbums?.albums).to(haveCount(1))
                expect(artistAlbums?.albums.first?.songs).to(haveCount(1))
            }

            TestUtils.it("should delete song and remove index") {
                let songMock = MockBuilders.buildSongMock()
                _ = try service.save(song: songMock).toBlocking().first()
                let deletedSong = try service.delete(song: songMock.id).toBlocking().first()
                expect(deletedSong).toNot(beNil())
                let artists = try service.getArtists().toBlocking().first()
                expect(artists).to(haveCount(0))
                expect(searchServiceMock.didCallRemoveIndexForArtist).to(equal(songMock.album.artist.id))
                expect(searchServiceMock.didCallRemoveIndexForAlbum).to(equal(songMock.album.id))
                expect(searchServiceMock.didCallRemoveIndexForSong).to(equal(songMock.id))
            }
            
            TestUtils.it("should search artists") {
                let songMock = MockBuilders.buildSongMock()
                _ = try service.save(song: songMock).toBlocking().first()
                searchServiceMock.searchArtists = [3]
                let artists = try service.searchArtists("bop").toBlocking().first()
                expect(artists).to(haveCount(1))
            }
            
            TestUtils.it("should search albums") {
                let songMock = MockBuilders.buildSongMock()
                _ = try service.save(song: songMock).toBlocking().first()
                searchServiceMock.searchAlbums = [3]
                let albums = try service.searchAlbums("futurs").toBlocking().first()
                expect(albums).to(haveCount(1))
            }
            
            TestUtils.it("should search songs") {
                let songMock = MockBuilders.buildSongMock()
                _ = try service.save(song: songMock).toBlocking().first()
                searchServiceMock.searchSongs = [15]
                let songs = try service.searchSongs("carton").toBlocking().first()
                expect(songs).to(haveCount(1))
            }
            
            TestUtils.it("should fetch artwork usage count") {
                let songMock = MockBuilders.buildSongMock()
                _ = try service.save(song: songMock).toBlocking().first()
                let usageCount = try service.getUsageCount(forArtwork: 3).toBlocking().first()
                expect(usageCount).to(equal(2))
            }

            TestUtils.it("should throw error when song not found") {
                expect {
                    _ = try service.getArtistAlbums(forArtist: 1).toBlocking().first()
                }.to(throwError(PonyError.notFound))
                expect {
                    _ = try service.delete(song: 1).toBlocking().first()
                }.to(throwError(PonyError.notFound))
            }

            TestUtils.it("should delete unused artist and album") {
                
                let songMock15_3_3 = MockBuilders.buildSongMock(suffix: "15_3_3")
                let songMock17_4_3 = MockBuilders.buildSongMock(suffix: "17_4_3")
                let songMock18_4_3 = MockBuilders.buildSongMock(suffix: "18_4_3")
                
                _ = try service.save(song: songMock15_3_3).toBlocking().toArray()
                _ = try service.save(song: songMock17_4_3).toBlocking().toArray()
                _ = try service.save(song: songMock18_4_3).toBlocking().toArray()
                
                var artistAlbums: ArtistAlbums?
                
                artistAlbums = try service.getArtistAlbums(forArtist: 3).toBlocking().first()
                expect(artistAlbums?.albums).to(haveCount(2))
                
                _ = try service.delete(song: 17).toBlocking().first()
                artistAlbums = try service.getArtistAlbums(forArtist: 3).toBlocking().first()
                expect(artistAlbums?.albums).to(haveCount(2))

                _ = try service.delete(song: 18).toBlocking().first()
                artistAlbums = try service.getArtistAlbums(forArtist: 3).toBlocking().first()
                expect(artistAlbums?.albums).to(haveCount(1))

                _ = try service.delete(song: 15).toBlocking().first()
                let artists = try service.getArtists().toBlocking().first()
                expect(artists).to(haveCount(0))
            }
        }
    }
}
