//
// Created by Denis Dorokhov on 29/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import ObjectMapper

class Authentication: Mappable {

    var accessToken: String!
    var accessTokenExpiration: Date!

    var refreshToken: String!
    var refreshTokenExpiration: Date!

    var user: User!

    init(accessToken: String, accessTokenExpiration: Date,
         refreshToken: String, refreshTokenExpiration: Date,
         user: User) {
        self.accessToken = accessToken
        self.accessTokenExpiration = accessTokenExpiration
        self.refreshToken = refreshToken
        self.refreshTokenExpiration = refreshTokenExpiration
        self.user = user
    }

    required init?(map: Map) {}

    func mapping(map: Map) {
        accessToken <- map["accessToken"]
        accessTokenExpiration <- (map["accessTokenExpiration"], DateTransform())
        refreshToken <- map["refreshToken"]
        refreshTokenExpiration <- (map["refreshTokenExpiration"], DateTransform())
        user <- map["user"]
    }
}
