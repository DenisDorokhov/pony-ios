//
// Created by Denis Dorokhov on 30/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

@testable import Pony

class ApiUrlDaoMock: ApiUrlDao {

    var url: URL?

    init(url: String? = nil) {
        self.url = url != nil ? URL(string: url!)! : nil
    }

    func fetchUrl() -> URL? {
        return url
    }

    func store(url: URL) {
        self.url = url
    }

    func removeUrl() {
        url = nil
    }
}
