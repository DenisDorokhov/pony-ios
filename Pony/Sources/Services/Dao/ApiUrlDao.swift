//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import XCGLogger

protocol ApiUrlDao: class {
    func fetchUrl() -> URL?
    func store(url: URL)
    func removeUrl()
}

class ApiUrlDaoImpl: ApiUrlDao {

    let KEY_URL = "ApiUrlDaoImpl.url"

    func fetchUrl() -> URL? {

        let url = UserDefaults.standard.string(forKey: KEY_URL)

        return url != nil ? URL(string: url!) : nil
    }

    func store(url: URL) {

        UserDefaults.standard.set(url.absoluteString, forKey: KEY_URL)
        UserDefaults.standard.synchronize()

        Log.debug("URL stored: \(url).")
    }

    func removeUrl() {

        UserDefaults.standard.removeObject(forKey: KEY_URL)
        UserDefaults.standard.synchronize()

        Log.debug("URL removed.")
    }
}
