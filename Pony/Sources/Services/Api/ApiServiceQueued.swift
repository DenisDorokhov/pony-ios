//
// Created by Denis Dorokhov on 05/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

class ApiServiceQueued: ApiService {
    
    let maxConcurrentImageRequests: Int
    let maxConcurrentSongRequests: Int

    private(set) var runningImageRequests = Variable(0)
    private(set) var runningSongRequests = Variable(0)

    private let targetService: ApiService

    private let imageSubject = PublishSubject<Observable<UIImage>>()
    private let songSubject = PublishSubject<Observable<Double>>()

    private let disposeBag = DisposeBag()

    init(targetService: ApiService, maxConcurrentImageRequests: Int = 8, maxConcurrentSongRequests: Int = 3) {
        self.targetService = targetService
        self.maxConcurrentImageRequests = maxConcurrentImageRequests
        self.maxConcurrentSongRequests = maxConcurrentSongRequests
        imageSubject.merge(maxConcurrent: maxConcurrentImageRequests).subscribe().addDisposableTo(disposeBag)
        songSubject.merge(maxConcurrent: maxConcurrentSongRequests).subscribe().addDisposableTo(disposeBag)
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
        return Observable.create { observer in
            let disposeSignal = PublishSubject<Bool>()
            self.imageSubject.onNext(self.targetService.downloadImage(atUrl: url)
                    .do(onNext: {
                        observer.onNext($0)
                    }, onError: {
                        observer.onError($0)
                    }, onCompleted: {
                        self.runningImageRequests.value -= 1
                        observer.onCompleted()
                    }, onSubscribe: {
                        self.runningImageRequests.value += 1
                    }).takeUntil(disposeSignal))
            return Disposables.create {
                disposeSignal.onNext(true)
                disposeSignal.onCompleted()
            }
        }
    }

    func downloadSong(atUrl url: String, toFile file: String) -> Observable<Double> {
        return Observable.create { observer in
            let disposeSignal = PublishSubject<Bool>()
            self.songSubject.onNext(self.targetService.downloadSong(atUrl: url, toFile: file)
                    .do(onNext: {
                        observer.onNext($0)
                    }, onError: {
                        observer.onError($0)
                    }, onCompleted: {
                        self.runningSongRequests.value -= 1
                        observer.onCompleted()
                    }, onSubscribe: {
                        self.runningSongRequests.value += 1
                    }).takeUntil(disposeSignal))
            return Disposables.create {
                disposeSignal.onNext(true)
                disposeSignal.onCompleted()
            }
        }
    }
}
