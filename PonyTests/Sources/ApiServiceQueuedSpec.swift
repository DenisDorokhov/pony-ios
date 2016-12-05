//
// Created by Denis Dorokhov on 05/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble
import RxSwift
import RxBlocking

@testable import Pony

class ApiServiceQueuedSpec: QuickSpec {
    override func spec() {
        describe("ApiServiceQueued") {

            var apiServiceMock: ApiServiceMock!
            var service: ApiServiceQueued!
            beforeEach {
                TestUtils.cleanAll()

                let bundle = Bundle(for: type(of: self))

                apiServiceMock = ApiServiceMock()
                apiServiceMock.imagePath = bundle.path(forResource: "artwork", ofType: "png")!
                apiServiceMock.songPath = bundle.path(forResource: "song", ofType: "mp3")!

                service = ApiServiceQueued(targetService: apiServiceMock)
            }
            afterEach {
                TestUtils.cleanAll()
            }

            it("should respect max concurrent image requests") {
                var observables: [Observable<UIImage>] = []
                for _ in 1 ... 20 {
                    observables.append(service.downloadImage(atUrl: "someUrl"))
                }
                _ = service.runningImageRequests.asObservable().subscribe(onNext: {
                    Log.debug("Number of running image requests: \($0).")
                    expect($0).to(beLessThanOrEqualTo(service.maxConcurrentImageRequests))
                })
                let images = try! Observable.from(observables).merge().toBlocking().toArray()
                expect(images).to(haveCount(observables.count))
            }

            it("should respect max concurrent song requests") {
                var observables: [Observable<Double>] = []
                var filePaths: [String] = []
                for _ in 1 ... 10 {
                    let filePath = FileUtils.generateTemporaryPath()
                    filePaths.append(filePath)
                    observables.append(service.downloadSong(atUrl: "someUrl", toFile: filePath))
                }
                _ = service.runningSongRequests.asObservable().subscribe(onNext: {
                    Log.debug("Number of running song requests: \($0).")
                    expect($0).to(beLessThanOrEqualTo(service.maxConcurrentSongRequests))
                })
                _ = try! Observable.from(observables).merge().toBlocking().toArray()
                for filePath in filePaths {
                    expect(FileManager.default.fileExists(atPath: filePath)).to(beTrue())
                }
            }
        }
    }
}
