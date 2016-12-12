//
// Created by Denis Dorokhov on 12/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

@testable import Pony

class SecurityServiceDelegateMock: SecurityServiceDelegate {
    
    var didAuthenticateUser: User?
    var didUpdateCurrentUser: User?
    var didLogoutUser: User?

    func securityService(_ securityService: SecurityService, didAuthenticateUser user: User) {
        didAuthenticateUser = user
    }

    func securityService(_ securityService: SecurityService, didUpdateCurrentUser user: User) {
        didUpdateCurrentUser = user
    }

    func securityService(_ securityService: SecurityService, didLogoutUser user: User) {
        didLogoutUser = user
    }
}
