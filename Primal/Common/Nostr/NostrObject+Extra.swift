//
//  NostrObject+Extra.swift
//  Primal
//
//  Created by Nikola Lukovic on 6.7.23..
//

import Foundation
import secp256k1_implementation
import GenericJSON

extension NostrObject {
    func toJSON() -> JSON {
        .object([
            "id": .string(id),
            "sig": .string(sig),
            "tags": .array(tags.map {
                .array($0.map { s in
                    .string(s)
                })
            }),
            "pubkey": .string(pubkey),
            "created_at": .number(Double(created_at)),
            "kind": .number(Double(kind)),
            "content": .string(content)
        ])
    }
    
    func toEventJSON() -> JSON {
        .array([
            .string("EVENT"),
            toJSON()
        ])
    }
    
    func toJSONString() -> String? {
        let outputFormatting = jsonEncoder.outputFormatting
        jsonEncoder.outputFormatting = .withoutEscapingSlashes
        defer { jsonEncoder.outputFormatting = outputFormatting }
        
        guard let nostrObjectJSONData = try? jsonEncoder.encode(self) else {
            print("Unable to encode NostrObject to Data")
            return nil
        }
        
        guard let nostrObjectJSONString =  String(data: nostrObjectJSONData, encoding: .utf8) else {
            print("Unable to encode NostrObject json Data to String")
            return nil
        }
        
        return nostrObjectJSONString
    }
    
    func toEventJSONString() -> String? {
        let json = toEventJSON()
        
        let outputFormatting = jsonEncoder.outputFormatting
        jsonEncoder.outputFormatting = .withoutEscapingSlashes
        defer { jsonEncoder.outputFormatting = outputFormatting }
        
        guard let nostrEventJSONData = try? jsonEncoder.encode(json) else {
            print("Unable to encode NostrObject to Data")
            return nil
        }
        
        guard let nostrEventJSONString =  String(data: nostrEventJSONData, encoding: .utf8) else {
            print("Unable to encode NostrObject json Data to String")
            return nil
        }
        
        return nostrEventJSONString
    }
}

extension NostrObject {
    static func create(content: String, kind: Int = 1, tags: [[String]] = [], createdAt: Int64 = Int64(Date().timeIntervalSince1970)) -> NostrObject? {
        createNostrObject(content: content, kind: kind, tags: tags, createdAt: createdAt)
    }
    
    static func createAndSign(pubkey: String, privkey: String, content: String, kind: Int = 1, tags: [[String]] = [], createdAt: Int64 = Int64(Date().timeIntervalSince1970)) -> NostrObject? {
        createNostrObjectAndSign(pubkey: pubkey, privkey: privkey, content: content, kind: kind, tags: tags, createdAt: createdAt)
    }
    
    static func like(post: PrimalFeedPost) -> NostrObject? {
        createNostrLikeEvent(post: post)
    }
    
    static func post(_ content: String, mentionedPubkeys: [String] = []) -> NostrObject? {
        createNostrPostEvent(content, mentionedPubkeys: mentionedPubkeys)
    }
    
    static func repost(_ nostrContent: NostrContent) -> NostrObject? {
        createNostrRepostEvent(nostrContent)
    }
    
    static func reply(_ content: String, post: PrimalFeedPost, mentionedPubkeys: [String]) -> NostrObject? {
        createNostrReplyEvent(content, post: post, mentionedPubkeys: mentionedPubkeys)
    }
    
    static func contacts(_ contacts: Set<String>, relays: [String: RelayInfo]) -> NostrObject? {
        createNostrContactsEvent(contacts, relays: relays)
    }
    
    static func getSettings() -> NostrObject? {
        createNostrGetSettingsEvent()
    }
    
    static func updateSettings(_ settings: PrimalSettingsContent) -> NostrObject? {
        createNostrUpdateSettingsEvent(settings)
    }
    
    static func metadata(_ metadata: Profile) -> NostrObject? {
        createNostrMetadataEvent(metadata)
    }
    
