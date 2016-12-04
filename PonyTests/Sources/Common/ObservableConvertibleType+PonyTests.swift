//
// Created by Denis Dorokhov on 04/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift
import RxBlocking

extension ObservableConvertibleType {
    public func toTestBlocking() -> BlockingObservable<E> {
        return toBlocking(timeout: 5)
    }
}