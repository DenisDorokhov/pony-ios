//
// Created by Denis Dorokhov on 14/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble
import RxSwift
import RxBlocking
import SwiftDate

@testable import Pony

class BootstrapServiceSpec: QuickSpec {
    override func spec() {
        describe("BootstrapService") {

            var apiUrlDaoMock: ApiUrlDaoMock!
            var tokenPairDaoMock: TokenPairDaoMock!
            var apiServiceMock: ApiServiceMock!
            var securityService: SecurityService!
            var userMock: User!
            var authenticationMock: Authentication!
            var service: BootstrapService!
            var delegate: BootstrapServiceDelegateMock!
            beforeEach {
                TestUtils.cleanAll()
                
                userMock = User(id: 1, creationDate: Date(), name: "Foo Bar", email: "foo@bar.com", role: .user)
                authenticationMock = Authentication(
                        accessToken: "accessToken", accessTokenExpiration: Date() + 8.days,
                        refreshToken: "refreshToken", refreshTokenExpiration: Date() + 1.day,
                        user: userMock)

                apiServiceMock = ApiServiceMock()
                apiServiceMock.logoutUser = userMock
                apiServiceMock.currentUser = userMock

                tokenPairDaoMock = TokenPairDaoMock()

                securityService = SecurityService(apiService: apiServiceMock, tokenPairDao: tokenPairDaoMock,
                        updateAuthenticationPeriodically: false)

                apiUrlDaoMock = ApiUrlDaoMock()

                service = BootstrapService(apiUrlDao: apiUrlDaoMock, securityService: securityService)
                delegate = BootstrapServiceDelegateMock()
            }
            afterEach {
                TestUtils.cleanAll()
            }

            it("should start bootstrap and require api url") {
                
                service.bootstrap(delegate: delegate)
                
                expect(delegate.didStartBootstrap).to(beTrue())
                expect(delegate.didFinishBootstrapWithUser).to(beNil())
                expect(delegate.didStartBackgroundActivity).to(beFalse())
                expect(delegate.didRequireApiUrl).to(beTrue())
                expect(delegate.didRequireAuthentication).to(beFalse())
                expect(delegate.didFailWithError).to(beNil())
            }

            it("should start background activity and require authentication") {
                
                apiUrlDaoMock.store(url: URL(string: "http://someUrl")!)
                service.bootstrap(delegate: delegate)

                expect(delegate.didStartBootstrap).to(beTrue())
                expect(delegate.didFinishBootstrapWithUser).to(beNil())
                expect(delegate.didStartBackgroundActivity).to(beTrue())
                expect(delegate.didRequireApiUrl).to(beFalse())
                expect(delegate.didRequireAuthentication).to(beTrue())
                expect(delegate.didFailWithError).to(beNil())
            }

            it("should finish bootstrap") {
                
                apiUrlDaoMock.store(url: URL(string: "http://someUrl")!)
                tokenPairDaoMock.store(tokenPair: TokenPair(authentication: authenticationMock))
                service.bootstrap(delegate: delegate)

                expect(delegate.didStartBootstrap).to(beTrue())
                expect(delegate.didFinishBootstrapWithUser).toEventuallyNot(beNil())
                expect(delegate.didStartBackgroundActivity).to(beTrue())
                expect(delegate.didRequireApiUrl).to(beFalse())
                expect(delegate.didRequireAuthentication).to(beFalse())
                expect(delegate.didFailWithError).to(beNil())
            }

            it("should fail on error") {
                
                apiUrlDaoMock.store(url: URL(string: "http://someUrl")!)
                tokenPairDaoMock.store(tokenPair: TokenPair(authentication: authenticationMock))
                apiServiceMock.currentUser = nil
                service.bootstrap(delegate: delegate)

                expect(delegate.didStartBootstrap).to(beTrue())
                expect(delegate.didFinishBootstrapWithUser).to(beNil())
                expect(delegate.didStartBackgroundActivity).to(beTrue())
                expect(delegate.didRequireApiUrl).to(beFalse())
                expect(delegate.didRequireAuthentication).to(beFalse())
                expect(delegate.didFailWithError).toNot(beNil())
            }

            it("should clear bootstrap data") {
                
                apiUrlDaoMock.store(url: URL(string: "http://someUrl")!)
                tokenPairDaoMock.store(tokenPair: TokenPair(authentication: authenticationMock))
                _ = try! securityService.updateAuthenticationStatus().toBlocking().first()
                
                expect(securityService.isAuthenticated).to(beTrue())
                
                service.clearBootstrapData()
                
                expect(securityService.isAuthenticated).to(beFalse())
                expect(apiUrlDaoMock.fetchUrl()).to(beNil())
            }
        }
    }
}
