//
// Created by Denis Dorokhov on 06/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

enum PonyError: Error, CustomStringConvertible {

    case offline
    case timeout
    case cancelled
    case unexpected
    case response(errors: [ResponseError])

    func fetchResponseError(byCode codes: [String]) -> ResponseError? {
        return fetchResponseErrors(byCodes: codes).first
    }

    func fetchResponseErrors(byCodes codes: [String]) -> [ResponseError] {
        var result: [ResponseError] = []
        if case let .response(errors) = self {
            for error in errors {
                for code in codes {
                    if error.code == code || error.code.hasPrefix("\(code).") {
                        result.append(error)
                    }
                }
            }
        }
        return result
    }

    var description: String {
        get {
            switch self {
            case .offline:
                return "ApiError.offline"
            case .timeout:
                return "ApiError.timeout"
            case .cancelled:
                return "ApiError.cancelled"
            case .unexpected:
                return "ApiError.unexpected"
            case .response(let errors):
                return "ApiError.response{errors=\(errors)}"
            }
        }
    }
}
