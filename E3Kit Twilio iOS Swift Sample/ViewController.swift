//
//  ViewController.swift
//  E3Kit iOS Swift Sample
//
//  Created by Matheus Cardoso on 4/18/19.
//  Copyright © 2019 cardoso. All rights reserved.
//

import UIKit
import VirgilE3Kit

var log: (_ text: Any) -> Void = { print($0) }

class ViewController: UIViewController {
    @IBOutlet weak var logsTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        log = { [weak self] text in
            DispatchQueue.main.async {
                self?.logsTextView.text += "\(text)\n"
            }
        }

        initializeUsers {
            self.initializeMessaging {
                self.registerUsers {
                    self.lookupPublicKeys {
                        do {
                            try self.encryptAndDecrypt()
                        } catch(let e) {
                            log(e)
                        }
                    }
                }
            }
        }
    }

    let alice = Device<TwilioClient>(withIdentity: "Alice")
    let bob = Device<TwilioClient>(withIdentity: "Bob")

    var bobLookup: EThree.LookupResult?
    var aliceLookup: EThree.LookupResult?

    func initializeUsers(_ completion: @escaping Completion) {
        log("Initializing Alice")
        alice.initialize { error in
            if let error = error {
                log("Failed initializing Alice: \(error)")
                return
            }

            log("Initializing Bob")
            self.bob.initialize { error in
                if let error = error {
                    log("Failed initializing Bob: \(error)")
                    return
                }

                completion()
            }
        }
    }

    func initializeMessaging(_ completion: @escaping Completion) {
        log("Alice is logging into Twilio")
        alice.initializeClient(withUserData: .init(authToken: alice.authToken)) { error in
            if let error = error {
                log("Alice failed logging into Twilio: \(error)")
                return
            }

            log("Bob is logging into Twilio")
            self.bob.initializeClient(withUserData: .init(authToken: self.bob.authToken)) { error in
                if let error = error {
                    log("Bob failed logging into Twilio: \(error)")
                    return
                }

                completion()
            }
        }
    }

    func registerUsers(_ completion: @escaping Completion) {
        log("Registering Alice")
        alice.register { error in
            if let error = error, error as? EThreeError != .userIsAlreadyRegistered {
                log("Failed registering Alice: \(error)")
                return
            }

            log("Registering Bob")
            self.bob.register { error in
                if let error = error, error as? EThreeError != .userIsAlreadyRegistered {
                    log("Failed registering Bob: \(error)")
                    return
                }

                // rotate keys in case bob and alice are already registered
                self.alice.rotatePrivateKey { _ in
                    self.bob.rotatePrivateKey { _ in
                        completion()
                    }
                }
            }
        }
    }


    func lookupPublicKeys(_ completion: @escaping Completion) {
        log("Looking up Bob's public key")
        alice.lookupPublicKeys(of: ["Bob"]) {
            switch $0 {
            case .failure(let error):
                log("Failed looking up Bob's public key: \(error)")
            case .success(let lookup):
                self.bobLookup = lookup
            }

            log("Looking up Alice's public key")
            self.bob.lookupPublicKeys(of: ["Alice"]) {
                switch $0 {
                case .failure(let error):
                    log("Failed looking up Alice's public key: \(error)")
                case .success(let lookup):
                    self.aliceLookup = lookup
                    completion()
                }
            }
        }
    }

    func encryptAndDecrypt() throws {
        let aliceEncryptedText = try alice.encrypt(text: "Hello Bob!", for: bobLookup)
        log("Alice encrypts and signs: '\(aliceEncryptedText)'")
        alice.messagingClient.sendMessage(aliceEncryptedText, completion: nil)
        bob.messagingClient.doOnMessaged { _, _ in
            guard let aliceDecryptedText = try? self.bob.decrypt(text: aliceEncryptedText, from: self.aliceLookup!["Alice"]) else {
                log("Bob failed decrypting or verifying Alice's signature")
                return
            }

            log("Bob decrypts and verifies Alice's signature: '\(aliceDecryptedText)'")
        }

        let bobEncryptedText = try bob.encrypt(text: "Hello Alice!", for: aliceLookup)
        log("Bob encrypts and signs: '\(bobEncryptedText)'")

        bob.messagingClient.sendMessage(bobEncryptedText, completion: nil)
        alice.messagingClient.doOnMessaged { _, _ in
            guard let bobDecryptedText = try? self.alice.decrypt(text: bobEncryptedText, from: self.bobLookup!["Bob"]) else {
                log("Alice failed decrypting or verifying Bob's signature")
                return
            }

            log("Alice decrypts and verifies Bob's signature: '\(bobDecryptedText)'")
        }
    }

}