    static func firstContact() -> NostrObject? {
        createNostrFirstContactEvent()
    }
    
    static func zap(_ comment: String = "", target: ZapTarget, relays: [String]) -> NostrObject? {
        createNostrPublicZapEvent(comment, target: target, relays: relays)
    }

    static func muteList(_ mutedPubkeys: [String]) -> NostrObject? {
        createNostrMuteListEvent(mutedPubkeys)
    }
    
    static func message(_ content: String, recipientPubkey: String) -> NostrObject? {
        createNostrMessageEvent(content: content, recipientPubkey: recipientPubkey)
    }
    
    static func chatRead(_ pubkey: String) -> NostrObject? {
        createNostrChatReadEvent(pubkey)
    }
    
    static func markAllChatRead() -> NostrObject? {
        createNostrMarkAllChatsReadEvent()
    }
    
    static func wallet(_ content: String) -> NostrObject? {
        createNostrObject(content: content, kind: 10_000_300)
    }
    
    static func zapWallet(_ note: String, sats: Int, post: ParsedContent) -> NostrObject? {
        var tags: [[String]] = [
            ["p", post.user.data.pubkey],
            ["e", post.post.id],
            ["amount", "\(sats)000"]
        ]
        
        if let relays = IdentityManager.instance.userRelays?.keys, !relays.isEmpty {
            tags.append(["relays"] + Array(relays))
        }
        
        return createNostrObject(content: note, kind: 9734, tags: tags)
    }
}

fileprivate let jsonEncoder = JSONEncoder()

fileprivate func createNostrObject(content: String, kind: Int = 1, tags: [[String]] = [], createdAt: Int64 = Int64(Date().timeIntervalSince1970)) -> NostrObject? {
    guard
        IdentityManager.instance.isNewUser ? true : LoginManager.instance.method() == .nsec,
        let keypair = ICloudKeychainManager.instance.getLoginInfo() ?? IdentityManager.instance.newUserKeypair,
        let privkey = keypair.hexVariant.privkey
    else {
        return nil
    }
    
    return createNostrObjectAndSign(pubkey: keypair.hexVariant.pubkey, privkey: privkey, content: content, kind: kind, tags: tags, createdAt: createdAt)
}

fileprivate func createNostrObjectAndSign(pubkey: String, privkey: String, content: String, kind: Int = 1, tags: [[String]] = [], createdAt: Int64 = Int64(Date().timeIntervalSince1970)) -> NostrObject? {
    guard
        let id = createNostrObjectId(pubkey: pubkey, tags: tags, content: content, created_at: createdAt, kind: kind),
        let sig = createNostrObjectSig(privkey: privkey, id: id)
    else {
        return nil
    }
    
    return NostrObject(id: id, sig: sig, tags: tags, pubkey: pubkey, created_at: createdAt, kind: kind, content: content)
}

fileprivate func createNostrLikeEvent(post: PrimalFeedPost) -> NostrObject? {
    createNostrObject(content: "+", kind: 7, tags: [["e", post.id], ["p", post.pubkey]])
}

fileprivate func createNostrContactsEvent(_ contacts: Set<String>, relays: [String: RelayInfo]) -> NostrObject? {
    guard let relaysJSONData = try? jsonEncoder.encode(relays) else {
        print("Unable to encode Relays to Data")
        return nil
    }
    
    guard let relaysJSONString =  String(data: relaysJSONData, encoding: .utf8) else {
        print("Unable to encode Relays json Data to String")
        return nil
    }
    
    let tags = contacts.map {
        ["p", $0]
    }
    return createNostrObject(content: relaysJSONString, kind: 3, tags: tags)
}

fileprivate func createNostrPostEvent(_ content: String, mentionedPubkeys: [String] = []) -> NostrObject? {
    createNostrObject(content: content, kind: 1, tags: mentionedPubkeys.map {
        ["p", $0, "", "mention"]
    })
}

