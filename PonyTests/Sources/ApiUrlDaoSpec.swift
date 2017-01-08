//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble

@testable import Pony

class ApiUrlDaoSpec: QuickSpec {
    override func spec() {
        TestUtils.describe("ApiUrlDao") {

            var dao: ApiUrlDaoImpl!

            beforeEach {
                TestUtils.cleanAll()
                dao = ApiUrlDaoImpl()
            }
            afterEach {
                TestUtils.cleanAll()
            }

            TestUtils.it("should be empty after cleaning") {
                expect(dao.fetchUrl()).to(beNil())
            }

            TestUtils.it("should store and fetch URL") {

                dao.store(url: URL(string: "http://google.com")!)

                let url = dao.fetchUrl()

                expect(url?.absoluteString).to(equal("http://google.com"))
            }

            TestUtils.it("should remove token pair") {
                dao.store(url: URL(string: "http://google.com")!)
                dao.removeUrl()
                expect(dao.fetchUrl()).to(beNil())
            }
        }
    }
}
