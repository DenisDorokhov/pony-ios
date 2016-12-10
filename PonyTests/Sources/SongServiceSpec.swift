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
        describe("SongService") {

            var service: SongService!
            beforeEach {
                TestUtils.cleanAll()
                service = SongService(realmContext: RealmContext(), storageUrlProvider: StorageUrlProvider())
            }
            afterEach {
                TestUtils.cleanAll()
            }

            let buildSongMock: (String) -> Song = { suffix in
                let bundle = Bundle(for: type(of: self))
                let json = try! String(contentsOfFile: bundle.path(forResource: "song-\(suffix)", ofType: "json")!)
                return Song(JSONString: json)!
            }
            let buildDefaultSongMock: () -> Song = {
                return buildSongMock("15_3_3")
            }

            it("should save song") {
                let songMock = buildDefaultSongMock()
                let song = try! service.save(song: songMock).toBlocking().first()!
                expect(song).toNot(beNil())
            }

            it("should fetch artists") {
                let songMock = buildDefaultSongMock()
                _ = try! service.save(song: songMock).toBlocking().first()!
                let artists = try! service.getArtists().toBlocking().first()!
                expect(artists).to(haveCount(1))
            }

            it("should fetch artist albums") {
                let songMock = buildDefaultSongMock()
                _ = try! service.save(song: songMock).toBlocking().first()!
                let artistAlbums = try! service.getArtistAlbums(forArtist: songMock.album.artist.id).toBlocking().first()!
                expect(artistAlbums.artist).toNot(beNil())
                expect(artistAlbums.albums).to(haveCount(1))
                expect(artistAlbums.albums[0].songs).to(haveCount(1))
            }

            it("should delete song") {
                let songMock = buildDefaultSongMock()
                _ = try! service.save(song: songMock).toBlocking().first()!
                _ = try! service.delete(song: songMock.id).toBlocking().first()!
                let artists = try! service.getArtists().toBlocking().first()!
                expect(artists).to(haveCount(0))
            }

            it("should throw error when song not found") {
                expect {
                    _ = try service.getArtistAlbums(forArtist: 1).toBlocking().first()
                }.to(throwError(PonyError.notFound))
                expect {
                    _ = try service.delete(song: 1).toBlocking().first()
                }.to(throwError(PonyError.notFound))
            }

            it("should delete unused artist and album") {
                
                let songMock15_3_3 = buildSongMock("15_3_3")
                let songMock17_4_3 = buildSongMock("17_4_3")
                let songMock18_4_3 = buildSongMock("18_4_3")
                
                _ = try! service.save(song: songMock15_3_3).toBlocking().first()!
                _ = try! service.save(song: songMock17_4_3).toBlocking().first()!
                _ = try! service.save(song: songMock18_4_3).toBlocking().first()!
                
                var artistAlbums: ArtistAlbums
                
                artistAlbums = try! service.getArtistAlbums(forArtist: 3).toBlocking().first()!
                expect(artistAlbums.albums).to(haveCount(2))
                
                _ = try! service.delete(song: 17).toBlocking().first()!
                artistAlbums = try! service.getArtistAlbums(forArtist: 3).toBlocking().first()!
                expect(artistAlbums.albums).to(haveCount(2))
                
                _ = try! service.delete(song: 18).toBlocking().first()!
                artistAlbums = try! service.getArtistAlbums(forArtist: 3).toBlocking().first()!
                expect(artistAlbums.albums).to(haveCount(1))
                
                _ = try! service.delete(song: 15).toBlocking().first()!
                let artists = try! service.getArtists().toBlocking().first()!
                expect(artists).to(haveCount(0))
            }
        }
    }
}
