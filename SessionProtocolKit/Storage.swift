import Curve25519Kit

public enum ClosedGroupRatchetCollectionType {
    case old, current
}

public protocol SessionProtocolKitStorageProtocol {

    func writeSync(with block: @escaping (Any) -> Void)

    func getUserKeyPair() -> ECKeyPair?
    func getClosedGroupRatchet(for groupPublicKey: String, senderPublicKey: String, from collection: ClosedGroupRatchetCollectionType) -> ClosedGroupRatchet?
    func setClosedGroupRatchet(for groupPublicKey: String, senderPublicKey: String, ratchet: ClosedGroupRatchet, in collection: ClosedGroupRatchetCollectionType, using transaction: Any)
}
