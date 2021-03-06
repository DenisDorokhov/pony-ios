//
// Created by Denis Dorokhov on 06/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble
import RxSwift
import RxBlocking

@testable import Pony

class ArtworkServiceSpec: QuickSpec {
    override func spec() {
        TestUtils.describe("ArtworkService") {

            var apiServiceMock: ApiServiceMock!
            var delegate: ArtworkUsageCountProviderMock!
            var storageUrlProvider: StorageUrlProvider!
            var service: ArtworkService!
            beforeEach {
                TestUtils.cleanAll()

                let bundle = Bundle(for: type(of: self))

                apiServiceMock = ApiServiceMock()
                apiServiceMock.imagePath = bundle.path(forResource: "artwork", ofType: "png")!

                delegate = ArtworkUsageCountProviderMock()
                delegate.artworkToUsageCount[123] = 0
                delegate.artworkToUsageCount[456] = 0
                
                storageUrlProvider = StorageUrlProvider()

                service = ArtworkService(artworkUsageCountProvider: delegate, apiService: apiServiceMock, storageUrlProvider: storageUrlProvider)
            }
            afterEach {
                TestUtils.cleanAll()
            }

            TestUtils.it("should download artwork") {
                let usageCount = try service.useOrDownload(artwork: 123, url: "someUrl").toBlocking().first()
                expect(usageCount).to(equal(1))
                expect(apiServiceMock.didCallDownloadImage).to(beTrue())
                expect(FileManager.default.fileExists(atPath: storageUrlProvider.fileUrl(forArtwork: 123).path)).to(beTrue())
            }

            TestUtils.it("should remove artwork") {
                let usageCount = try service.useOrDownload(artwork: 123, url: "someUrl").flatMap { _ in
                            service.releaseOrRemove(artwork: 123)
                        }.toBlocking().first()
                expect(usageCount).to(equal(0))
                expect(FileManager.default.fileExists(atPath: storageUrlProvider.fileUrl(forArtwork: 123).path)).to(beFalse())
            }

            TestUtils.it("should increase usage count without calling api") {
                _ = try service.useOrDownload(artwork: 123, url: "someUrl").toBlocking().first()
                apiServiceMock.didCallDownloadImage = false
                let usageCount = try service.useOrDownload(artwork: 123, url: "someUrl").toBlocking().first()
                expect(usageCount).to(equal(2))
                expect(apiServiceMock.didCallDownloadImage).to(beFalse())
            }

            TestUtils.it("should decrease usage count") {
                let usageCount = try service.useOrDownload(artwork: 123, url: "someUrl").flatMap { _ in
                            service.useOrDownload(artwork: 123, url: "someUrl")
                        }.flatMap { _ in
                            service.releaseOrRemove(artwork: 123)
                        }.toBlocking().first()
                expect(usageCount).to(equal(1))
            }

            TestUtils.it("should avoid race conditions") {
                _ = service.useOrDownload(artwork: 123, url: "someUrl").subscribe()
                let usageCount = try service.useOrDownload(artwork: 123, url: "someUrl").toBlocking().first()
                expect(usageCount).to(equal(2))
            }
            
            TestUtils.it("should separate artwork downloads") {
                _ = service.useOrDownload(artwork: 123, url: "someUrl1").subscribe()
                _ = service.useOrDownload(artwork: 456, url: "someUrl2").subscribe()
                let usageCount = try service.useOrDownload(artwork: 456, url: "someUrl2").toBlocking().first()
                expect(usageCount).to(equal(2))
            }
            
            TestUtils.it("should cancel artwork download") {
                service.useOrDownload(artwork: 123, url: "someUrl1").subscribe().dispose()
                let usageCount = try service.useOrDownload(artwork: 123, url: "someUrl").toBlocking().first()
                expect(usageCount).to(equal(1))
            }
            
            TestUtils.it("should cancel artwork removal") {
                _ = try service.useOrDownload(artwork: 123, url: "someUrl").toBlocking().first()
                service.releaseOrRemove(artwork: 123).subscribe().dispose()
                let usageCount = try service.useOrDownload(artwork: 123, url: "someUrl").toBlocking().first()
                expect(usageCount).to(equal(2))
            }
        }
    }
}
