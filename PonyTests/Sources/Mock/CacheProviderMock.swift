//
// Created by Denis Dorokhov on 01/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

@testable import Pony

class CacheProviderMock<T>: CacheProvider {

    var map: [String: T] = [:]

    func get(forKey key: String) -> Observable<T?> {
        return Observable.deferred {
            return Observable.just(self.map[key])
        }
    }

    func set(object: T, forKey key: String) -> Observable<T> {
        return Observable.deferred {
            self.map[key] = object
            return Observable.just(object)
        }
    }

    func remove(forKey key: String) -> Observable<Void> {
        return Observable.deferred {
            self.map.removeValue(forKey: key)
            return Observable.empty()
        }
    }

    func removeAll() -> Observable<Void> {
        return Observable.deferred {
            self.map.removeAll()
            return Observable.empty()
        }
    }
}
