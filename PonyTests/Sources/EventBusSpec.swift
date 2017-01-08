//
// Created by Denis Dorokhov on 25/03/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Quick
import Nimble

@testable import Pony

class EventBusSpec: QuickSpec {

    override func spec() {
        TestUtils.describe("EventBus") {
            
            var eventBus: EventBus!
            
            beforeEach {
                eventBus = EventBus()
            }
            
            TestUtils.it("should listen to subscribed events") {
                
                var firedEvent: PayloadEvent<Int>?
                _ = eventBus.listen("test") { (event: PayloadEvent<Int>) in
                    firedEvent = event
                }
                
                eventBus.fire(PayloadEvent("test", 123))
                expect(firedEvent).toNot(beNil())
                expect(firedEvent?.payload).to(equal(123))
            }
            
            TestUtils.it("should not listen to not subscribed events") {
                
                var called = false
                _ = eventBus.listen("test") { _ in
                    called = true
                }
                
                eventBus.fire(Event("test"))
                expect(called).to(beTrue())
            }
            
            TestUtils.it("should unsubscribe") {
                
                var called = false
                let handle = eventBus.listen("test") { _ in
                    called = true
                }
                handle.removeListener()
                
                eventBus.fire(Event("test"))
                expect(called).to(beFalse())
            }
        }
    }

}
