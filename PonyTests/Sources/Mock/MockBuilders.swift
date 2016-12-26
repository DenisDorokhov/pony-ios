//
// Created by Denis Dorokhov on 26/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

@testable import Pony

class MockBuilders {
    static func buildSongMock(suffix: String = "15_3_3") -> Song {
        let bundle = Bundle(for: MockBuilders.self)
        let json = try! String(contentsOfFile: bundle.path(forResource: "song-\(suffix)", ofType: "json")!)
        return Song(JSONString: json)!
    }
}
