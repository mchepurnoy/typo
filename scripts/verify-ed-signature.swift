// Checks an EdDSA (Ed25519) signature from Sparkle's sign_update against a public key, so a release
// signed with a key that does not match the app's SUPublicEDKey fails before it is published.
// Usage: swift scripts/verify-ed-signature.swift <base64 public key> <base64 signature> <file>
import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
      let publicKey = Data(base64Encoded: arguments[1]).flatMap({ try? Curve25519.Signing.PublicKey(rawRepresentation: $0) }),
      let signature = Data(base64Encoded: arguments[2]),
      let file = FileManager.default.contents(atPath: arguments[3])
else {
    FileHandle.standardError.write(Data("usage: verify-ed-signature.swift <public key> <signature> <file>\n".utf8))
    exit(2)
}
guard publicKey.isValidSignature(signature, for: file) else {
    FileHandle.standardError.write(Data("signature does not match SUPublicEDKey\n".utf8))
    exit(1)
}
