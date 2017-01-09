//
// Created by Denis Dorokhov on 26/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import Quick
import Nimble

@testable import Pony

class SearchServiceSpec: QuickSpec {

    override func spec() {

        TestUtils.describe("SearchServiceImpl") {

            var service: SearchServiceImpl!

            beforeEach {
                TestUtils.cleanAll()
                service = SearchServiceImpl()
            }
            afterEach {
                TestUtils.cleanAll()
            }

            let songMock15_3_3 = MockBuilders.buildSongMock(suffix: "15_3_3")
            let songMock17_4_3 = MockBuilders.buildSongMock(suffix: "17_4_3")
            let songMock18_4_3 = MockBuilders.buildSongMock(suffix: "18_4_3")
            let songMock413_48_16 = MockBuilders.buildSongMock(suffix: "413_48_16")
            
            TestUtils.it("should create index for artist") {
                expect { 
                    try service.createIndex(forArtist: songMock15_3_3.album.artist) 
                }.notTo(throwError())
            }
            
            TestUtils.it("should create index for album") {
                expect { 
                    try service.createIndex(forAlbum: songMock15_3_3.album) 
                }.notTo(throwError())
            }
            
            TestUtils.it("should create index for song") {
                expect { 
                    try service.createIndex(forSong: songMock15_3_3) 
                }.notTo(throwError())
            }
            
            TestUtils.it("should find artist") {

                try service.createIndex(forArtist: songMock15_3_3.album.artist)
                try service.createIndex(forArtist: songMock413_48_16.album.artist)

                let artists = try service.searchArtists("James Quintet", limit: 10)
                expect(artists).to(haveCount(1))
                expect(artists.first).to(equal(16))
            }
            
            TestUtils.it("should find album") {

                try service.createIndex(forAlbum: songMock15_3_3.album)
                try service.createIndex(forAlbum: songMock17_4_3.album)
                try service.createIndex(forAlbum: songMock413_48_16.album)

                let albums = try service.searchAlbums("f", limit: 10)
                expect(albums).to(haveCount(2))
                expect(albums).to(contain(3, 48))
            }
            
            TestUtils.it("should find song") {

                try service.createIndex(forSong: songMock15_3_3)
                try service.createIndex(forSong: songMock17_4_3)
                try service.createIndex(forSong: songMock18_4_3)
                try service.createIndex(forSong: songMock413_48_16)

                let songs = try service.searchSongs("car", limit: 10)
                expect(songs).to(haveCount(1))
                expect(songs.first).to(equal(15))
            }
            
            TestUtils.it("should respect limit") {

                try service.createIndex(forAlbum: songMock15_3_3.album)
                try service.createIndex(forAlbum: songMock17_4_3.album)
                try service.createIndex(forAlbum: songMock413_48_16.album)

                let albums = try service.searchAlbums("f", limit: 1)
                expect(albums).to(haveCount(1))
            }

            TestUtils.it("should remove index for artist") {
                try service.createIndex(forArtist: songMock413_48_16.album.artist)
                expect { 
                    try service.removeIndex(forArtist: 16) 
                }.toNot(throwError())
                let artists = try service.searchArtists("James Quintet", limit: 10)
                expect(artists).to(beEmpty())
            }

            TestUtils.it("should remove index for album") {
                try service.createIndex(forAlbum: songMock15_3_3.album)
                expect { 
                    try service.removeIndex(forAlbum: 3)
                }.toNot(throwError())
                let albums = try service.searchAlbums("f", limit: 10)
                expect(albums).to(beEmpty())
            }

            TestUtils.it("should remove index for song") {
                try service.createIndex(forSong: songMock15_3_3)
                expect { 
                    try service.removeIndex(forSong: 15)
                }.toNot(throwError())
                let songs = try service.searchSongs("car", limit: 10)
                expect(songs).to(beEmpty())
            }
            
            TestUtils.it("should clear index") {
                try service.createIndex(forArtist: songMock413_48_16.album.artist)
                try service.createIndex(forAlbum: songMock15_3_3.album)
                try service.createIndex(forSong: songMock15_3_3)
                expect {
                    try service.clearIndex()
                }.toNot(throwError())
                let artists = try service.searchArtists("James Quintet", limit: 10)
                let albums = try service.searchAlbums("f", limit: 10)
                let songs = try service.searchSongs("car", limit: 10)
                expect(artists).to(beEmpty())
                expect(albums).to(beEmpty())
                expect(songs).to(beEmpty())
            }
            
            TestUtils.it("should not throw error when indexing the same artist multiple times") {
                try service.createIndex(forArtist: songMock15_3_3.album.artist)
                expect {
                    try service.createIndex(forArtist: songMock15_3_3.album.artist)
                }.notTo(throwError())
            }
            
            TestUtils.it("should not throw error when indexing the same album multiple times") {
                try service.createIndex(forAlbum: songMock15_3_3.album)
                expect {
                    try service.createIndex(forAlbum: songMock15_3_3.album)
                }.notTo(throwError())
            }
            
            TestUtils.it("should not throw error when indexing the same song multiple times") {
                try service.createIndex(forSong: songMock15_3_3)
                expect {
                    try service.createIndex(forSong: songMock15_3_3)
                }.notTo(throwError())
            }
        }
    }
}
