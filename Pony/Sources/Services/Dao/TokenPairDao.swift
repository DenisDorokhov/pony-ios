//
// Created by Denis Dorokhov on 26/04/16.
// Copyright (c) 2016 Denis Dorokhov. All rights reserved.
//

import Foundation
import ObjectMapper
import KeychainSwift
import XCGLogger

class TokenPair: Mappable {

    private(set) var accessToken: String!
    private(set) var accessTokenExpiration: Date!

    private(set) var refreshToken: String!
    private(set) var refreshTokenExpiration: Date!

    init(accessToken: String, accessTokenExpiration: Date,
         refreshToken: String, refreshTokenExpiration: Date) {
        self.accessToken = accessToken
        self.accessTokenExpiration = accessTokenExpiration
        self.refreshToken = refreshToken
        self.refreshTokenExpiration = refreshTokenExpiration
    }

    convenience init(authentication: Authentication) {
        self.init(accessToken: authentication.accessToken!, accessTokenExpiration: authentication.accessTokenExpiration,
                refreshToken: authentication.refreshToken, refreshTokenExpiration: authentication.refreshTokenExpiration)
    }

    required init?(map: Map) {}

    func mapping(map: Map) {
        accessToken <- map["accessToken"]
        accessTokenExpiration <- (map["accessTokenExpiration"], DateTransform())
        refreshToken <- map["refreshToken"]
        refreshTokenExpiration <- (map["refreshTokenExpiration"], DateTransform())
    }
}

protocol TokenPairDao: class {
    func fetchTokenPair() -> TokenPair?
    func store(tokenPair: TokenPair)
    func removeTokenPair()
}

class TokenPairDaoImpl: TokenPairDao {

    let KEY_TOKEN_PAIR = "TokenDataDao.tokenPair"

    /**
     * When NSUserDefaults value for this key does not exist, no token data will be fetched.
     * This behavior is implemented to avoid token fetching when the application was uninstalled.
     */
    let KEY_HAS_TOKEN = "TokenPairDao.hasToken"

    let keychain = KeychainSwift()

    func fetchTokenPair() -> TokenPair? {

        var tokenPair: TokenPair?

        if let tokenPairJson = keychain.get(KEY_TOKEN_PAIR) {

            tokenPair = TokenPair(JSONString: tokenPairJson)

            if !UserDefaults.standard.bool(forKey: KEY_HAS_TOKEN) {
                Log.debug("It seems like application was uninstalled. Removing the token.")
                removeTokenPair()
                tokenPair = nil
            }
        }

        return tokenPair
    }

    func store(tokenPair: TokenPair) {

        keychain.set(Mapper().toJSONString(tokenPair)!, forKey: KEY_TOKEN_PAIR)

        UserDefaults.standard.set(true, forKey: KEY_HAS_TOKEN)
        UserDefaults.standard.synchronize()

        Log.verbose("Token pair stored.")
    }

    func removeTokenPair() {

        keychain.delete(KEY_TOKEN_PAIR)

        UserDefaults.standard.removeObject(forKey: KEY_HAS_TOKEN)
        UserDefaults.standard.synchronize()

        Log.verbose("Token pair removed.")
    }
}

class TokenPairDaoCached: TokenPairDao {

    let tokenPairDao: TokenPairDao

    var cachedTokenPair: TokenPair?
    var isCachedTokenPairNil: Bool = false

    init(tokenPairDao: TokenPairDao) {
        self.tokenPairDao = tokenPairDao
    }

    func fetchTokenPair() -> TokenPair? {

        if isCachedTokenPairNil {
            return nil
        }
        if cachedTokenPair != nil {
            return cachedTokenPair
        }

        cachedTokenPair = tokenPairDao.fetchTokenPair()
        isCachedTokenPairNil = (cachedTokenPair == nil)

        return cachedTokenPair
    }

    func store(tokenPair: TokenPair) {

        tokenPairDao.store(tokenPair: tokenPair)

        cachedTokenPair = tokenPair
        isCachedTokenPairNil = false
    }

    func removeTokenPair() {

        tokenPairDao.removeTokenPair()

        cachedTokenPair = nil
        isCachedTokenPairNil = true
    }
}
