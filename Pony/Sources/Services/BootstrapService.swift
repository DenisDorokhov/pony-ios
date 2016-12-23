//
// Created by Denis Dorokhov on 14/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

protocol BootstrapServiceDelegate: class {
    
    func bootstrapServiceDidStartBootstrap(_: BootstrapService)
    func bootstrapService(_: BootstrapService, didFinishBootstrapWithUser: User)

    func bootstrapServiceDidStartBackgroundActivity(_: BootstrapService)

    func bootstrapServiceDidRequireApiUrl(_: BootstrapService)
    func bootstrapServiceDidRequireAuthentication(_: BootstrapService)

    func bootstrapService(_: BootstrapService, didFailWithError: Error)
}

class BootstrapService {

    let apiUrlDao: ApiUrlDao
    let securityService: SecurityService

    private var isBootstrapping = false

    private let disposeBag = DisposeBag()

    init(apiUrlDao: ApiUrlDao, securityService: SecurityService) {
        self.apiUrlDao = apiUrlDao
        self.securityService = securityService
    }

    func bootstrap(delegate: BootstrapServiceDelegate?) {
        if !isBootstrapping {

            Log.info("Bootstrapping...")
            isBootstrapping = true
            delegate?.bootstrapServiceDidStartBootstrap(self)

            if apiUrlDao.fetchUrl() != nil {
                if let currentUser = securityService.currentUser {
                    isBootstrapping = false
                    propagateBootstrapFinish(user: currentUser, delegate: delegate)
                } else {
                    delegate?.bootstrapServiceDidStartBackgroundActivity(self)
                    securityService.updateAuthenticationStatus().do(onNext: { state in
                                self.isBootstrapping = false
                                switch state {
                                case .notAuthenticated:
                                    Log.info("Bootstrapping requires authentication.")
                                    delegate?.bootstrapServiceDidRequireAuthentication(self)
                                case .authenticated(let user):
                                    self.propagateBootstrapFinish(user: user, delegate: delegate)
                                }
                            }, onError: { error in
                                self.isBootstrapping = false
                                delegate?.bootstrapService(self, didFailWithError: error)
                            }).subscribe().addDisposableTo(disposeBag)
                }
            } else {
                Log.info("Bootstrapping requires server URL.")
                isBootstrapping = false
                delegate?.bootstrapServiceDidRequireApiUrl(self)
            }
        } else {
            Log.warn("Could not bootstrap: already bootstrapping.")
        }
    }

    func clearBootstrapData() {
        Log.info("Clearing bootstrap data.")
        securityService.logout().subscribe().addDisposableTo(disposeBag)
        apiUrlDao.removeUrl()
    }

    func propagateBootstrapFinish(user: User, delegate: BootstrapServiceDelegate?) {
        Log.info("Bootstrap finished.")
        delegate?.bootstrapService(self, didFinishBootstrapWithUser: user)
    }
}
