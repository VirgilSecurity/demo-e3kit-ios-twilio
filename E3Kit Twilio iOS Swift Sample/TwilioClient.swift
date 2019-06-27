//
//  TwilioClient.swift
//  E3Kit Twilio iOS Swift Sample
//
//  Created by Matheus Cardoso on 4/24/19.
//  Copyright © 2019 cardoso. All rights reserved.
//

import TwilioChatClient
import VirgilSDK

@objc final class TwilioClient: NSObject {
    var client: TwilioChatClient? = nil
    var generalChannel: TCHChannel? = nil
    var messages: [TCHMessage] = []
    var onMessaged: (((body: String, author: String)) -> Void)?
    var redactsMessages: Bool = true

    func initializeTwilioClient(withAuthToken authToken: String, _ completion: FailableCompletion?) {
        //# start of snippet: e3kit_initialize_twilio
        let connection = HttpConnection()

        guard let url = URL(string: "http://localhost:3000/twilio-jwt") else {
            completion?(AppError.invalidUrl)
            return
        }

        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer " + authToken
        ]

        let request = Request(url: url, method: .get, headers: headers)

        guard
            let body = try? connection.send(request).body,
            let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any],
            let token = json["twilioToken"] as? String
        else {
            completion?(AppError.invalidResponse)
            return
        }

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
        guard let channelsList = client?.channelsList() else {
            completion?(AppError.gettingChannelsListFailed)
            return
        }

        let defaultChannel = "general"

        channelsList.channel(withSidOrUniqueName: defaultChannel) { result, channel in
            if let channel = channel {
                self.generalChannel = channel
                channel.join { result in
                    print("Channel joined with result \(result)")
                    completion?(nil)
                }
            } else {
                let options = [
                    TCHChannelOptionFriendlyName: "General Chat Channel",
                    TCHChannelOptionType: TCHChannelType.public.rawValue
                ] as [String : Any]

                channelsList.createChannel(options: options) { result, channel in
                    if result.isSuccessful(), let channel = channel {
                        self.generalChannel = channel
                        channel.join { result in
                            channel.setUniqueName(defaultChannel) { result in
                                print("channel unique name set")
                                completion?(result.error)
                            }
                        }
                    } else {
                        completion?(result.error)
                    }
                }
            }
        }
    }

    func sendMessage(_ message: String, completion: FailableCompletion?) {
        generalChannel?.messages?.sendMessage(with: TCHMessageOptions().withBody(message)) { result, message in
            if self.redactsMessages {
                message?.updateBody("[redacted]")
            }
            completion?(result.error)
        }
    }
}

extension TwilioClient: TwilioChatClientDelegate {
    func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        if let body = message.body, let author = message.author, author != client.user?.identity {
            onMessaged?((body, author))
        }
    }
}
