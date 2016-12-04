//
// Created by Denis Dorokhov on 26/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import Alamofire
import XCGLogger

class ApiSessionManager: SessionManager {

    var debug: Bool

    init(debug: Bool = false) {

        self.debug = debug

        super.init()
    }

    override func request(_ URLRequest: URLRequestConvertible) -> DataRequest {
        let request = super.request(URLRequest)
        if debug {
            Log.debug("ApiSessionManager request:\n\(request.debugDescription)\n")
            let startDate = Date()
            request.response {
                dataResponse in
                let dump = self.dumpResponse(dataResponse.request, dataResponse.response,
                        dataResponse.data, dataResponse.error, startDate)
                Log.debug("ApiSessionManager response:\n\(dump)\n")
            }
        }
        return request
    }

    private func dumpResponse(_ request: URLRequest?, _ response: HTTPURLResponse?,
                              _ data: Data?, _ error: Error?, _ startDate: Date) -> String {

        var output: [String] = []

        output.append(request != nil ? "[Request]: \(request.debugDescription)" : "[Request]: nil")
        output.append(response != nil ? "[Response]: \(response!)" : "[Response]: nil")
        output.append("[Data]: \(data?.count ?? 0) bytes")
        output.append(error != nil ? "[Error]: \(error!)" : "[Error]: nil")

        if let data = data {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
                let pretty = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                if let string = String(data: pretty, encoding: .utf8) {
                    output.append("[JSON]: \(string)")
                }
            } catch {
                if let string = String(data: data, encoding: .utf8) {
                    output.append("[Output]: \(string)")
                } else {
                    output.append("[Output]: \(data)")
                }
            }
        }

        let elapsedTime = Date().timeIntervalSince(startDate)
        output.append("[Time]: \(String(format: "%.04f", elapsedTime))s")

        return output.joined(separator: "\n")
    }
}