fileprivate func createNostrRepostEvent(_ nostrContent: NostrContent) -> NostrObject? {
    guard let jsonData = try? JSONEncoder().encode(nostrContent) else {
        print("Error encoding post json for repost")
        return nil
    }
    let jsonStr = String(data: jsonData, encoding: .utf8)!
    
    return createNostrObject(content: jsonStr, kind: 6, tags: [["e", nostrContent.id], ["p", nostrContent.pubkey]])
}

fileprivate func createNostrReplyEvent(_ content: String, post: PrimalFeedPost, mentionedPubkeys: [String]) -> NostrObject? {
    let e = ["e", post.id, "", "reply"]
    let p = ["p", post.pubkey]
    
    return createNostrObject(content: content, kind: 1, tags: [e, p] + mentionedPubkeys.map { ["p", $0, "", "mention"] })
}

fileprivate func createNostrGetSettingsEvent() -> NostrObject? {
    let tags: [[String]] = [["d", APP_NAME]]
    
    guard let settingsJSON: JSON = try? JSON(["description": "Sync app settings"]) else {
        print ("Error encoding settings")
        return nil
    }
    
    guard let settingsJSONData = try? jsonEncoder.encode(settingsJSON) else {
        print("Unable to encode tags to Data")
        return nil
    }
    
    guard let settingsJSONString =  String(data: settingsJSONData, encoding: .utf8) else {
        print("Unable to encode tags json Data to String")
        return nil
    }
    
    return createNostrObject(content: settingsJSONString, kind: 30078, tags: tags)
}

fileprivate func createNostrUpdateSettingsEvent(_ settings: PrimalSettingsContent) -> NostrObject? {
    let tags: [[String]] = [["d", APP_NAME]]
    
    guard let settingsJSONData = try? jsonEncoder.encode(settings) else {
        print("Unable to encode tags to Data")
        return nil
    }
    
    guard let settingsJSONString =  String(data: settingsJSONData, encoding: .utf8) else {
        print("Unable to encode tags json Data to String")
        return nil
    }
    
    return createNostrObject(content: settingsJSONString, kind: 30078, tags: tags)
}

fileprivate func createNostrMetadataEvent(_ metadata: Profile) -> NostrObject? {
    guard let metadataJSONData = try? jsonEncoder.encode(metadata) else {
        print("Unable to encode tags to Data")
        return nil
    }
    
    guard let metadataJSONString = String(data: metadataJSONData, encoding: .utf8) else {
        print("Unable to encode tags json Data to String")
        return nil
    }

    return createNostrObject(content: metadataJSONString, kind: NostrKind.metadata.rawValue)
}

fileprivate func createNostrFirstContactEvent() -> NostrObject? {
    let rw_relay_info = RelayInfo(read: true, write: true)
    var relays: [String: RelayInfo] = [:]
    
    for relay in bootstrap_relays {
        relays[relay] = rw_relay_info
    }
    
    guard let relaysJSONData = try? jsonEncoder.encode(relays) else {
        print("Unable to encode tags to Data")
        return nil
    }
    
    guard let relaysJSONString =  String(data: relaysJSONData, encoding: .utf8) else {
        print("Unable to encode tags json Data to String")
        return nil
    }
    
    guard
        IdentityManager.instance.isNewUser ? true : LoginManager.instance.method() == .nsec,
        let keypair = ICloudKeychainManager.instance.getLoginInfo() ?? IdentityManager.instance.newUserKeypair
    else {
        print("Unable to get keypair")
        return nil
    }
    
    let tags = [["p", keypair.hexVariant.pubkey]]
    
    return createNostrObject(content: relaysJSONString, kind: NostrKind.contacts.rawValue, tags: tags)
}

fileprivate func createNostrPublicZapEvent(_ comment: String = "", target: ZapTarget, relays: [String]) -> NostrObject? {
    let tags = createZapTags(target, relays)
    
    return createNostrObject(content: comment, kind: 9734, tags: tags)
}

