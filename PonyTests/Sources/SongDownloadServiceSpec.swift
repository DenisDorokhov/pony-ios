//
// Created by Denis Dorokhov on 27/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble
import RxSwift
import RxBlocking

@testable import Pony

class SongDownloadServiceSpec: QuickSpec {
    override func spec() {
        TestUtils.describe("SongDownloadServiceImpl") {

            var apiServiceMock: ApiServiceMock!
            var songService: SongService!
            var delegate: SongDownloadServiceDelegateMock!
            var service: SongDownloadService!
            beforeEach {
                TestUtils.cleanAll()

                let bundle = Bundle(for: type(of: self))
                
                apiServiceMock = ApiServiceMock()
                apiServiceMock.imagePath = bundle.path(forResource: "artwork", ofType: "png")!
                apiServiceMock.songPath = bundle.path(forResource: "song", ofType: "mp3")!
                
                let storageUrlProvider = StorageUrlProvider()
                
                songService = SongService(context: SongService.Context(), storageUrlProvider: storageUrlProvider, searchService: SearchServiceMock())
                
                let artworkService = ArtworkService(artworkUsageCountProvider: songService, apiService: apiServiceMock, storageUrlProvider: storageUrlProvider)
                
                delegate = SongDownloadServiceDelegateMock()
                service = SongDownloadService(apiService: apiServiceMock, artworkService: artworkService, songService: songService, storageUrlProvider: storageUrlProvider)
                service.addDelegate(delegate)
            }
            afterEach {
                TestUtils.cleanAll()
            }

            let songMock = MockBuilders.buildSongMock()
            
            TestUtils.it("should download song") {

                let progress = try service.downloadSong(songMock).toBlocking().toArray()
                
                expect(delegate.didStartSongDownload).toNot(beNil())
                expect(delegate.didProgressSongDownload).toNot(beNil())
                expect(delegate.didCompleteSongDownload).toEventuallyNot(beNil())
                expect(delegate.didCancelSongDownload).to(beNil())
                expect(delegate.didFailSongDownload).to(beNil())
                expect(delegate.didDeleteSongDownload).to(beNil())
                
                expect(progress.count).to(beGreaterThan(0))
                expect(service.taskForSong(songMock.id)).to(beNil())
                
                let artists = try songService.getArtists().toBlocking().first()
                expect(artists).to(haveCount(1))
                
                if let song = delegate.didCompleteSongDownload {
                    let fileManager = FileManager.default
                    expect(fileManager.fileExists(atPath: URL(string: song.url)!.path)).to(beTrue())
                    expect(fileManager.fileExists(atPath: URL(string: song.album.artworkUrl!)!.path)).to(beTrue())
                    expect(fileManager.fileExists(atPath: URL(string: song.album.artist.artworkUrl!)!.path)).to(beTrue())
                }
            }
            
            TestUtils.it("should return tasks and cancel song download") {
                
                _ = service.downloadSong(songMock).subscribe()

                expect(service.taskForSong(songMock.id)).toNot(beNil())
                expect(service.allTasks()).to(haveCount(1))
                
                service.cancelSongDownload(songMock.id)
                
                _ = try Observable.just().delay(1, scheduler: MainScheduler.instance).toBlocking().first()

                expect(delegate.didStartSongDownload).toNot(beNil())
                expect(delegate.didProgressSongDownload).to(beNil())
                expect(delegate.didCancelSongDownload).toNot(beNil())
                expect(delegate.didFailSongDownload).to(beNil())
                expect(delegate.didCompleteSongDownload).to(beNil())
                expect(delegate.didDeleteSongDownload).to(beNil())
            }
            
            TestUtils.it("should delete song") {

                _ = service.downloadSong(songMock).subscribe()

                expect(delegate.didCompleteSongDownload).toEventuallyNot(beNil())
                
                let deletedSong = try service.deleteSongDownload(songMock.id).toBlocking().first()
                expect(deletedSong).toNot(beNil())
                if let song = deletedSong {
                    let fileManager = FileManager.default
                    expect(fileManager.fileExists(atPath: URL(string: song.url)!.path)).to(beFalse())
                    expect(fileManager.fileExists(atPath: URL(string: song.album.artworkUrl!)!.path)).to(beFalse())
                    expect(fileManager.fileExists(atPath: URL(string: song.album.artist.artworkUrl!)!.path)).to(beFalse())
                }

                let artists = try songService.getArtists().toBlocking().first()
                expect(artists).to(beEmpty())
            }
            
            TestUtils.it("should throw when deleting currently downloading song") {

                _ = service.downloadSong(songMock).subscribe()
                
                expect { 
                    try service.deleteSongDownload(songMock.id).toBlocking().toArray()
                }.to(throwError())
                
                expect(delegate.didCompleteSongDownload).toEventuallyNot(beNil())
            }
            
            TestUtils.it("should throw when downloading currently deleting song") {

                _ = try service.downloadSong(songMock).toBlocking().toArray()
                var deleted = false
                _ = service.deleteSongDownload(songMock.id).subscribe(onNext: { _ in
                    deleted = true
                })

                expect {
                    try service.downloadSong(songMock).toBlocking().toArray()
                }.to(throwError())
                
                expect(deleted).toEventually(beTrue())
            }
            
            TestUtils.it("should fail song download") {
                
                apiServiceMock.songPath = nil
                
                expect { 
                    try service.downloadSong(songMock).toBlocking().toArray()
                }.to(throwError())

                expect(delegate.didStartSongDownload).toNot(beNil())
                expect(delegate.didProgressSongDownload).to(beNil())
                expect(delegate.didCompleteSongDownload).to(beNil())
                expect(delegate.didCancelSongDownload).to(beNil())
                expect(delegate.didFailSongDownload).toNot(beNil())
                expect(delegate.didDeleteSongDownload).to(beNil())
            }
        }
    }
}
