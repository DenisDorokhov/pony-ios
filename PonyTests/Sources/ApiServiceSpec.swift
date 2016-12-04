//
// Created by Denis Dorokhov on 30/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import Quick
import Nimble
import ReachabilitySwift
import RxSwift
import RxBlocking

@testable import Pony

class ApiServiceSpec: QuickSpec {

    private let ONLINE_DEMO_URL = "http://pony.dorokhov.net/demo"
    private let OFFLINE_DEMO_URL = "http://localhost:8080"

    private let DEMO_EMAIL = "foo@bar.com"
    private let DEMO_PASSWORD = "demo"

    override func spec() {

        describe("ApiServiceImpl") {

            let isOffline = Reachability()?.currentReachabilityStatus == .notReachable

            var service: ApiServiceImpl!
            beforeEach {
                TestUtils.cleanAll()
                service = ApiServiceImpl()
                service.sessionManager = ApiSessionManager(debug: true)
                service.tokenPairDao = TokenPairDaoMock()
                service.restUrlDao = ApiUrlDaoMock(url: isOffline ? self.OFFLINE_DEMO_URL : self.ONLINE_DEMO_URL)
            }
            afterEach {
                TestUtils.cleanAll()
            }

            let credentials = Credentials(email: self.DEMO_EMAIL, password: self.DEMO_PASSWORD)
            
            let authenticateAndStoreToken: (Credentials) -> Authentication = {
                let authentication = try! service.authenticate(credentials: $0).toBlocking().first()!
                service.tokenPairDao.store(tokenPair: TokenPair(authentication: authentication))
                return authentication
            }

            it("should handle errors") {
                service.restUrlDao = ApiUrlDaoMock(url: "http://notExistingDomain")
                expect { 
                    try service.getInstallation().toBlocking().first() 
                }.to(throwError(errorType: ApiError.self))
            }

            it("should get installation") {
                let installation = try! service.getInstallation().toBlocking().first()
                expect(installation).toNot(beNil())
            }

            it("should authenticate") {
                let authentication = try! service.authenticate(credentials: credentials).toBlocking().first()
                expect(authentication).toNot(beNil())
            }

            it("should logout") {
                _ = authenticateAndStoreToken(credentials)
                let user = try! service.logout().toBlocking().first()
                expect(user).toNot(beNil())
            }

            it("should get current user") {
                _ = authenticateAndStoreToken(credentials)
                let user = try! service.getCurrentUser().toBlocking().first()
                expect(user).toNot(beNil())
            }

            it("should refresh token") {
                _ = authenticateAndStoreToken(credentials)
                let authentication = try! service.refreshToken().toBlocking().first()
                expect(authentication).toNot(beNil())
            }

            it("should get artists") {
                _ = authenticateAndStoreToken(credentials)
                let artists = try! service.getArtists().toBlocking().first()!
                expect(artists).toNot(beNil())
            }

            it("should get artist albums") {
                _ = authenticateAndStoreToken(credentials)
                let artists = try! service.getArtists().toBlocking().first()!
                let artistAlbums = try! service.getArtistAlbums(artistId: artists[0].id).toBlocking().first()!
                expect(artistAlbums).toNot(beNil())
            }

            it("should download image") {
                _ = authenticateAndStoreToken(credentials)
                let artists = try! service.getArtists().toBlocking().first()!
                let image = try! service.downloadImage(atUrl: artists[0].artworkUrl!).toBlocking().first()!
                expect(image).toNot(beNil())
            }

            it("should download song") {
                _ = authenticateAndStoreToken(credentials)
                let artists = try! service.getArtists().toBlocking().first()!
                let artistAlbums = try! service.getArtistAlbums(artistId: artists[0].id).toBlocking().first()!
                let filePath = FileUtils.generateTemporaryPath()
                let progresses = try! service.downloadSong(atUrl: artistAlbums.albums[0].songs[0].url, toFile: filePath).toBlocking().toArray()
                expect(progresses.count).to(beGreaterThan(0))
                expect(progresses.last).to(equal(1))
                expect(FileManager.default.fileExists(atPath: filePath)).to(beTrue())
            }
        }
    }
}
