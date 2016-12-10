//
// Created by Denis Dorokhov on 06/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

fileprivate class ArtworkDownloadChannel {

    let artwork: Int64
    let queue: PublishSubject<Observable<Int>>

    var referenceCount: Int = 0 {
        didSet {
            if oldValue == 0 && referenceCount == 1 {
                disposable = queue.concat().subscribe()
            }
            if referenceCount <= 0 {
                dispose()
            }
        }
    }

    private var disposable: Disposable?

    init(_ artwork: Int64) {
        self.artwork = artwork
        queue = PublishSubject()
    }
    
    deinit {
        dispose()
    }

    private func dispose() {
        disposable?.dispose()
        disposable = nil
    }
}

protocol ArtworkServiceDelegate: class {
    func getUsageCount(forArtwork: Int64) -> Observable<Int>
}

class ArtworkService {

    let delegate: ArtworkServiceDelegate
    let apiService: ApiService
    let storageUrlProvider: StorageUrlProvider

    private var artworkToUsageCount: [Int64: Int] = [:]
    private var artworkToChannel: [Int64: ArtworkDownloadChannel] = [:]

    private var fileOperationScheduler = ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global(qos: .default))

    init(delegate: ArtworkServiceDelegate, apiService: ApiService, storageUrlProvider: StorageUrlProvider) {
        self.delegate = delegate
        self.apiService = apiService
        self.storageUrlProvider = storageUrlProvider
    }

    func useOrDownload(artwork: Int64, url: String) -> Observable<Int> {
        return Observable.create { observer in
            let disposeSignal = ReplaySubject<Void>.createUnbounded()
            self.retainChannel(forArtwork: artwork).onNext(
                            self.fetchUsageCount(forArtwork: artwork).flatMap {
                                self.useOrDownload(artwork: artwork, url: url, usageCount: $0)
                            }.takeUntil(disposeSignal).do(onNext: {
                                self.cacheUsageCount($0, forArtwork: artwork)
                                observer.onNext($0)
                                observer.onCompleted()
                            }, onError: {
                                observer.onError($0)
                            }, onDispose: {
                                self.releaseChannel(forArtwork: artwork)
                                Log.debug("Use / download cancelled for artwork '\(artwork)'.")
                            }))
            return Disposables.create {
                disposeSignal.onNext()
                disposeSignal.onCompleted()
            }
        }
    }

    func releaseOrRemove(artwork: Int64) -> Observable<Int> {
        return Observable.create { observer in
            let disposeSignal = ReplaySubject<Void>.createUnbounded()
            self.retainChannel(forArtwork: artwork).onNext(
                            self.fetchUsageCount(forArtwork: artwork).flatMap {
                                self.releaseOrRemove(artwork: artwork, usageCount: $0)
                            }.takeUntil(disposeSignal).do(onNext: {
                                self.cacheUsageCount($0, forArtwork: artwork)
                                observer.onNext($0)
                                observer.onCompleted()
                            }, onError: {
                                observer.onError($0)
                            }, onDispose: {
                                self.releaseChannel(forArtwork: artwork)
                                Log.debug("Release / removal cancelled for artwork '\(artwork)'.")
                            }))
            return Disposables.create {
                disposeSignal.onNext()
                disposeSignal.onCompleted()
            }
        }
    }

    private func retainChannel(forArtwork artwork: Int64) -> PublishSubject<Observable<Int>> {
        if let channel = artworkToChannel[artwork] {
            let newReferenceCount = channel.referenceCount + 1
            Log.verbose("Retaining channel for artwork '\(artwork)': \(newReferenceCount).")
            channel.referenceCount = newReferenceCount
            return channel.queue
        } else {
            Log.verbose("Creating channel for artwork '\(artwork)'.")
            let channel = ArtworkDownloadChannel(artwork)
            channel.referenceCount = 1
            artworkToChannel[artwork] = channel
            return channel.queue
        }
    }

    private func releaseChannel(forArtwork artwork: Int64) {
        if let channel = artworkToChannel[artwork] {
            if channel.referenceCount <= 1 {
                Log.verbose("Removing channel for artwork '\(artwork)'.")
                channel.referenceCount = 0
                artworkToChannel.removeValue(forKey: artwork)
            } else {
                let newReferenceCount = channel.referenceCount - 1
                Log.verbose("Releasing channel for artwork '\(artwork)': \(newReferenceCount).")
                channel.referenceCount = newReferenceCount
            }
        } else {
            Log.warn("No channel to release for artwork '\(artwork)'.")
        }
    }

    private func cacheUsageCount(_ usageCount: Int, forArtwork artwork: Int64) {
        if usageCount <= 0 {
            Log.verbose("Removing usage count cache for artwork '\(artwork)'.")
            artworkToUsageCount.removeValue(forKey: artwork)
        } else {
            Log.warn("Caching usage count for artwork '\(artwork)': \(usageCount).")
            artworkToUsageCount[artwork] = usageCount
        }
    }

    private func fetchUsageCount(forArtwork artwork: Int64) -> Observable<Int> {
        return Observable.deferred {
            if let usageCount = self.artworkToUsageCount[artwork], usageCount > 0 {
                return Observable.just(usageCount)
            } else {
                Log.verbose("Checking usage count for artwork '\(artwork)'.")
                return self.delegate.getUsageCount(forArtwork: artwork).do(onNext: {
                    Log.verbose("Usage count for artwork '\(artwork)': \($0).")
                    self.artworkToUsageCount[artwork] = $0
                })
            }
        }
    }

    private func useOrDownload(artwork: Int64, url: String, usageCount: Int) -> Observable<Int> {
        let newUsageCount = usageCount + 1
        assert(newUsageCount > 0)
        Log.debug("Incremented usage count of '\(artwork)': \(newUsageCount).")
        if newUsageCount == 1 {
            Log.debug("Downloading artwork '\(artwork)...'.")
            return apiService.downloadImage(atUrl: url)
                    .map { image -> (UIImage, URL) in
                        Log.info("Artwork '\(artwork)' has been downloaded.")
                        return (image, self.storageUrlProvider.fileUrl(forArtwork: artwork))
                    }.observeOn(fileOperationScheduler).map {
                        let (image, fileUrl) = $0
                        guard let imageData = UIImagePNGRepresentation(image) else {
                            Log.error("Artwork '\(artwork)' could not be encoded into PNG.")
                            throw PonyError.unexpected
                        }
                        do {
                            try FileUtils.createDirectory(atPath: (fileUrl.path as NSString).deletingLastPathComponent)
                            try imageData.write(to: fileUrl, options: .atomic)
                            Log.info("Artwork '\(artwork)' has been stored to '\(fileUrl)'.")
                        } catch let error {
                            Log.error("Artwork '\(artwork)' could not be written to file: \(error).")
                            throw error
                        }
                        return newUsageCount
                    }.observeOn(MainScheduler.instance)
        } else {
            return Observable.just(newUsageCount)
        }
    }

    private func releaseOrRemove(artwork: Int64, usageCount: Int) -> Observable<Int> {
        let newUsageCount = usageCount - 1
        assert(newUsageCount >= 0)
        Log.debug("Decremented usage count of '\(artwork)': \(newUsageCount).")
        if newUsageCount <= 0 {
            return Observable.just(self.storageUrlProvider.fileUrl(forArtwork: artwork))
                    .observeOn(fileOperationScheduler).map { fileUrl in
                        Log.info("Deleting artwork '\(artwork)'...")
                        do {
                            try FileManager.default.removeItem(atPath: fileUrl.path)
                            Log.info("Artwork '\(artwork)' has been deleted from '\(fileUrl)'.")
                        } catch let error {
                            Log.warn("Could not delete artwork '\(artwork)' file: \(error).")
                        }
                        return newUsageCount
                    }.observeOn(MainScheduler.instance)
        } else {
            return Observable.just(newUsageCount)
        }
    }
}
