// Exports one signing identity (certificate and private key) from the keychain as a .p12, for CI.
// macOS asks for permission to export the key. The password is read from the P12_PASSWORD
// environment variable, so it never appears in the process list.
// Usage: P12_PASSWORD=… swift scripts/export-identity.swift <certificate SHA-1> <out.p12>
import CryptoKit
import Foundation
import Security

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 3, let password = ProcessInfo.processInfo.environment["P12_PASSWORD"] else {
    fail("usage: P12_PASSWORD=… swift export-identity.swift <certificate SHA-1> <out.p12>")
}
let wanted = arguments[1].uppercased()

var result: CFTypeRef?
let query: [String: Any] = [
    kSecClass as String: kSecClassIdentity, kSecMatchLimit as String: kSecMatchLimitAll, kSecReturnRef as String: true,
]
guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let identities = result as? [SecIdentity] else {
    fail("no signing identities in the keychain")
}
let identity = identities.first { identity in
    var certificate: SecCertificate?
    SecIdentityCopyCertificate(identity, &certificate)
    guard let certificate else { return false }
    let sha1 = Insecure.SHA1.hash(data: SecCertificateCopyData(certificate) as Data)
    return sha1.map { String(format: "%02X", $0) }.joined() == wanted
}
guard let identity else { fail("no identity with certificate SHA-1 \(wanted)") }

var parameters = SecItemImportExportKeyParameters()
parameters.version = UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION)
parameters.passphrase = Unmanaged.passUnretained(password as CFString)
var exported: CFData?
let status = SecItemExport(identity, .formatPKCS12, [], &parameters, &exported)
guard status == errSecSuccess, let exported else {
    fail("export failed: \(SecCopyErrorMessageString(status, nil) as String? ?? "\(status)")")
}
FileManager.default.createFile(atPath: arguments[2], contents: exported as Data, attributes: [.posixPermissions: 0o600])
