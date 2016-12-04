//
// Created by Denis Dorokhov on 01/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble
import RxSwift
import RxBlocking

@testable import Pony

class ApiServiceCachedSpec: QuickSpec {
    override func spec() {
        describe("ApiServiceCached") {

            var apiServiceMock: ApiServiceMock!
            var service: ApiServiceCached!
            beforeEach {
                TestUtils.cleanAll()

                let bundle = Bundle(for: type(of: self))

                apiServiceMock = ApiServiceMock()
                apiServiceMock.imagePath = bundle.path(forResource: "artwork", ofType: "png")!

                service = ApiServiceCached(targetService: apiServiceMock,
                        imageCache: Cache(provider: CacheProviderMock<UIImage>()))
            }
            afterEach {
                TestUtils.cleanAll()
            }

            it("should cache image") {

                _ = try! service.downloadImage(atUrl: "someUrl").toBlocking().first()!
                expect(apiServiceMock.didCallDownloadImage).to(beTrue())

                apiServiceMock.didCallDownloadImage = false
                
                _ = try! service.downloadImage(atUrl: "someUrl").toBlocking().first()!
                expect(apiServiceMock.didCallDownloadImage).to(beFalse())
            }
        }
    }
}
