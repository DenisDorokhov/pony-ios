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
            var songService: SongServiceImpl!
            var delegate: SongDownloadServiceDelegateMock!
            var service: SongDownloadService!
            beforeEach {
                TestUtils.cleanAll()

                let bundle = Bundle(for: type(of: self))
                
                apiServiceMock = ApiServiceMock()
                apiServiceMock.imagePath = bundle.path(forResource: "artwork", ofType: "png")!
                apiServiceMock.songPath = bundle.path(forResource: "song", ofType: "mp3")!
                
                let storageUrlProvider = StorageUrlProvider()
                
                songService = SongServiceImpl(context: SongServiceImpl.Context(), storageUrlProvider: storageUrlProvider, searchService: SearchServiceMock())
                
                let artworkService = ArtworkServiceImpl(artworkUsageCountProvider: songService, apiService: apiServiceMock, storageUrlProvider: storageUrlProvider)
                
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
                
                if let songUrl = delegate.didCompleteSongDownload?.url {
                    expect(FileManager.default.fileExists(atPath: URL(string: songUrl)!.path)).to(beTrue())
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
                if let songUrl = deletedSong?.url {
                    expect(FileManager.default.fileExists(atPath: URL(string: songUrl)!.path)).to(beFalse())
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
