//
// Created by Denis Dorokhov on 27/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

@testable import Pony

class SongDownloadServiceDelegateMock: SongDownloadServiceDelegate {
    
    var didStartSongDownload: SongDownloadService.Task?
    var didProgressSongDownload: SongDownloadService.Task?
    var didCancelSongDownload: Song?
    var didFailSongDownload: (Song, Error)?
    var didCompleteSongDownload: Song?
    var didDeleteSongDownload: Song?

    func songDownloadService(_: SongDownloadService, didStartSongDownload task: SongDownloadService.Task) {
        didStartSongDownload = task
    }

    func songDownloadService(_: SongDownloadService, didProgressSongDownload task: SongDownloadService.Task) {
        didProgressSongDownload = task
    }

    func songDownloadService(_: SongDownloadService, didCancelSongDownload song: Song) {
        didCancelSongDownload = song
    }

    func songDownloadService(_: SongDownloadService, didFailSongDownload song: Song, withError error: Error) {
        didFailSongDownload = (song, error)
    }

    func songDownloadService(_: SongDownloadService, didCompleteSongDownload song: Song) {
        didCompleteSongDownload = song
    }

    func songDownloadService(_: SongDownloadService, didDeleteSongDownload song: Song) {
        didDeleteSongDownload = song
    }

}
