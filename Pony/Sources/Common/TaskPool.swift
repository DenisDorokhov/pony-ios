//
// Created by Denis Dorokhov on 16/05/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import RxSwift

class TaskPool<T>: Disposable {

    let maxConcurrent: Int
    let runningTasks: Variable<Int>
    
    private var subject: PublishSubject<Observable<Void>>?
    private var disposable: Disposable?
    
    convenience init() {
        self.init(maxConcurrent: 1)
    }
    
    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
        self.runningTasks = Variable(0)
    }
    
    func add(_ observable: Observable<T>) -> Observable<T> {
        return Observable.create { observer in
            let disposeSignal = ReplaySubject<Void>.createUnbounded()
            self.lazySubject().onNext(observable
                    .do(onNext: {
                        observer.onNext($0)
                    }, onError: {
                        observer.onError($0)
                    }, onCompleted: {
                        self.runningTasks.value -= 1
                        observer.onCompleted()
                    }, onSubscribe: {
                        self.runningTasks.value += 1
                    }).map { _ in }.catchErrorJustReturn().takeUntil(disposeSignal))
            return Disposables.create {
                disposeSignal.onNext()
                disposeSignal.onCompleted()
            }
        }
    }

    func dispose() {
        disposable?.dispose()
        subject?.dispose()
        disposable = nil
        subject = nil
    }
    
    private func lazySubject() -> PublishSubject<Observable<Void>> {
        if let subject = subject {
            return subject
        }
        let createdSubject = PublishSubject<Observable<Void>>()
        subject = createdSubject
        disposable = createdSubject.merge(maxConcurrent: maxConcurrent).subscribe()
        return createdSubject
    }
}
