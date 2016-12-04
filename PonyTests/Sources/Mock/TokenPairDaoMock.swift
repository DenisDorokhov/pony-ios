//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

@testable import Pony

class TokenPairDaoMock: TokenPairDao {

    var tokenPair: TokenPair?

    private(set) var fetchTokenPairCallsCount: Int = 0

    init(tokenPair: TokenPair? = nil) {
        self.tokenPair = tokenPair
    }

    func fetchTokenPair() -> TokenPair? {

        fetchTokenPairCallsCount += 1

        return tokenPair
    }

    func store(tokenPair: TokenPair) {
        self.tokenPair = tokenPair
    }

    func removeTokenPair() {
        tokenPair = nil
    }
}
