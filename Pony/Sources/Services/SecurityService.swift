//
// Created by Denis Dorokhov on 10/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift
import OrderedSet

protocol SecurityServiceDelegate: class {
    func securityService(_: SecurityService, didAuthenticateUser: User)
    func securityService(_: SecurityService, didUpdateCurrentUser: User)
    func securityService(_: SecurityService, didLogoutUser: User)
}

class SecurityService {

    enum AuthenticationStatus {
        case notAuthenticated
        case authenticated(user: User)
    }

    let apiService: ApiService
    let tokenPairDao: TokenPairDao

    let timeToRefreshTokenBeforeExpiration: TimeInterval
    
    var updateAuthenticationPeriodically: Bool

    var isAuthenticated: Bool {
        return currentUser != nil
    }

    private(set) var currentUser: User?

    private var delegates = Delegates<SecurityServiceDelegate>()

    private let queue = TaskPool(maxConcurrent: 1)
    private var cancellationSignal: PublishSubject<Void> = PublishSubject()

    private let disposeBag = DisposeBag()

    init(apiService: ApiService, tokenPairDao: TokenPairDao,
         tokenExpirationCheckInterval: TimeInterval = 60, timeToRefreshTokenBeforeExpiration: TimeInterval = 7 * 24 * 60 * 60,
         updateAuthenticationPeriodically: Bool = true) {

        self.apiService = apiService
        self.tokenPairDao = tokenPairDao
        self.timeToRefreshTokenBeforeExpiration = timeToRefreshTokenBeforeExpiration
        self.updateAuthenticationPeriodically = updateAuthenticationPeriodically

        queue.addDisposableTo(disposeBag)
        cancellationSignal.addDisposableTo(disposeBag)
        
        Observable<Int>.timer(0, period: tokenExpirationCheckInterval, scheduler: MainScheduler.instance)
                .flatMap { [weak self] (_) -> Observable<AuthenticationStatus> in
                    if let strongSelf = self, strongSelf.updateAuthenticationPeriodically {
                        Log.verbose("Scheduled authentication update...")
                        return strongSelf.updateAuthenticationStatus()
                    } else {
                        return Observable.empty()
                    }
                }
                .map { _ in }
                .catchErrorJustReturn()
                .subscribe().addDisposableTo(disposeBag)
    }

    func addDelegate(_ delegate: SecurityServiceDelegate) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: SecurityServiceDelegate) {
        delegates.remove(delegate)
    }

    func authenticate(credentials: Credentials) -> Observable<User> {
        return enqueue {
            if self.isAuthenticated {
                throw PonyError.alreadyAuthenticated
            }
            Log.info("Authenticating user '\(credentials.email ?? "")'...")
            return self.apiService.authenticate(credentials: credentials)
                    .do(onNext: { authentication in
                        Log.info("User '\(authentication.user.email ?? "")' has been authenticated.")
                        self.updateAuthentication(authentication)
                        self.propagateAuthentication(user: authentication.user)
                    }, onError: { error in
                        Log.error("Authentication failed for user '\(credentials.email ?? "")': \(error)")
                    }).map {
                        return $0.user
                    }
        }
    }

    func updateAuthenticationStatus() -> Observable<AuthenticationStatus> {
        return enqueue {
            if let accessTokenExpiration = self.tokenPairDao.fetchTokenPair()?.accessTokenExpiration.timeIntervalSinceNow {
                if accessTokenExpiration <= self.timeToRefreshTokenBeforeExpiration {
                    return self.refreshToken().map { AuthenticationStatus.authenticated(user: $0.user) }
                } else {
                    return self.apiService.getCurrentUser().map { user in
                        self.currentUser = user
                        self.propagateCurrentUserUpdate(user: user)
                        return AuthenticationStatus.authenticated(user: user) 
                    }
                }
            } else {
                return Observable.just(AuthenticationStatus.notAuthenticated)
            }
        }
    }

    func logout() -> Observable<User> {
        return Observable.deferred {
            self.cancellationSignal.onNext()
            if let user = self.currentUser {
                Log.info("Logging out user '\(user.email ?? "")'...")
                self.apiService.logout().do(onNext: { _ in
                    Log.info("User '\(user.email ?? "")' has logged out successfully.")
                }, onError: { error in
                    Log.error("Could not logout user '\(user.email ?? "")': \(error).")
                }).subscribe().addDisposableTo(self.disposeBag)
                self.clearAuthentication()
                self.propagateLogout(user: user)
                return Observable.just(user)
            } else {
                throw PonyError.notAuthenticated
            }
        }
    }

    private func refreshToken() -> Observable<Authentication> {
        Log.info("Refreshing access token...")
        return apiService.refreshToken().do(onNext: { authentication in
            self.updateAuthentication(authentication)
            self.propagateCurrentUserUpdate(user: authentication.user)
            Log.info("Token for user '\(authentication.user.email ?? "")' has been refreshed.")
        }, onError: { error in
            Log.error("Could not refresh token: \(error)")
        })
    }

    private func updateAuthentication(_ authentication: Authentication) {
        tokenPairDao.store(tokenPair: TokenPair(authentication: authentication))
        currentUser = authentication.user
    }

    private func clearAuthentication() {
        tokenPairDao.removeTokenPair()
        currentUser = nil
    }

    private func propagateAuthentication(user: User) {
        self.delegates.fetch().forEach { $0.securityService(self, didAuthenticateUser: user) }
    }

    private func propagateCurrentUserUpdate(user: User) {
        self.delegates.fetch().forEach { $0.securityService(self, didUpdateCurrentUser: user) }
    }

    private func propagateLogout(user: User) {
        self.delegates.fetch().forEach { $0.securityService(self, didLogoutUser: user) }
    }

    private func enqueue<T>(_ observable: @escaping () throws -> Observable<T>) -> Observable<T> {
        let enqueue = Observable.deferred {
            self.queue.add(Observable.deferred {
                try observable()
            })
        }
        let expectCancellation = cancellationSignal.flatMap { (_) -> Observable<T> in
            throw PonyError.cancelled
        }
        return Observable.amb([enqueue, expectCancellation])
    }
}
