//
// Created by Denis Dorokhov on 06/12/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation

enum PonyError: Error, CustomStringConvertible {

    case unexpected
    case offline
    case timeout
    case cancelled
    case notFound
    case notAuthenticated
    case alreadyAuthenticated
    case response(errors: [ResponseError])

    func fetchResponseError(byCodeIn codes: String...) -> ResponseError? {
        return doFetchResponseErrors(byCodeIn: codes).first
    }

    func fetchResponseErrors(byCodeIn codes: String...) -> [ResponseError] {
        return doFetchResponseErrors(byCodeIn: codes)
    }
    
    private func doFetchResponseErrors(byCodeIn codes: [String]) -> [ResponseError] {
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
            case .unexpected:
                return "PonyError.unexpected"
            case .offline:
                return "PonyError.offline"
            case .timeout:
                return "PonyError.timeout"
            case .cancelled:
                return "PonyError.cancelled"
            case .notFound:
                return "PonyError.notFound"
            case .notAuthenticated:
                return "PonyError.notAuthenticated"
            case .alreadyAuthenticated:
                return "PonyError.alreadyAuthenticated"
            case .response(let errors):
                return "PonyError.response{errors=\(errors)}"
            }
        }
    }
}
