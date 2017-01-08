//
// Created by Denis Dorokhov on 26/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import RxSwift
import OrderedSet

protocol SongDownloadServiceDelegate: class {
    func songDownloadService(_: SongDownloadService, didStartSongDownload: SongDownloadService.Task)
    func songDownloadService(_: SongDownloadService, didProgressSongDownload: SongDownloadService.Task)
    func songDownloadService(_: SongDownloadService, didCancelSongDownload: Song)
    func songDownloadService(_: SongDownloadService, didFailSongDownload: Song, withError: Error)
    func songDownloadService(_: SongDownloadService, didCompleteSongDownload: Song)
    func songDownloadService(_: SongDownloadService, didDeleteSongDownload: Song)
}

class SongDownloadService {

    class Task: Hashable {

        let song: Song

        var progress: Double {
            do {
                return try progressSubject.value()
            } catch {
                return -1
            }
        }

        var hashValue: Int {
            return song.id.hashValue
        }

        fileprivate let progressSubject: BehaviorSubject<Double>
        fileprivate var downloadedArtworks: [Int64] = []

        fileprivate init(song: Song, progressSubject: BehaviorSubject<Double>) {
            self.song = song
            self.progressSubject = progressSubject
        }

        func asObservable() -> Observable<Double> {
            return progressSubject.asObservable()
        }
    }

    let apiService: ApiService
    let artworkService: ArtworkService
    let songService: SongService
    let storageUrlProvider: StorageUrlProvider

    private var delegates = Delegates<SongDownloadServiceDelegate>()
    
    private var tasks: OrderedSet<SongDownloadService.Task> = []
    private var songToTask: [Int64: SongDownloadService.Task] = [:]
    private var deletingSongs: Set<Int64> = []

