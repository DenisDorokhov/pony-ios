//
// Created by Denis Dorokhov on 08/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

class StorageUrlProvider {

    let artworkDownloadFolder: String
    let songDownloadFolder: String
    
    convenience init() {
        self.init(artworkDownloadFolder: "Artwork", songDownloadFolder: "Songs")
    }
    
    init(artworkDownloadFolder: String, songDownloadFolder: String) {
        self.artworkDownloadFolder = artworkDownloadFolder
        self.songDownloadFolder = songDownloadFolder
    }

    func fileUrl(forArtwork artwork: Int64) -> URL {
        let path = NSString(string: artworkDownloadFolder).appendingPathComponent(String(artwork))
        return URL(fileURLWithPath: FileUtils.pathInDocuments(path))
    }
    
    func fileUrl(forSong song: Int64) -> URL {
        let path = NSString(string: songDownloadFolder).appendingPathComponent(String(song))
        return URL(fileURLWithPath: FileUtils.pathInDocuments(path))
    }
}
