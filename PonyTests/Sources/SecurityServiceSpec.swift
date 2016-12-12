//
// Created by Denis Dorokhov on 12/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble
import RxSwift
import RxBlocking
import SwiftDate

@testable import Pony

class SecurityServiceSpec: QuickSpec {
    override func spec() {
        describe("SecurityService") {

            var credentials: Credentials!
            var apiServiceMock: ApiServiceMock!
            var tokenPairDaoMock: TokenPairDaoMock!
            var service: SecurityService!
            var delegate: SecurityServiceDelegateMock!
            beforeEach {
                TestUtils.cleanAll()

                credentials = Credentials(email: "foo@bar.com", password: "demo")

                let user = User(id: 1, creationDate: Date(), name: "Foo Bar", email: "foo@bar.com", role: .user)
                let authentication = Authentication(
                        accessToken: "accessToken", accessTokenExpiration: Date() + 2.hour,
                        refreshToken: "refreshToken", refreshTokenExpiration: Date() + 1.day,
                        user: user)

                apiServiceMock = ApiServiceMock()
                apiServiceMock.authentication = authentication
                apiServiceMock.refreshTokenAuthentication = authentication
                apiServiceMock.currentUser = user
                apiServiceMock.logoutUser = user

                tokenPairDaoMock = TokenPairDaoMock(tokenPair: TokenPair(authentication: authentication))

                service = SecurityService(apiService: apiServiceMock, tokenPairDao: tokenPairDaoMock, updateAuthenticationPeriodically: false)
                
                delegate = SecurityServiceDelegateMock()
                service.addDelegate(delegate: delegate)
            }
            afterEach {
                TestUtils.cleanAll()
            }

            it("should authenticate") {
                
                let user = try! service.authenticate(credentials: credentials).toBlocking().first()
                expect(user).notTo(beNil())
                expect(service.isAuthenticated).to(beTrue())
                
                expect(apiServiceMock.didCallAuthenticate).to(beTrue())
                expect(apiServiceMock.didCallGetCurrentUser).to(beFalse())
                expect(apiServiceMock.didCallRefreshToken).to(beFalse())
                
                expect(delegate.didAuthenticateUser).toNot(beNil())
                expect(delegate.didUpdateCurrentUser).to(beNil())
                expect(delegate.didLogoutUser).to(beNil())
            }

            it("should update status after authentication") {
                
                _ = try! service.authenticate(credentials: credentials).toBlocking().first()
                let status = try! service.updateAuthenticationStatus().toBlocking().first()!
                switch status {
                case .authenticated(_):
                    expect(apiServiceMock.didCallGetCurrentUser).to(beTrue())
                    expect(apiServiceMock.didCallRefreshToken).to(beFalse())
                default:
                    fail("not authenticated")
                }

                expect(delegate.didAuthenticateUser).toNot(beNil())
                expect(delegate.didUpdateCurrentUser).toNot(beNil())
                expect(delegate.didLogoutUser).to(beNil())
            }

            it("should update status without authentication") {
                
                let status = try! service.updateAuthenticationStatus().toBlocking().first()!
                expect(service.isAuthenticated).to(beTrue())
                switch status {
                case .authenticated(_):
                    expect(apiServiceMock.didCallGetCurrentUser).to(beTrue())
                    expect(apiServiceMock.didCallRefreshToken).to(beFalse())
                default:
                    fail("not authenticated")
                }

                expect(delegate.didAuthenticateUser).to(beNil())
                expect(delegate.didUpdateCurrentUser).toNot(beNil())
                expect(delegate.didLogoutUser).to(beNil())
            }

            it("should refresh token when updating status") {

                let tokenPair = TokenPair(accessToken: "accessToken", accessTokenExpiration: Date(),
                        refreshToken: "refreshToken", refreshTokenExpiration: Date() + 1.day)
                tokenPairDaoMock.store(tokenPair: tokenPair)

                let status = try! service.updateAuthenticationStatus().toBlocking().first()!
                switch status {
                case .authenticated(_):
                    expect(apiServiceMock.didCallGetCurrentUser).to(beFalse())
                    expect(apiServiceMock.didCallRefreshToken).to(beTrue())
                default:
                    fail("not authenticated")
                }

                expect(delegate.didAuthenticateUser).to(beNil())
                expect(delegate.didUpdateCurrentUser).toNot(beNil())
                expect(delegate.didLogoutUser).to(beNil())
            }

            it("should avoid race conditions when authenticating and updating status") {
                
                apiServiceMock.authenticateDelay = 0.3
                apiServiceMock.getCurrentUserDelay = 0.1
                
                var order = [Int]()
                _ = service.authenticate(credentials: credentials).subscribe(onCompleted: {
                    order.append(1)
                })
                _ = service.updateAuthenticationStatus().subscribe(onCompleted: {
                    order.append(2)
                })
                expect(order.first).toEventually(equal(1))
                expect(order.last).toEventually(equal(2))
            }
            
            it("should logout") {
                
                try! service.logout().toBlocking().first()
                expect(service.isAuthenticated).to(beFalse())

                expect(apiServiceMock.didCallGetCurrentUser).to(beTrue())
                expect(apiServiceMock.didCallLogout).to(beTrue())

                expect(delegate.didAuthenticateUser).to(beNil())
                expect(delegate.didUpdateCurrentUser).to(beNil())
                expect(delegate.didLogoutUser).toNot(beNil())
            }
            
            it("should cancel authentication and status requests when logging out") {
                var errorRequests = 0
                _ = service.updateAuthenticationStatus().subscribe(onError: { _ in
                            errorRequests += 1
                        })
                _ = service.updateAuthenticationStatus().subscribe(onError: { _ in
                            errorRequests += 1
                        })
                _ = service.logout().subscribe()
                expect(errorRequests).toEventually(equal(2))
            }
        }
    }
}
