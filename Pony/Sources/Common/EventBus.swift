//
// Created by Denis Dorokhov on 25/03/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

class Event: NSObject {

    let type: String

    init(_ type: String) {
        self.type = type
    }
}

class PayloadEvent<T>: Event {

    let payload: T

    init(_ type: String, _ payload: T) {

        self.payload = payload

        super.init(type)
    }
}

class EventHandle {

    private let executeOnRemoval: () -> Void
    private(set) var removed: Bool = false

    fileprivate init(executeOnRemoval: @escaping () -> Void) {
        self.executeOnRemoval = executeOnRemoval
    }

    func removeListener() {
        if !removed {
            executeOnRemoval()
            removed = true
        }
    }
}

class EventBus {

    static let instance = EventBus()

    private var typeToListeners: [String: NSMutableOrderedSet] = [:]

    func listen<T:Event>(_ eventType: String, execute: @escaping (T) -> Void) -> EventHandle {

        let entry = ListenerEntry(eventType) {
            event in
            execute(event as! T)
        }

        var listeners = typeToListeners[eventType]
        if listeners == nil {
            listeners = NSMutableOrderedSet()
            typeToListeners[eventType] = listeners
        }
        listeners!.add(entry)

        return EventHandle() {
            listeners!.remove(entry)
        }
    }

    func fire(_ event: Event) {
        if let listeners = typeToListeners[event.type] {
            for listener in listeners {
                (listener as! ListenerEntry).execute(event)
            }
        }
    }

    static func listen<T:Event>(_ eventType: String, execute: @escaping (T) -> Void) -> EventHandle {
        return instance.listen(eventType, execute: execute)
    }

    static func fire(_ event: Event) {
        instance.fire(event)
    }

    private class ListenerEntry {

        let type: String
        let execute: (Event) -> Void

        init(_ type: String, execute: @escaping (Event) -> Void) {
            self.type = type
            self.execute = execute
        }
    }

}
