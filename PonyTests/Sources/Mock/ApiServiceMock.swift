//
// Created by Denis Dorokhov on 01/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

@testable import Pony

class ApiServiceMock: ApiService {

    var installation: Installation?
    var authentication: Authentication?
    var logoutUser: User?
    var currentUser: User?
    var refreshTokenAuthentication: Authentication?
    var artists: [Artist]?
    var artistAlbums: ArtistAlbums?
    var imagePath: String?
    var songPath: String?

    var didCallGetInstallation = false
    var didCallAuthenticate = false
    var didCallLogout = false
    var didCallGetCurrentUser = false
    var didCallRefreshToken = false
    var didCallGetArtists = false
    var didCallGetArtistAlbums = false
    var didCallDownloadImage = false
    var didCallDownloadSong = false

    var error = ApiError.unexpected

    func getInstallation() -> Observable<Installation> {
        return buildObservable(installation) {
            self.didCallGetInstallation = true
        }
    }

    func authenticate(credentials: Credentials) -> Observable<Authentication> {
        return buildObservable(authentication) {
            self.didCallAuthenticate = true
        }
    }

    func logout() -> Observable<User> {
        return buildObservable(logoutUser) {
            self.didCallLogout = true
        }
    }

    func getCurrentUser() -> Observable<User> {
        return buildObservable(currentUser) {
            self.didCallGetCurrentUser = true
        }
    }

    func refreshToken() -> Observable<Authentication> {
        return buildObservable(refreshTokenAuthentication) {
            self.didCallRefreshToken = true
        }
    }

    func getArtists() -> Observable<[Artist]> {
        return buildObservable(artists) {
            self.didCallGetArtists = true
        }
    }

    func getArtistAlbums(artistId: Int64) -> Observable<ArtistAlbums> {
        return buildObservable(artistAlbums) {
            self.didCallGetArtistAlbums = true
        }
    }

    func downloadImage(atUrl: String) -> Observable<UIImage> {
        return Observable.deferred {
            let image: UIImage?
            if let imagePath = self.imagePath {
                image = UIImage(data: try! Data(contentsOf: URL(fileURLWithPath: imagePath)))!
            } else {
                image = nil
            }
            return self.buildObservable(image, delay: 0.3) {
                self.didCallDownloadImage = true
            }
        }
    }

    func downloadSong(atUrl: String, toFile: String) -> Observable<Double> {
        return Observable.deferred {
            self.didCallDownloadSong = true
            if let songPath = self.songPath {
                try! FileManager.default.copyItem(atPath: songPath, toPath: toFile)
                return Observable.of(0.3, 0.6, 1.0)
            } else {
                return Observable.error(self.error)
            }
        }.delay(0.5, scheduler: MainScheduler.instance)
    }
    
    private func buildObservable<T>(_ value: T?, delay: RxTimeInterval = 0.1, action: @escaping () -> Void) -> Observable<T> {
        return Observable.deferred {
            action()
            if let value = value {
                return Observable.just(value)
            } else {
                return Observable.error(self.error)
            }
        }.delay(delay, scheduler: MainScheduler.instance)
    }

}
