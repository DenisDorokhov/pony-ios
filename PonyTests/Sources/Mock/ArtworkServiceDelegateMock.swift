//
// Created by Denis Dorokhov on 05/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

@testable import Pony

class ArtworkServiceDelegateMock: ArtworkServiceDelegate {

    let folderPath: String
    
    var artworkToUsageCount: [Int64:Int] = [:]

    init() {
        folderPath = try! FileUtils.createTemporaryDirectory()
    }

    func getUsageCount(forArtwork artwork: Int64) -> Observable<Int> {
        return Observable.just(artworkToUsageCount[artwork]!)
    }

    func getFilePath(forArtwork artwork: Int64) -> String {
        return (folderPath as NSString).appendingPathComponent("\(artwork).png")
    }
}
