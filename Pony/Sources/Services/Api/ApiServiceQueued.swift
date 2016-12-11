//
// Created by Denis Dorokhov on 05/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

class ApiServiceQueued: ApiService {
    
    let targetService: ApiService
    
    let maxConcurrentImageRequests: Int
    let maxConcurrentSongRequests: Int

    private(set) var runningImageRequests = Variable(0)
    private(set) var runningSongRequests = Variable(0)

    private let imagePool: TaskPool<UIImage>
    private let songPool: TaskPool<Double>

    private let disposeBag = DisposeBag()

    init(targetService: ApiService, maxConcurrentImageRequests: Int = 8, maxConcurrentSongRequests: Int = 3) {
        
        self.targetService = targetService
        self.maxConcurrentImageRequests = maxConcurrentImageRequests
        self.maxConcurrentSongRequests = maxConcurrentSongRequests
        
        imagePool = TaskPool(maxConcurrent: maxConcurrentImageRequests)
        imagePool.addDisposableTo(disposeBag)
        
        songPool = TaskPool(maxConcurrent: maxConcurrentSongRequests)
        songPool.addDisposableTo(disposeBag)
        
        imagePool.runningTasks.asObservable().subscribe(onNext: { [weak self] value in
                    self?.runningImageRequests.value = value
                }).addDisposableTo(disposeBag)
        songPool.runningTasks.asObservable().subscribe(onNext: { [weak self] in
                    self?.runningSongRequests.value = $0
                }).addDisposableTo(disposeBag)
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
            self.imagePool.add(self.targetService.downloadImage(atUrl: url))
        }
    }

    func downloadSong(atUrl url: String, toFile file: String) -> Observable<Double> {
        return Observable.deferred {
            self.songPool.add(self.targetService.downloadSong(atUrl: url, toFile: file))
        }
    }
}
