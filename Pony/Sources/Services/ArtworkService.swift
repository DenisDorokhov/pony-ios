//
// Created by Denis Dorokhov on 06/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

protocol ArtworkService: class {
    func useOrDownload(artwork: Int64, url: String) -> Observable<Int>
    func releaseOrRemove(artwork: Int64) -> Observable<Int>
}

protocol ArtworkUsageCountProvider: class {
    func getUsageCount(forArtwork: Int64) -> Observable<Int>
}

class ArtworkServiceImpl: ArtworkService {

    private class DownloadQueue {

        let artwork: Int64

        let queue = TaskPool(maxConcurrent: 1)

        var referenceCount: Int = 0 {
            didSet {
                if referenceCount <= 0 {
                    queue.dispose()
                }
            }
        }

        private var disposable: Disposable?

        init(_ artwork: Int64) {
            self.artwork = artwork
        }

        deinit {
            queue.dispose()
        }
    }

    let artworkUsageCountProvider: ArtworkUsageCountProvider
    let apiService: ApiService
    let storageUrlProvider: StorageUrlProvider

    private var artworkToUsageCount: [Int64: Int] = [:]
    private var artworkToQueue: [Int64: DownloadQueue] = [:]

    private var fileOperationScheduler = ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global(qos: .default))

    init(artworkUsageCountProvider: ArtworkUsageCountProvider, apiService: ApiService, storageUrlProvider: StorageUrlProvider) {
        self.artworkUsageCountProvider = artworkUsageCountProvider
        self.apiService = apiService
        self.storageUrlProvider = storageUrlProvider
    }

    func useOrDownload(artwork: Int64, url: String) -> Observable<Int> {
        return Observable.deferred {
            self.retainQueue(forArtwork: artwork).add(self.fetchUsageCount(forArtwork: artwork).flatMap {
                        self.useOrDownload(artwork: artwork, url: url, usageCount: $0)
                    }).do(onNext: {
                        self.cacheUsageCount($0, forArtwork: artwork)
                    }, onDispose: {
                        self.releaseQueue(forArtwork: artwork)
                    })
        }
    }

    func releaseOrRemove(artwork: Int64) -> Observable<Int> {
        return Observable.deferred {
            self.retainQueue(forArtwork: artwork).add(self.fetchUsageCount(forArtwork: artwork).flatMap {
                        self.releaseOrRemove(artwork: artwork, usageCount: $0)
                    }).do(onNext: {
                        self.cacheUsageCount($0, forArtwork: artwork)
                    }, onDispose: {
                        self.releaseQueue(forArtwork: artwork)
                    })
        }
    }

    private func retainQueue(forArtwork artwork: Int64) -> TaskPool {
        if let queue = artworkToQueue[artwork] {
            let newReferenceCount = queue.referenceCount + 1
            Log.verbose("Retaining queue for artwork '\(artwork)': \(newReferenceCount).")
            queue.referenceCount = newReferenceCount
            return queue.queue
        } else {
            Log.verbose("Creating queue for artwork '\(artwork)'.")
            let queue = DownloadQueue(artwork)
            queue.referenceCount = 1
            artworkToQueue[artwork] = queue
            return queue.queue
        }
    }

    private func releaseQueue(forArtwork artwork: Int64) {
        if let queue = artworkToQueue[artwork] {
            if queue.referenceCount <= 1 {
                Log.verbose("Removing queue for artwork '\(artwork)'.")
                queue.referenceCount = 0
                artworkToQueue.removeValue(forKey: artwork)
            } else {
                let newReferenceCount = queue.referenceCount - 1
                Log.verbose("Releasing queue for artwork '\(artwork)': \(newReferenceCount).")
                queue.referenceCount = newReferenceCount
            }
        } else {
            Log.warn("No queue to release for artwork '\(artwork)'.")
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
                return self.artworkUsageCountProvider.getUsageCount(forArtwork: artwork).do(onNext: {
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
            return apiService.downloadImage(atUrl: url).do(onError: {
                        Log.error("Could not download artwork '\(artwork)': \($0).")
                    })
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
