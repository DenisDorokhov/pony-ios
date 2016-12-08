//
// Created by Denis Dorokhov on 01/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift
import Haneke

class HanekeCache<T:DataConvertible>: CacheProvider where T.Result == T, T: DataRepresentable {

    let cache: Haneke.Cache<T>
    let formatName: String

    init(cache: Haneke.Cache<T>, formatName: String) {
        self.cache = cache
        self.formatName = formatName
    }

    func get(forKey key: String) -> Observable<T?> {
        return Observable.create { observer in
            self.cache.fetch(key: key, formatName: self.formatName, failure: {
                error in
                observer.onNext(nil)
                observer.onCompleted()
            }, success: {
                observer.onNext($0)
                observer.onCompleted()
            })
            return Disposables.create()
        }
    }

    func set(object: T, forKey key: String) -> Observable<T> {
        return Observable.create { observer in
            self.cache.set(value: object, key: key, formatName: self.formatName, success: {
                value in
                observer.onNext(object)
                observer.onCompleted()
            })
            return Disposables.create()
        }
    }

    func remove(forKey key: String) -> Observable<Void> {
        return Observable.create { observer in
            self.cache.remove(key: key, formatName: self.formatName)
            observer.onCompleted()
            return Disposables.create()
        }
    }

    func removeAll() -> Observable<Void> {
        return Observable.create { observer in
            self.cache.removeAll {
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }
}
