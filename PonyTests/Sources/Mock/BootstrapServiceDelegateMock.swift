//
// Created by Denis Dorokhov on 23/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

@testable import Pony

class BootstrapServiceDelegateMock: BootstrapServiceDelegate {
    
    var didStartBootstrap = false
    var didFinishBootstrapWithUser: User?
    var didStartBackgroundActivity = false
    var didRequireApiUrl = false
    var didRequireAuthentication = false
    var didFailWithError: Error?

    func bootstrapServiceDidStartBootstrap(_: BootstrapService) {
        didStartBootstrap = true
    }

    func bootstrapService(_: BootstrapService, didFinishBootstrapWithUser user: User) {
        didFinishBootstrapWithUser = user
    }

    func bootstrapServiceDidStartBackgroundActivity(_: BootstrapService) {
        didStartBackgroundActivity = true
    }

    func bootstrapServiceDidRequireApiUrl(_: BootstrapService) {
        didRequireApiUrl = true
    }

    func bootstrapServiceDidRequireAuthentication(_: BootstrapService) {
        didRequireAuthentication = true
    }

    func bootstrapService(_: BootstrapService, didFailWithError error: Error) {
        didFailWithError = error
    }
}
