//
// Created by Denis Dorokhov on 10/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift
import OrderedSet

protocol SecurityServiceDelegate: class {
    func securityService(_ securityService: SecurityService, didAuthenticateUser user: User)
    func securityService(_ securityService: SecurityService, didUpdateCurrentUser user: User)
    func securityService(_ securityService: SecurityService, didLogoutUser user: User)
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

    private var delegates: OrderedSet<NSValue> = []

    private let queue = TaskPool(maxConcurrent: 1)
    private var errorSignal: PublishSubject<Void> = PublishSubject()

    private let disposeBag = DisposeBag()

    init(apiService: ApiService, tokenPairDao: TokenPairDao,
         tokenExpirationCheckInterval: TimeInterval = 60, timeToRefreshTokenBeforeExpiration: TimeInterval = 60 * 60,
         updateAuthenticationPeriodically: Bool = true) {

        self.apiService = apiService
        self.tokenPairDao = tokenPairDao
        self.timeToRefreshTokenBeforeExpiration = timeToRefreshTokenBeforeExpiration
        self.updateAuthenticationPeriodically = updateAuthenticationPeriodically

        queue.addDisposableTo(disposeBag)
        errorSignal.addDisposableTo(disposeBag)
        
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

    func addDelegate(delegate: SecurityServiceDelegate) {
        delegates.append(NSValue(nonretainedObject: delegate))
    }

    func removeDelegate(delegate: SecurityServiceDelegate) {
        delegates.remove(NSValue(nonretainedObject: delegate))
    }

    func authenticate(credentials: Credentials) -> Observable<User> {
        return enqueue {
            Log.info("Authenticating user '\(credentials.email)'...")
            return self.apiService.authenticate(credentials: credentials)
                    .do(onNext: { authentication in
                        Log.info("User '\(authentication.user.email)' has been authenticated.")
                        self.updateAuthentication(authentication)
                        self.propagateAuthentication(user: authentication.user)
                    }, onError: { error in
                        Log.error("Authentication failed for user '\(credentials.email)': \(error)")
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

    func logout() -> Observable<Void> {
        return Observable.deferred {
            self.errorSignal.onNext()
            return self.enqueue {
                let getCurrentUser: Observable<User>
                if let user = self.currentUser {
                    getCurrentUser = Observable.just(user)
                } else {
                    getCurrentUser = self.apiService.getCurrentUser()
                }
                return getCurrentUser.flatMap { user in
                    self.apiService.logout().do(onNext: { _ in
                                Log.info("User '\(user.email)' has logged out successfully.")
                            }, onError: { error in
                                Log.error("Could not logout user '\(user.email)': \(error).")
                            }).catchErrorJustReturn(user)
                }.do(onNext: { user in
                    self.clearAuthentication()
                    self.propagateLogout(user: user)
                }).map { _ in }
            }
        }
    }

    private func refreshToken() -> Observable<Authentication> {
        Log.info("Refreshing access token...")
        return apiService.refreshToken().do(onNext: { authentication in
            self.updateAuthentication(authentication)
            self.propagateCurrentUserUpdate(user: authentication.user)
            Log.info("Token for user '\(authentication.user.email)' has been refreshed.")
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
        self.fetchDelegates().forEach { $0.securityService(self, didAuthenticateUser: user) }
    }

    private func propagateCurrentUserUpdate(user: User) {
        self.fetchDelegates().forEach { $0.securityService(self, didUpdateCurrentUser: user) }
    }

    private func propagateLogout(user: User) {
        self.fetchDelegates().forEach { $0.securityService(self, didLogoutUser: user) }
    }

    private func fetchDelegates() -> [SecurityServiceDelegate] {
        return delegates.map { $0.nonretainedObjectValue as! SecurityServiceDelegate }
    }

    private func enqueue<T>(_ observable: @escaping () throws -> Observable<T>) -> Observable<T> {
        let enqueue = Observable.deferred {
            self.queue.add(Observable.deferred {
                try observable()
            })
        }
        let expectCancellation = errorSignal.flatMap { (_) -> Observable<T> in
            throw PonyError.cancelled
        }
        return Observable.amb([enqueue, expectCancellation])
    }
}
