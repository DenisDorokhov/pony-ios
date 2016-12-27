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
            return progressVariable.value
        }

        var hashValue: Int {
            return song.id.hashValue
        }

        fileprivate let progressVariable: Variable<Double>
        fileprivate var downloadedArtworks: [Int64] = []

        fileprivate init(song: Song, progressVariable: Variable<Double>) {
            self.song = song
            self.progressVariable = progressVariable
        }

        func asObservable() -> Observable<Double> {
            return progressVariable.asObservable()
        }
    }

    let apiService: ApiService
    let artworkService: ArtworkService
    let songService: SongService
    let storageUrlProvider: StorageUrlProvider

    private var delegates = Delegates<SongDownloadServiceDelegate>()
    
    private var tasks: OrderedSet<SongDownloadService.Task> = []
    private var songToTask: [Int64: SongDownloadService.Task] = [:]
    
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

    func downloadSong(_ song: Song) -> SongDownloadService.Task {
        if let task = songToTask[song.id] {
            Log.warn("Song '\(song.id!)' is already downloading.")
            return task
        }
        
        let task = Task(song: song, progressVariable: Variable(0))

        tasks.append(task)
        songToTask[song.id] = task
        
        let download = apiService.downloadSong(atUrl: song.url, toFile: storageUrlProvider.fileUrl(forSong: song.id).path).do(onNext: {
            task.progressVariable.value = $0
            self.delegates.fetch().forEach { $0.songDownloadService(self, didProgressSongDownload: task) }
        }).takeLast(1).flatMap { (_) -> Observable<Int> in
            self.doUseOrDownloadAlbumArtwork(task)
        }.flatMap { (_) -> Observable<Int> in
            self.doUseOrDownloadArtistArtwork(task)
        }.flatMap { _ in
            self.songService.save(song: song)
        }
        let expectCancellation = cancellationSignal.filter { $0 == song.id }.flatMap { (_) -> Observable<Song> in
            throw PonyError.cancelled
        }
        
        _ = Observable.amb([download, expectCancellation]).subscribe(onError: { error in
            self.cleanTask(task)
            if case PonyError.cancelled = error {} else {
                Log.error("Could not download song '\(song.id!)': \(error).")
                self.delegates.fetch().forEach { $0.songDownloadService(self, didFailSongDownload: task.song, withError: error) }
            }
        }, onCompleted: {
            self.forgetTask(task)
            self.delegates.fetch().forEach { $0.songDownloadService(self, didCompleteSongDownload: task.song) }
        })

        Log.info("Song '\(song.id!)' download started.")
        delegates.fetch().forEach { $0.songDownloadService(self, didStartSongDownload: task) }
        return task
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
        return songService.delete(song: song).do(onNext: { song in
            self.deleteSongFile(song.id)
            if let artwork = song.album.artwork {
                _ = self.artworkService.releaseOrRemove(artwork: artwork).subscribe()
            }
            if let artwork = song.album.artist.artwork {
                _ = self.artworkService.releaseOrRemove(artwork: artwork).subscribe()
            }
            self.delegates.fetch().forEach { $0.songDownloadService(self, didDeleteSongDownload: song) }
        })
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
