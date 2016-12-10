//
// Created by Denis Dorokhov on 05/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

@testable import Pony

class ArtworkServiceDelegateMock: ArtworkServiceDelegate {

    var artworkToUsageCount: [Int64:Int] = [:]

    func getUsageCount(forArtwork artwork: Int64) -> Observable<Int> {
        return Observable.just(artworkToUsageCount[artwork]!)
    }
}