    private let fileOperationScheduler = ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global(qos: .default))
    
    private let cancellationSignal: PublishSubject<Int64> = PublishSubject()
    
    private let disposeBag = DisposeBag()

    init(apiService: ApiService, artworkService: ArtworkService, 
         songService: SongService, storageUrlProvider: StorageUrlProvider) {
        
        self.apiService = apiService
        self.artworkService = artworkService
        self.songService = songService
        self.storageUrlProvider = storageUrlProvider
        
        cancellationSignal.addDisposableTo(disposeBag)
    }

    func addDelegate(_ delegate: SongDownloadServiceDelegate) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: SongDownloadServiceDelegate) {
        delegates.remove(delegate)
    }

    func downloadSong(_ song: Song) -> Observable<Double> {
        return Observable.deferred {
            if let _ = self.songToTask[song.id] {
                return Observable.error(PonyError.illegalState(message: "Song is already downloading."))
            }
            if self.deletingSongs.contains(song.id) {
                return Observable.error(PonyError.illegalState(message: "Song is being deleted."))
            }

            let task = Task(song: song, progressSubject: BehaviorSubject(value: 0))

            self.tasks.append(task)
            self.songToTask[song.id] = task
            
            let fileUrl = self.storageUrlProvider.fileUrl(forSong: song.id).path

            let download = self.apiService.downloadSong(atUrl: song.url, toFile: fileUrl).do(onNext: {
                task.progressSubject.onNext($0)
                self.delegates.fetch().forEach { $0.songDownloadService(self, didProgressSongDownload: task) }
            }).takeLast(1).flatMap { (_) -> Observable<Int> in
                self.doUseOrDownloadAlbumArtwork(task)
            }.flatMap { (_) -> Observable<Int> in
                self.doUseOrDownloadArtistArtwork(task)
            }.flatMap { _ in
                self.songService.save(song: song)
            }
            let expectCancellation = self.cancellationSignal.filter { $0 == song.id }.flatMap { (_) -> Observable<Song> in
                throw PonyError.cancelled
            }

            _ = Observable.amb([download, expectCancellation]).subscribe(onNext: { song in
                self.forgetTask(task)
                self.delegates.fetch().forEach { $0.songDownloadService(self, didCompleteSongDownload: song) }
                task.progressSubject.onCompleted()
            }, onError: { error in
                self.cleanTask(task)
                if case PonyError.cancelled = error {} else {
                    Log.error("Could not download song '\(song.id!)': \(error).")
                    self.delegates.fetch().forEach { $0.songDownloadService(self, didFailSongDownload: task.song, withError: error) }
                }
                task.progressSubject.onError(error)
            })

            Log.info("Song '\(song.id!)' download started.")
            self.delegates.fetch().forEach { $0.songDownloadService(self, didStartSongDownload: task) }
            return task.asObservable()
        }
    }

    func cancelSongDownload(_ song: Int64) {
        if let task = songToTask[song] {
            cancellationSignal.onNext(song)
            forgetTask(task)
            delegates.fetch().forEach { $0.songDownloadService(self, didCancelSongDownload: task.song) }
            Log.info("Download cancelled for song '\(task.song.id!)'.")
        } else {
            Log.warn("Could not cancel download of song '\(song)': download is not started.")
        }
    }

    func taskForSong(_ song: Int64) -> SongDownloadService.Task? {
        return songToTask[song]
    }

    func allTasks() -> [SongDownloadService.Task] {
        return Array(tasks)
    }

    func deleteSongDownload(_ song: Int64) -> Observable<Song> {
        return Observable.create { observer in
            if let _ = self.songToTask[song] {
                observer.onError(PonyError.illegalState(message: "Song is downloading."))
            } else {
                self.deletingSongs.insert(song)
                _ = self.songService.delete(song: song).observeOn(self.fileOperationScheduler).map { (song: Song) -> Song in
                    self.deleteSongFile(song.id)
                    return song
                }.observeOn(MainScheduler.instance).flatMap { (song) -> Observable<Song> in
                    var observables: [Observable<Int>] = []
                    if let artwork = song.album.artwork {
                        observables.append(self.artworkService.releaseOrRemove(artwork: artwork))
                    }
                    if let artwork = song.album.artist.artwork {
                        observables.append(self.artworkService.releaseOrRemove(artwork: artwork))
                    }
                    return Observable.from(observables).merge().map { _ in song }
                }.subscribe(onNext: { song in
                    self.deletingSongs.remove(song.id)
                    observer.onNext(song)
                    self.delegates.fetch().forEach { $0.songDownloadService(self, didDeleteSongDownload: song) }
                }, onError: observer.onError, onCompleted: observer.onCompleted)
            }
            return Disposables.create()
        }
    }
    
    private func cleanTask(_ task: Task) {
        deleteSongFile(task.song.id)
        task.downloadedArtworks.forEach { _ = artworkService.releaseOrRemove(artwork: $0).subscribe() }
        forgetTask(task)
    }
    
    private func forgetTask(_ task: Task) {
        tasks.remove(task)
        songToTask.removeValue(forKey: task.song.id)
    }
    
    private func doUseOrDownloadAlbumArtwork(_ task: Task) -> Observable<Int> {
        if let artwork = task.song.album.artwork, let artworkUrl = task.song.album.artworkUrl {
            return self.artworkService.useOrDownload(artwork: artwork, url: artworkUrl).do(onNext: { _ in
                task.downloadedArtworks.append(artwork)
            })
        } else {
            return Observable.just(0)
        }
    }
    
    private func doUseOrDownloadArtistArtwork(_ task: Task) -> Observable<Int> {
        if let artwork = task.song.album.artist.artwork, let artworkUrl = task.song.album.artist.artworkUrl {
            return self.artworkService.useOrDownload(artwork: artwork, url: artworkUrl).do(onNext: { _ in
                task.downloadedArtworks.append(artwork)
            })
        } else {
            return Observable.just(0)
        }
    }
    
    private func deleteSongFile(_ song: Int64) {
        let storageUrl = storageUrlProvider.fileUrl(forSong: song)
        do {
            try FileManager.default.removeItem(at: storageUrl)
        } catch let error {
            Log.warn("Could not delete song '\(song)' file '\(storageUrl.path)': \(error).")
        }
    }
}

func ==(lhs: SongDownloadService.Task, rhs: SongDownloadService.Task) -> Bool {
    return lhs.song.id == rhs.song.id
}
