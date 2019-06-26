//
//  TwilioClient.swift
//  E3Kit Twilio iOS Swift Sample
//
//  Created by Matheus Cardoso on 4/24/19.
//  Copyright © 2019 cardoso. All rights reserved.
//

import TwilioChatClient
import VirgilSDK

typealias OnMessagedCallback = (String, String) -> Void

extension TwilioClient {
    func sendMessage(_ message: String, completion: FailableCompletion?) {
        generalChannel.messages?.sendMessage(with: TCHMessageOptions().withBody(message)) { result, message in
            if self.redactsMessages {
                message?.updateBody("[redacted]")
            }
            completion?(result.error)
        }
    }
}

@objc final class TwilioClient: NSObject {
    var client: TwilioChatClient! = nil
    var generalChannel: TCHChannel! = nil
    var messages: [TCHMessage] = []
    var onMessaged: OnMessagedCallback?
    var redactsMessages: Bool = true

    func initializeTwilioClient(withAuthToken authToken: String, _ completion: FailableCompletion?) {
        //# start of snippet: e3kit_initialize_twilio
        let connection = HttpConnection()
        let url = URL(string: "http://localhost:3000/twilio-jwt")!
        let headers = ["Content-Type": "application/json", "Authorization": "Bearer " + authToken]
        let request = Request(url: url, method: .get, headers: headers)
        let body = try! connection.send(request).body!

        let json = try! JSONSerialization.jsonObject(with: body, options: []) as! [String: Any]
        let token = json["twilioToken"] as! String

        TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { result, client in
            guard let client = client, result.isSuccessful() else {
                completion?(result.error)
                return
            }

            self.client = client

            self.joinOrCreateTwilioChannel { error in
                completion?(error)
            }
        }
        //# end of snippet: e3kit_initialize_twilio
    }

    private func joinOrCreateTwilioChannel(_ completion: FailableCompletion?) {
        // not a Virgil snippet.
        // learn here: https://www.twilio.com/docs/chat/channels#create-channel

        // Join (or create) the general channel
        let defaultChannel = "general"
        if let channelsList = client.channelsList() {
            channelsList.channel(withSidOrUniqueName: defaultChannel, completion: { (result, channel) in
                if let channel = channel {
                    self.generalChannel = channel
                    channel.join(completion: { result in
                        print("Channel joined with result \(result)")
                        completion?(nil)
                    })
                } else {
                    // Create the general channel (for public use) if it hasn't been created yet
                    channelsList.createChannel(options: [TCHChannelOptionFriendlyName: "General Chat Channel", TCHChannelOptionType: TCHChannelType.public.rawValue], completion: { (result, channel) -> Void in
                        if result.isSuccessful() {
                            self.generalChannel = channel
                            self.generalChannel?.join(completion: { result in
                                self.generalChannel?.setUniqueName(defaultChannel, completion: { result in
                                    print("channel unique name set")
                                    completion?(result.error)
                                })
                            })
                        }
                    })
                }
            })
        }
    }
}

extension TwilioClient: TwilioChatClientDelegate {
    func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        if let body = message.body, let author = message.author, author != client.user?.identity {
            onMessaged?(body, author)
        }
    }
}
