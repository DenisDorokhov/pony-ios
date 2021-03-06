//
// Created by Denis Dorokhov on 01/11/2016.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Alamofire
import AlamofireImage
import AlamofireObjectMapper
import ObjectMapper
import RxSwift

protocol ApiService: class {

    func getInstallation() -> Observable<Installation>

    func authenticate(credentials: Credentials) -> Observable<Authentication>

    func logout() -> Observable<User>

    func getCurrentUser() -> Observable<User>

    func refreshToken() -> Observable<Authentication>

    func getArtists() -> Observable<[Artist]>

    func getArtistAlbums(artistId: Int64) -> Observable<ArtistAlbums>

    func downloadImage(atUrl: String) -> Observable<UIImage>

    func downloadSong(atUrl: String, toFile: String) -> Observable<Double>
}

fileprivate protocol ApiResponse {
    associatedtype DataType

    var version: String! { get set }
    var successful: Bool! { get set }

    var data: DataType? { get set }
    var errors: [ResponseError]! { get set }
}

extension ObjectResponse: ApiResponse {
}

extension ArrayResponse: ApiResponse {
}

class ApiServiceImpl: ApiService {

    private let HEADER_ACCESS_TOKEN = "X-Pony-Access-Token"
    private let HEADER_REFRESH_TOKEN = "X-Pony-Refresh-Token"

    let sessionManager: SessionManager
    let tokenPairDao: TokenPairDao
    let apiUrlDao: ApiUrlDao

    init(sessionManager: SessionManager, tokenPairDao: TokenPairDao, apiUrlDao: ApiUrlDao) {
        self.sessionManager = sessionManager
        self.tokenPairDao = tokenPairDao
        self.apiUrlDao = apiUrlDao
        DataRequest.addAcceptableImageContentTypes(["image/jpg"])
    }

    func getInstallation() -> Observable<Installation> {
        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.request(self.buildUrl("/api/installation"), method: .get).responseObject {
                (response: DataResponse<ObjectResponse<Installation>>) in
                self.handleResponse(response, observer)
            })
        }
    }

    func authenticate(credentials: Credentials) -> Observable<Authentication> {
        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.request(self.buildUrl("/api/authenticate"), method: .post,
                    parameters: Mapper().toJSON(credentials), encoding: JSONEncoding.prettyPrinted).responseObject {
                (response: DataResponse<ObjectResponse<Authentication>>) in
                self.handleResponse(response, observer)
            })
        }
    }

    func logout() -> Observable<User> {
        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.request(self.buildUrl("/api/logout"), method: .post,
                    headers: self.buildAuthorizationHeaders()).responseObject {
                (response: DataResponse<ObjectResponse<User>>) in
                self.handleResponse(response, observer)
            })
        }
    }

    func getCurrentUser() -> Observable<User> {
        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.request(self.buildUrl("/api/currentUser"), method: .get,
                    headers: self.buildAuthorizationHeaders()).responseObject {
                (response: DataResponse<ObjectResponse<User>>) in
                self.handleResponse(response, observer)
            })
        }
    }

    func refreshToken() -> Observable<Authentication> {

        var headers = [String: String]()
        if let tokenPair = tokenPairDao.fetchTokenPair() {
            headers[HEADER_REFRESH_TOKEN] = tokenPair.refreshToken
        }

        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.request(self.buildUrl("/api/refreshToken"), method: .post,
                    headers: headers).responseObject {
                (response: DataResponse<ObjectResponse<Authentication>>) in
                self.handleResponse(response, observer)
            })
        }
    }

    func getArtists() -> Observable<[Artist]> {
        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.request(self.buildUrl("/api/artists"), method: .get,
                    headers: self.buildAuthorizationHeaders()).responseObject {
                (response: DataResponse<ArrayResponse<Artist>>) in
                self.handleResponse(response, observer)
            })
        }
    }

    func getArtistAlbums(artistId: Int64) -> Observable<ArtistAlbums> {
        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.request(self.buildUrl("/api/artistAlbums/\(artistId)"), method: .get,
                    headers: self.buildAuthorizationHeaders()).responseObject {
                (response: DataResponse<ObjectResponse<ArtistAlbums>>) in
                self.handleResponse(response, observer)
            })
        }
    }

    func downloadImage(atUrl url: String) -> Observable<UIImage> {
        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.request(url, method: .get,
                    headers: self.buildAuthorizationHeaders()).responseImage {
                response in
                if response.result.isSuccess {
                    observer.onNext(response.result.value!)
                    observer.onCompleted()
                } else {
                    let error = self.buildError(response.result.error!)
                    switch error {
                    case .cancelled:
                        Log.debug("Image request cancelled.")
                    default:
                        Log.error("Image request error: \(response.result.error!).")
                    }
                    observer.onError(error)
                }
            })
        }
    }

    func downloadSong(atUrl url: String, toFile filePath: String) -> Observable<Double> {
        return Observable.create { observer in
            self.buildDisposable(self.sessionManager.download(url, method: .get, headers: self.buildAuthorizationHeaders(), to: {
                _, _ in
                return (URL(fileURLWithPath: filePath), [.removePreviousFile, .createIntermediateDirectories])
            }).downloadProgress {
                observer.onNext($0.fractionCompleted)
            }.response {
                response in
                if let responseError = response.error {
                    let error = self.buildError(responseError)
                    switch error {
                    case .cancelled:
                        Log.debug("Song request cancelled.")
                    default:
                        Log.error("Song request error: \(responseError).")
                    }
                    observer.onError(error)
                } else {
                    observer.onCompleted()
                }
            })
        }
    }

    private func buildUrl(_ path: String) -> URL {
        return apiUrlDao.fetchUrl()!.appendingPathComponent(path)
    }

    private func buildAuthorizationHeaders() -> [String: String] {
        var headers = [String: String]()
        if let tokenPair = tokenPairDao.fetchTokenPair() {
            headers[HEADER_ACCESS_TOKEN] = tokenPair.accessToken
        }
        return headers
    }

    private func buildError(_ error: Error) -> PonyError {
        var result = PonyError.unexpected
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            if nsError.code == NSURLErrorNotConnectedToInternet {
                result = PonyError.offline
            } else if nsError.code == NSURLErrorTimedOut {
                result = PonyError.timeout
            } else if nsError.code == NSURLErrorCancelled {
                result = PonyError.cancelled
            }
        }
        return result
    }

    private func buildDisposable(_ request: Request) -> Disposable {
        return Disposables.create {
            if request.task?.state != .completed {
                Log.debug("Canceling request: \(request.debugDescription)")
                request.cancel()
            }
        }
    }

    private func handleResponse<T:ApiResponse>(_ response: DataResponse<T>,
                                               _ observer: AnyObserver<T.DataType>) {
        if response.result.isSuccess {
            let responseValue = response.result.value!
            if responseValue.successful ?? false {
                if let data = responseValue.data {
                    observer.onNext(data)
                    observer.onCompleted()
                } else {
                    Log.error("API returned nil data object.")
                    observer.onError(PonyError.unexpected)
                }
            } else {
                let error = PonyError.response(errors: responseValue.errors)
                Log.error("API response error: \(error)")
                observer.onError(error)
            }
        } else {
            let error = buildError(response.result.error!)
            switch error {
            case .cancelled:
                Log.debug("API request cancelled.")
            default:
                Log.error("API request error: \(response.result.error!).")
            }
            observer.onError(error)
        }
    }
}
