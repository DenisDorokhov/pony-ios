//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import Quick
import Nimble

@testable import Pony

class TokenPairDaoSpec: QuickSpec {
    override func spec() {
        
        let buildTokenPair: () -> TokenPair = {
            return TokenPair(accessToken: "someAccessToken", accessTokenExpiration: Date(),
                    refreshToken: "someRefreshToken", refreshTokenExpiration: Date())
        }

        TestUtils.describe("TokenPairDaoImpl") {

            var dao: TokenPairDaoImpl!
            beforeEach {
                TestUtils.cleanAll()
                dao = TokenPairDaoImpl()
            }
            afterEach {
                TestUtils.cleanAll()
            }

            TestUtils.it("should be empty after cleaning") {
                expect(dao.fetchTokenPair()).to(beNil())
            }

            TestUtils.it("should store and fetch token pair") {
                dao.store(tokenPair: buildTokenPair())
                expect(dao.fetchTokenPair()).notTo(beNil())
            }

            TestUtils.it("should remove token pair") {
                dao.store(tokenPair: buildTokenPair())
                dao.removeTokenPair()
                expect(dao.fetchTokenPair()).to(beNil())
            }

            TestUtils.it("should not fetch token after the app is uninstalled") {
                dao.store(tokenPair: buildTokenPair())
                TestUtils.cleanUserDefaults()
                expect(dao.fetchTokenPair()).to(beNil())
            }
        }

        TestUtils.describe("TokenPairDaoCached") {

            var mock: TokenPairDaoMock!
            var dao: TokenPairDaoCached!
            beforeEach {
                TestUtils.cleanAll()
                mock = TokenPairDaoMock()
                dao = TokenPairDaoCached(tokenPairDao: mock)
            }

            TestUtils.it("should cache token pair") {
                dao.store(tokenPair: buildTokenPair())
                expect(dao.fetchTokenPair()).toNot(beNil())
                expect(mock.fetchTokenPairCallsCount).to(equal(0))
            }

            TestUtils.it("should cache absense of token pair") {
                expect(dao.fetchTokenPair()).to(beNil())
                expect(dao.fetchTokenPair()).to(beNil())
                expect(mock.fetchTokenPairCallsCount).to(equal(1))
            }

            TestUtils.it("should remember absense of token pair after removal") {
                dao.store(tokenPair: buildTokenPair())
                dao.removeTokenPair()
                expect(dao.fetchTokenPair()).to(beNil())
                expect(mock.fetchTokenPairCallsCount).to(equal(0))
            }
        }
    }
}
