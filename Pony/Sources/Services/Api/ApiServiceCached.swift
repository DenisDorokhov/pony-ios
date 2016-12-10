//
// Created by Denis Dorokhov on 01/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

class ApiServiceCached: ApiService {

    let targetService: ApiService
    let imageCache: Cache<UIImage>

    init(targetService: ApiService, imageCache: Cache<UIImage>) {
        self.targetService = targetService
        self.imageCache = imageCache
    }

    func getInstallation() -> Observable<Installation> {
        return targetService.getInstallation()
    }

    func authenticate(credentials: Credentials) -> Observable<Authentication> {
        return targetService.authenticate(credentials: credentials)
    }

    func logout() -> Observable<User> {
        return targetService.logout()
    }

    func getCurrentUser() -> Observable<User> {
        return targetService.getCurrentUser()
    }

    func refreshToken() -> Observable<Authentication> {
        return targetService.refreshToken()
    }

    func getArtists() -> Observable<[Artist]> {
        return targetService.getArtists()
    }

    func getArtistAlbums(artistId: Int64) -> Observable<ArtistAlbums> {
        return targetService.getArtistAlbums(artistId: artistId)
    }

    func downloadImage(atUrl url: String) -> Observable<UIImage> {
        return Observable.deferred {
            let downloadImageAndCache = self.targetService.downloadImage(atUrl: url)
                    .flatMap {
                        self.imageCache.set(object: $0, forKey: url)
                    }
            return self.imageCache.get(forKey: url).flatMap { (image) -> Observable<UIImage> in
                if let image = image {
                    return Observable.of(image)
                } else {
                    return downloadImageAndCache
                }
            }
        }
    }

    func downloadSong(atUrl url: String, toFile file: String) -> Observable<Double> {
        return targetService.downloadSong(atUrl: url, toFile: file)
    }
}
