import CryptoKit
import Foundation

nonisolated struct AppAttestRequestBinding: Codable, Equatable, Sendable {
    let method: String
    let pathname: String
    let query: String
    let bodySHA256: String

    init(method: String, url: URL, body: Data?) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AppAttestClientError.invalidURL
        }
        self.method = method.uppercased()
        self.pathname = components.percentEncodedPath
        self.query = Self.normalizedQuery(components.queryItems ?? [])
        self.bodySHA256 = Self.hexDigest(body ?? Data())
    }

    func canonicalPayload(challenge: String) -> String {
        [
            "KARA-APP-ATTEST-V1",
            challenge,
            method,
            pathname,
            query,
            bodySHA256,
        ].joined(separator: "\n")
    }

    private static func normalizedQuery(_ items: [URLQueryItem]) -> String {
        items
            .map { (percentEncode($0.name), percentEncode($0.value ?? "")) }
            .sorted {
                if $0.0 != $1.0 { return $0.0 < $1.0 }
                return $0.1 < $1.1
            }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
    }

    private static func percentEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private static func hexDigest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
