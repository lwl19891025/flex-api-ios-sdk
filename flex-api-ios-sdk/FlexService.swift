//
//  FlexServiceImpl.swift
//  flex_api_ios_sdk
//
//  Created by Rakesh Ramamurthy on 11/04/21.
//

import Foundation

@objc public class FlexService: NSObject, FlexServiceProtocol {
    
    private var captureContext: CaptureContext?
    private var tokenGenerator: FlexTokensGenerator
        
    static func standardClient() -> FlexServiceProtocol {
        let httpClient = URLSessionHTTPClient()
        let tokenGenerator = RemoteFlexTokensGenerator(client: httpClient)
        return FlexService(tokenGenerator: tokenGenerator)
    }
    
    public typealias Result = Swift.Result<TransientToken, FlexErrorResponse>

    public enum Error: Swift.Error {
        case invalidCaptureContext
        case invalidData
        case connectivity
    }
    
    public override init() {
        let httpClient = URLSessionHTTPClient()
        self.tokenGenerator = RemoteFlexTokensGenerator(client: httpClient)
    }
    
    init(tokenGenerator: RemoteFlexTokensGenerator) {
        self.tokenGenerator = tokenGenerator
    }
    
    init(captureContext: CaptureContext, tokenGenerator: FlexTokensGenerator) {
        self.captureContext = captureContext
        self.tokenGenerator = tokenGenerator
    }
        
    public func flexPublicKey(kid: String) -> SecKey? {
        return LongTermKey.sharedInstance.get(kid: kid)
    }

    @objc public func createTransientToken(
        from captureContext: String,
        data: [String: Any],
        completion: @escaping (_ success: Bool, _ token: TransientToken?, _ error: FlexErrorResponse?) -> Void
    ) {
        if captureContext.isEmpty {
            completion(false, nil, FlexInternalErrors.emptyCaptureContext.errorResponse)
            return
        } else if data.isEmpty {
            completion(false, nil, FlexInternalErrors.emptyCardData.errorResponse)
            return
        }
        do {
            try self.captureContext = CaptureContextImpl(from: captureContext)
        } catch let error as FlexErrorResponse {
            completion(false, nil, error)
            return
        } catch {
            completion(false, nil, FlexInternalErrors.unknownError.errorResponse)
            return
        }

        do {
            try createToken(data: data) { success, token, error in
                completion(success, token, error)
            }
        } catch let error as FlexErrorResponse {
            completion(false, nil, error)
        } catch {
            completion(false, nil, FlexInternalErrors.unknownError.errorResponse)
        }
    }
    
    func createToken(
        data: [String: Any],
        completion: @escaping (_ success: Bool, _ token: TransientToken?, _ error: FlexErrorResponse?) -> Void
    ) throws {
        guard let kid = self.captureContext?.getJsonWebKey()?.kid else {
            completion(false, nil, FlexInternalErrors.missingKid.errorResponse)
            return
        }

        var jweString: String?
        do {
            jweString = try self.captureContext?.jwe(kid: kid, data: data)
        } catch let error as FlexErrorResponse {
            throw error
        }

        guard let jwe = jweString else {
            completion(false, nil, FlexInternalErrors.jweCreationError.errorResponse)
            return
        }

        guard let path = self.captureContext?.getTokensPath() else {
            completion(false, nil, FlexInternalErrors.invalidFlexServicePath.errorResponse)
            return
        }

        guard let origin = self.captureContext?.getFlexOrigin() else {
            completion(false, nil, FlexInternalErrors.invalidFlexServiceOrigin.errorResponse)
            return
        }

        guard let url = URL(string: origin + path) else {
            completion(false, nil, FlexInternalErrors.invalidFlexServiceURL.errorResponse)
            return
        }

        let requestObj = FlexRequest(keyId: jwe)
        var requestData = Data()

        do {
            requestData = try JSONEncoder().encode(requestObj)
        } catch {
            completion(false, nil, FlexInternalErrors.requestObjectDecodingError.errorResponse)
            return
        }

        self.tokenGenerator.generateTransientToken(url: url, payload: requestData) { result in
            switch result {
            case let .success(response):
                if response.isValidResponse() {
                    do {
                        try DigestHelper.verifyResponseDigest(response: response)
                    } catch {
                        completion(false, nil, error as? FlexErrorResponse ?? FlexInternalErrors.unknownError.errorResponse)
                        return
                    }

                    if let responseToken = response.body {
                        completion(true, TransientToken(token: responseToken), nil)
                    } else {
                        completion(false, nil, Tools.handleErrorResponse(response: response, startTime: 1))
                    }
                } else {
                    completion(false, nil, Tools.handleErrorResponse(response: response, startTime: 1))
                }

            case let .failure(error):
                completion(false, nil, Tools.createErrorObjectFrom(
                    status: 4000,
                    reason: "Connectivity error",
                    message: error.localizedDescription
                ))
            }
        }
    }

}
