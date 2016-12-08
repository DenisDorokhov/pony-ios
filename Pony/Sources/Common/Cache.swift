//
// Created by Denis Dorokhov on 01/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

protocol CacheProvider: class {

    associatedtype ItemType

    func get(forKey: String) -> Observable<ItemType?>
    func set(object: ItemType, forKey: String) -> Observable<ItemType>

    func remove(forKey: String) -> Observable<Void>
    func removeAll() -> Observable<Void>
}

class Cache<T>: CacheProvider {

    private let doGet: (String) -> Observable<T?>
    private let doSet: (T, String) -> Observable<T>
    private let doRemove: (String) -> Observable<Void>
    private let doRemoveAll: () -> Observable<Void>

    init<P:CacheProvider>(provider: P) where P.ItemType == T {
        doGet = provider.get
        doSet = provider.set
        doRemove = provider.remove
        doRemoveAll = provider.removeAll
    }

    func get(forKey key: String) -> Observable<T?> {
        return doGet(key).do(onNext: {
            if $0 != nil {
                Log.verbose("Cache HIT for key '\(key)'.")
            } else {
                Log.verbose("Cache MISS for key '\(key)'.")
            }
        })
    }

    func set(object: T, forKey key: String) -> Observable<T> {
        return doSet(object, key).do(onCompleted: {
            Log.verbose("Value CACHED for key '\(key)'.")
        })
    }

    func remove(forKey key: String) -> Observable<Void> {
        return doRemove(key).do(onCompleted: {
            Log.verbose("Value REMOVED for key '\(key)'.")
        })
    }

    func removeAll() -> Observable<Void> {
        return doRemoveAll().do(onCompleted: {
            Log.debug("Cache CLEARED.")
        })
    }
}
