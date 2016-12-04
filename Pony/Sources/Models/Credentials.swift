//
// Created by Denis Dorokhov on 29/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import ObjectMapper

class Credentials: Mappable {

    var email: String!
    var password: String!

    init(email: String, password: String) {
        self.email = email
        self.password = password
    }

    required init?(map: Map) {}

    func mapping(map: Map) {
        email <- map["email"]
        password <- map["password"]
    }
}
