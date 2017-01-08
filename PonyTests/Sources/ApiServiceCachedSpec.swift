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
        TestUtils.describe("ApiServiceCached") {

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

            TestUtils.it("should cache image") {
                
                var image: UIImage?

                image = try service.downloadImage(atUrl: "someUrl").toBlocking().first()
                expect(image).toNot(beNil())
                expect(apiServiceMock.didCallDownloadImage).to(beTrue())

                apiServiceMock.didCallDownloadImage = false
                
                image = try service.downloadImage(atUrl: "someUrl").toBlocking().first()
                expect(image).toNot(beNil())
                expect(apiServiceMock.didCallDownloadImage).to(beFalse())
            }
        }
    }
}
