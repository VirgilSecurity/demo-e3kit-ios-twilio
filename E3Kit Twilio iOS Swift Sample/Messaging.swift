//
//  Messaging.swift
//  E3Kit Twilio iOS Swift Sample
//
//  Created by Matheus Cardoso on 4/24/19.
//  Copyright © 2019 cardoso. All rights reserved.
//

import Foundation

protocol Messaging {
    associatedtype UserData
    typealias OnMessagedCallback = (_ message: String, _ author: String) -> Void

    var redactsMessages: Bool { get set }

    init()

    func initialize(withUserData userData: UserData, completion: FailableCompletion?)
    func sendMessage(_ message: String, completion: FailableCompletion?)
    func doOnMessaged(callback: @escaping OnMessagedCallback)
}
