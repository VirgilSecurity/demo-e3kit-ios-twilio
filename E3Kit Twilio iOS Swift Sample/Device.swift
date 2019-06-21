//
//  Device.swift
//  E3Kit iOS Swift Sample
//
//  Created by Matheus Cardoso on 4/18/19.
//  Developer Relations Engineer @ Virgil Security
//

//# start of snippet: e3kit_imports
import VirgilE3Kit
import VirgilCrypto
//# end of snippet: e3kit_imports

typealias Completion = () -> Void
typealias FailableCompletion = (Error?) -> Void
typealias ResultCompletion<T> = (Result<T, Error>) -> Void

class Device<MessagingClient>: NSObject where MessagingClient: Messaging {
    let identity: String
    var eThree: EThree!
    var authToken: String!

    var messagingClient: MessagingClient!

    init(withIdentity identity: String) {
        self.identity = identity
    }

    // First step in e3kit flow is to initialize the SDK (eThree instance)
    func initialize(_ completion: FailableCompletion? = nil) {
        let identity = self.identity

        //# start of snippet: e3kit_authenticate
        func authenticate(_ identity: String, _ completion: @escaping (String?) -> Void) {
            let url = URL(string: "http://localhost:3000/authenticate")!
            let params = ["identity": identity]

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try! JSONSerialization.data(withJSONObject: params, options: [])
            request.httpMethod = "POST"
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data else {
                    completion(nil)
                    return
                }

                let json = try? JSONDecoder().decode([String: String].self, from: data)
                completion(json?["authToken"])
            }.resume()
        }
        //# end of snippet: e3kit_authenticate

        //# start of snippet: e3kit_jwt_callback
        let tokenCallback: EThree.RenewJwtCallback = { completion in
            authenticate(identity) { authToken in
                guard let authToken = authToken else {
                    completion(nil, nil)
                    return
                }

                self.authToken = authToken


                let url = URL(string: "http://localhost:3000/virgil-jwt")!
                var request = URLRequest(url: url)
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let data = data else {
                        completion(nil, error)
                        return
                    }

                    let json = try? JSONDecoder().decode([String: String].self, from: data)
                    completion(json?["virgilToken"], error)
                }.resume()
            }
        }
        //# end of snippet: e3kit_jwt_callback

        //# start of snippet: e3kit_initialize
        EThree.initialize(tokenCallback: tokenCallback) { eThree, error in
            self.eThree = eThree
            completion?(error)
        }
        //# end of snippet: e3kit_initialize
    }

    func initializeClient(withUserData userData: MessagingClient.UserData, completion: FailableCompletion? = nil) {
        messagingClient = MessagingClient()
        messagingClient.initialize(withUserData: userData) { error in
            completion?(error)
        }
    }

    func register(_ completion: FailableCompletion? = nil) {
        //# start of snippet: e3kit_has_local_private_key
        if try! eThree.hasLocalPrivateKey() {
            try! eThree.cleanUp()
        }
        //# end of snippet: e3kit_has_local_private_key

        //# start of snippet: e3kit_register
        eThree.register { error in
            if error as? EThreeError == .userIsAlreadyRegistered {
                self.eThree.rotatePrivateKey { error in
                    completion?(error)
                }

                return
            }

            completion?(error)
        }
        //# end of snippet: e3kit_register
    }

    func lookupPublicKeys(of identities: [String], completion: ResultCompletion<EThree.LookupResult>?) {
        //# start of snippet: e3kit_lookup_public_keys
        eThree.lookupPublicKeys(of: identities) { result, error in
            if let result = result {
                completion?(.success(result))
            } else if let error = error {
                completion?(.failure(error))
            }
        }
        //# end of snippet: e3kit_lookup_public_keys
    }

    func encrypt(text: String, for lookupResult: EThree.LookupResult? = nil) throws -> String {
        //# start of snippet: e3kit_encrypt
        let encryptedText = try eThree.encrypt(text: text, for: lookupResult)
        //# end of snippet: e3kit_encrypt

        return encryptedText
    }

    func decrypt(text: String, from senderPublicKey: VirgilPublicKey? = nil) throws -> String {
        //# start of snippet: e3kit_decrypt
        let decryptedText = try eThree.decrypt(text: text, from: senderPublicKey)
        //# end of snippet: e3kit_decrypt

        return decryptedText
    }

    func hasLocalPrivateKey() throws -> Bool {
        //# start of snippet: e3kit_has_local_private_key
        let hasLocalPrivateKey = try eThree.hasLocalPrivateKey()
        //# end of snippet: e3kit_has_local_private_key

        return hasLocalPrivateKey
    }

    func backupPrivateKey(password: String, completion: FailableCompletion? = nil) {
        //# start of snippet: e3kit_backup_private_key
        eThree.backupPrivateKey(password: password) { error in
            completion?(error)
        }
        //# end of snippet: e3kit_backup_private_key
    }

    func restorePrivateKey(password: String, completion: FailableCompletion? = nil) {
        //# start of snippet: e3kit_restore_private_key
        eThree.restorePrivateKey(password: password) { error in
            completion?(error)
        }
        //# end of snippet: e3kit_restore_private_key
    }

    func rotatePrivateKey(completion: FailableCompletion? = nil) {
        //# start of snippet: e3kit_rotate_private_key
        eThree.rotatePrivateKey { error in
            completion?(error)
        }
        //# end of snippet: e3kit_rotate_private_key
    }
}