fileprivate func createNostrMuteListEvent(_ mutedPubkeys: [String]) -> NostrObject? {
    let tags = mutedPubkeys.map({ pubkey in ["p", pubkey] })

    return createNostrObject(content: "", kind: NostrKind.muteList.rawValue, tags: tags)
}

fileprivate func createNostrMessageEvent(content: String, recipientPubkey: String) -> NostrObject? {
    guard
        IdentityManager.instance.isNewUser ? true : LoginManager.instance.method() == .nsec,
        let keypair = ICloudKeychainManager.instance.getLoginInfo() ?? IdentityManager.instance.newUserKeypair,
        let privkey = keypair.hexVariant.privkey
    else {
        return nil
    }
    
    return createNostrObject(
        content: encryptDirectMessage(content, privkey: privkey, pubkey: recipientPubkey) ?? "",
        kind: 4,
        tags: [["p", recipientPubkey]]
    )
}

fileprivate func createNostrChatReadEvent(_ pubkey: String) -> NostrObject? {
    createNostrObject(
        content: "{ \"description\": \"reset messages from '\(pubkey)'\"}",
        kind: 30078,
        tags: [["d", APP_NAME]]
    )
}

fileprivate func createNostrMarkAllChatsReadEvent() -> NostrObject? {
    createNostrObject(
        content: "{'description': 'mark all messages as read'}",
        kind: 30078,
        tags: [["d", APP_NAME]]
    )
}


fileprivate func createZapTags(_ target: ZapTarget, _ relays: [String]) -> [[String]] {
    var tags: [[String]] = []
    
    switch target {
    case .profile(let pubkey):
        tags.append(["p", pubkey])
    case .note(let noteTarget):
        tags.append(["e", noteTarget.eventId])
        tags.append(["p", noteTarget.authorPubkey])
    }
    
    var relaysTag = ["relays"]
    relaysTag.append(contentsOf: relays)
    
    tags.append(relaysTag)
    
    return tags
}

fileprivate func createNostrObjectId(pubkey: String, tags: [[String]], content: String, created_at: Int64, kind: Int) -> String? {
    let defaultOutputFormatting = jsonEncoder.outputFormatting
    jsonEncoder.outputFormatting = .withoutEscapingSlashes
    defer { jsonEncoder.outputFormatting = defaultOutputFormatting }
    
    guard let tagsJSONData = try? jsonEncoder.encode(tags) else {
        print("Unable to encode tags to Data")
        return nil
    }
    
    guard let tagsJSONString =  String(data: tagsJSONData, encoding: .utf8) else {
        print("Unable to encode tags json Data to String")
        return nil
    }
    
    guard let contentJSONData = try? jsonEncoder.encode(content) else {
        print("Unable to encode content to Data")
        return nil
    }
    
    guard let contentJSONString = String(data: contentJSONData, encoding: .utf8) else {
        print("Unable to encode content json Data to String")
        return nil
    }
    
    guard let commitment = "[0,\"\(pubkey)\",\(created_at),\(kind),\(tagsJSONString),\(contentJSONString)]".data(using: .utf8) else {
        print("Unable to encode commitment to Data")
        return nil
    }
    
    let hash = sha256(commitment)
    
    return hex_encode(hash)
}

fileprivate func createNostrObjectSig(privkey: String, id: String) -> String? {
    guard let privkeyBytes = try? privkey.bytes else {
        print("Unable to get bytes from privkey")
        return nil
    }
    
    guard let key = try? secp256k1.Signing.PrivateKey(rawRepresentation: privkeyBytes) else {
        print("Unable to get key from privkey bytes")
        return nil
    }
    
    var aux_rand = random_bytes(count: 64)
    
    guard var idBytes = try? id.bytes else {
        print("Unable to get bytes from id")
        return nil
    }
    
    guard let sig = try? key.schnorr.signature(message: &idBytes, auxiliaryRand: &aux_rand) else {
        print("Failed to create signature for: \(id)")
        return nil
    }
    
    return hex_encode(sig.rawRepresentation)
}
