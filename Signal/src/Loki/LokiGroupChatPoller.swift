
@objc(LKGroupChatPoller)
public final class LokiGroupChatPoller : NSObject {
    private let group: LokiGroupChat
    private var pollForNewMessagesTimer: Timer? = nil
    private var pollForDeletedMessagesTimer: Timer? = nil
    private var hasStarted = false
    
    private let pollForNewMessagesInterval: TimeInterval = 4
    private let pollForDeletedMessagesInterval: TimeInterval = 20
    
    @objc(initForGroup:)
    public init(for group: LokiGroupChat) {
        self.group = group
        super.init()
    }
    
    @objc public func startIfNeeded() {
        if hasStarted { return }
        pollForNewMessagesTimer = Timer.scheduledTimer(withTimeInterval: pollForNewMessagesInterval, repeats: true) { [weak self] _ in self?.pollForNewMessages() }
        pollForNewMessages() // Perform initial update
        pollForDeletedMessagesTimer = Timer.scheduledTimer(withTimeInterval: pollForDeletedMessagesInterval, repeats: true) { [weak self] _ in self?.pollForDeletedMessages() }
        hasStarted = true
    }
    
    @objc public func stop() {
        pollForNewMessagesTimer?.invalidate()
        pollForDeletedMessagesTimer?.invalidate()
        hasStarted = false
    }
    
    private func pollForNewMessages() {
        let group = self.group
        let _ = LokiGroupChatAPI.getMessages(for: group.serverID, on: group.server).done { messages in
            messages.reversed().forEach { message in
                let senderHexEncodedPublicKey = message.hexEncodedPublicKey
                let endIndex = senderHexEncodedPublicKey.endIndex
                let cutoffIndex = senderHexEncodedPublicKey.index(endIndex, offsetBy: -8)
                let senderDisplayName = "\(message.displayName) (...\(senderHexEncodedPublicKey[cutoffIndex..<endIndex]))"
                let id = group.id.data(using: String.Encoding.utf8)!
                let x1 = SSKProtoGroupContext.builder(id: id, type: .deliver)
                x1.setName(group.displayName)
                let x2 = SSKProtoDataMessage.builder()
                x2.setTimestamp(message.timestamp)
                x2.setGroup(try! x1.build())
                x2.setBody(message.body)
                let messageServerID = message.serverID!
                let publicChatInfo = SSKProtoPublicChatInfo.builder()
                publicChatInfo.setServerID(messageServerID)
                x2.setPublicChatInfo(try! publicChatInfo.build())
                let x3 = SSKProtoContent.builder()
                x3.setDataMessage(try! x2.build())
                let x4 = SSKProtoEnvelope.builder(type: .ciphertext, timestamp: message.timestamp)
                x4.setSource(senderDisplayName)
                x4.setSourceDevice(OWSDevicePrimaryDeviceId)
                x4.setContent(try! x3.build().serializedData())
                OWSPrimaryStorage.shared().dbReadWriteConnection.readWrite { transaction in
                    SSKEnvironment.shared.messageManager.throws_processEnvelope(try! x4.build(), plaintextData: try! x3.build().serializedData(), wasReceivedByUD: false, transaction: transaction)
                }
            }
        }
    }
    
    private func pollForDeletedMessages() {
        let group = self.group
        let _ = LokiGroupChatAPI.getDeletedMessageServerIDs(for: group.serverID, on: group.server).done { deletedMessageServerIDs in
            let storage = OWSPrimaryStorage.shared()
            storage.dbReadWriteConnection.readWrite { transaction in
                let deletedMessageIDs = deletedMessageServerIDs.compactMap { storage.getIDForMessage(withServerID: UInt($0), in: transaction) }
                deletedMessageIDs.forEach { messageID in
                    TSMessage.fetch(uniqueId: messageID)?.remove(with: transaction)
                }
            }
        }
    }
}