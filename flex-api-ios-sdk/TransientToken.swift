//
//  TransientToken.swift
//  flex_api_ios_sdk
//
//  Created by Rakesh Ramamurthy on 11/04/21.
//

import Foundation

@objc public class TransientToken: NSObject {
    public static func == (lhs: TransientToken, rhs: TransientToken) -> Bool {
        lhs.token == rhs.token
    }
    
    @objc public let token: String

    init(token: String) {
        self.token = token
    }
}
