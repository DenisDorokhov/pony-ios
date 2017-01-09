//
// Created by Denis Dorokhov on 09/01/2017.
// Copyright (c) 2017 Denis Dorokhov. All rights reserved.
//

import Foundation
import Swinject
import Haneke

class ServiceAssembly: Assembly {
    
    private let IMAGE_CACHE_NAME = "ServiceAssembly.imageCache"
    private let IMAGE_CACHE_FORMAT = "ServiceAssembly.imageCacheFormat"
    private let IMAGE_CACHE_CAPACITY: UInt64 = 50 * 1024 * 1024

    func assemble(container: Container) {

        container.register(LogConfigurator.self) { r in
#if DISABLE_LOGGING
            return LogConfigurator(level: .none)
#else
            return LogConfigurator(level: .debug)
#endif
        }.inObjectScope(.container)
        
        container.register(ApiUrlDao.self) { r in
            return ApiUrlDaoImpl()
        }.inObjectScope(.container)

        container.register(TokenPairDao.self) { r in
            return TokenPairDaoImpl()
        }.inObjectScope(.container)

        container.register(ApiSessionManager.self) { r in
            return ApiSessionManager(debug: false)
        }.inObjectScope(.container)
        
        container.register(Cache.self, name: "imageCache") { (r: Resolver) -> Cache<UIImage> in
            let format = Format<UIImage>(name: self.IMAGE_CACHE_FORMAT,
                    diskCapacity: self.IMAGE_CACHE_CAPACITY)
            let cache = Haneke.Cache<UIImage>(name: self.IMAGE_CACHE_NAME)
            cache.addFormat(format)
            return Cache(provider: HanekeCache(cache: cache, formatName: self.IMAGE_CACHE_FORMAT))
        }

        container.register(ApiService.self) { (r: Resolver) -> ApiService in
            let service = ApiServiceImpl(sessionManager: r.resolve(ApiSessionManager.self)!, 
                    tokenPairDao: r.resolve(TokenPairDao.self)!, 
                    apiUrlDao: r.resolve(ApiUrlDao.self)!)
            return ApiServiceCached(targetService: ApiServiceQueued(targetService: service), 
                    imageCache: r.resolve(Cache.self, name: "imageCache")!)
        }.inObjectScope(.container)

        container.register(SecurityService.self) { r in
            return SecurityService(apiService: r.resolve(ApiService.self)!, tokenPairDao: r.resolve(TokenPairDao.self)!)
        }.inObjectScope(.container)

        container.register(BootstrapService.self) { r in
            return BootstrapService(apiUrlDao: r.resolve(ApiUrlDao.self)!, securityService: r.resolve(SecurityService.self)!)
        }.inObjectScope(.container)

        container.register(SearchService.self) { r in
            return SearchServiceImpl()
        }.inObjectScope(.container)
        
        container.register(StorageUrlProvider.self) { r in
            return StorageUrlProvider()
        }.inObjectScope(.container)
        
        container.register(SongService.self) { r in
            return SongService(context: SongService.Context(), 
                    storageUrlProvider: r.resolve(StorageUrlProvider.self)!, 
                    searchService: r.resolve(SearchService.self)!)
        }.inObjectScope(.container)
        
        container.register(ArtworkService.self) { r in
            return ArtworkService(artworkUsageCountProvider: r.resolve(SongService.self)!, 
                    apiService: r.resolve(ApiService.self)!, 
                    storageUrlProvider: r.resolve(StorageUrlProvider.self)!)
        }.inObjectScope(.container)
        
        container.register(SongDownloadService.self) { r in
            return SongDownloadService(apiService: r.resolve(ApiService.self)!, 
                    artworkService: r.resolve(ArtworkService.self)!, 
                    songService: r.resolve(SongService.self)!, 
                    storageUrlProvider: r.resolve(StorageUrlProvider.self)!)
        }.inObjectScope(.container)
    }
}
