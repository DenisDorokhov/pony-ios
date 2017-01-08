//
// Created by Denis Dorokhov on 30/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

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
        TestUtils.describe("ApiServiceImpl") {

            let isOffline = Reachability()?.currentReachabilityStatus == .notReachable

            var service: ApiServiceImpl!
            beforeEach {
                TestUtils.cleanAll()
                service = ApiServiceImpl(sessionManager: ApiSessionManager(debug: true),
                        tokenPairDao: TokenPairDaoMock(),
                        apiUrlDao: ApiUrlDaoMock(url: isOffline ? self.OFFLINE_DEMO_URL : self.ONLINE_DEMO_URL))
            }
            afterEach {
                TestUtils.cleanAll()
            }

            let credentials = Credentials(email: self.DEMO_EMAIL, password: self.DEMO_PASSWORD)
            
            let authenticateAndStoreToken: (Credentials) throws -> Authentication = {
                if let authentication = try service.authenticate(credentials: $0).toTestBlocking().first() {
                    service.tokenPairDao.store(tokenPair: TokenPair(authentication: authentication))
                    return authentication
                } else {
                    throw PonyError.illegalState(message: "Authentication must not be nil.")
                }
            }

            TestUtils.it("should handle errors") {
                (service.apiUrlDao as! ApiUrlDaoMock).url = URL(string: "http://notExistingDomain")
                expect { 
                    try service.getInstallation().toTestBlocking().first() 
                }.to(throwError(errorType: PonyError.self))
            }

            TestUtils.it("should get installation") {
                let installation = try service.getInstallation().toTestBlocking().first()
                expect(installation).toNot(beNil())
            }

            TestUtils.it("should authenticate") {
                let authentication = try service.authenticate(credentials: credentials).toTestBlocking().first()
                expect(authentication).toNot(beNil())
            }

            TestUtils.it("should logout") {
                _ = try authenticateAndStoreToken(credentials)
                let user = try service.logout().toTestBlocking().first()
                expect(user).toNot(beNil())
            }

            TestUtils.it("should get current user") {
                _ = try authenticateAndStoreToken(credentials)
                let user = try service.getCurrentUser().toTestBlocking().first()
                expect(user).toNot(beNil())
            }

            TestUtils.it("should refresh token") {
                _ = try authenticateAndStoreToken(credentials)
                let authentication = try service.refreshToken().toTestBlocking().first()
                expect(authentication).toNot(beNil())
            }

            TestUtils.it("should get artists") {
                _ = try authenticateAndStoreToken(credentials)
                let artists = try service.getArtists().toTestBlocking().first()
                expect(artists).toNot(beNil())
            }

            TestUtils.it("should get artist albums") {
                _ = try authenticateAndStoreToken(credentials)
                let artists = try service.getArtists().toTestBlocking().first()
                let firstArtist = artists?.first?.id
                expect(firstArtist).toNot(beNil())
                if let firstArtist = firstArtist {
                    let artistAlbums = try service.getArtistAlbums(artistId: firstArtist).toTestBlocking().first()
                    expect(artistAlbums).toNot(beNil())
                }
            }

            TestUtils.it("should download image") {
                _ = try authenticateAndStoreToken(credentials)
                let artists = try service.getArtists().toTestBlocking().first()
                let firstArtistArtwork = artists?.first?.artworkUrl
                expect(firstArtistArtwork).toNot(beNil())
                if let firstArtistArtwork = firstArtistArtwork {
                    let image = try service.downloadImage(atUrl: firstArtistArtwork).toTestBlocking().first()
                    expect(image).toNot(beNil())
                }
            }

            TestUtils.it("should download song") {
                _ = try authenticateAndStoreToken(credentials)
                let artists = try service.getArtists().toTestBlocking().first()
                let firstArtist = artists?.first?.id
                expect(firstArtist).toNot(beNil())
                if let firstArtist = firstArtist {
                    let artistAlbums = try service.getArtistAlbums(artistId: firstArtist).toTestBlocking().first()
                    let firstSongUrl = artistAlbums?.albums?.first?.songs.first?.url
                    expect(firstSongUrl).toNot(beNil())
                    if let firstSongUrl = firstSongUrl {
                        let filePath = FileUtils.generateTemporaryPath()
                        let progresses = try service.downloadSong(atUrl: firstSongUrl, toFile: filePath).toTestBlocking().toArray()
                        expect(progresses.count).to(beGreaterThan(0))
                        expect(progresses.last).to(equal(1))
                        expect(FileManager.default.fileExists(atPath: filePath)).to(beTrue())
                    }
                }
            }
        }
    }
}
