//
// Created by Denis Dorokhov on 28/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

class RandomUtils {

    static func randomInt(from: Int, to: Int) -> Int {
        return from + Int(arc4random()) % (to - from + 1)
    }

    static func randomDouble(from: Double, to: Double) -> Double {
        return ((to - from) * (Double(arc4random()) / Double(RAND_MAX))) + from
    }

    static func randomBool() -> Bool {
        return randomInt(from: 0, to: 99) > 49
    }

    static func randomArrayElement<T>(array: [T]) -> T? {

        if array.count == 0 {
            return nil
        }

        let index = randomInt(from: 0, to: (array.count - 1))

        return array[index]
    }

    static func boolWithProbability(probability: Int) -> Bool {
        return randomInt(from: 1, to: 100) <= min(probability, 100)
    }

    static func shuffleArray<T>(array: [T]) -> [T] {

        var result: [T] = []
        var copy = array

        while (copy.count > 0) {
            let index: Int = Int(arc4random()) % copy.count
            result.append(copy[index])
            copy.remove(at: index)
        }

        return result
    }

    static func uuid() -> String {
        return NSUUID().uuidString
    }
}
