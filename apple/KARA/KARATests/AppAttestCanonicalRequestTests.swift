import Foundation
import Testing
@testable import KARA

@Suite("App Attest canonical request")
struct AppAttestCanonicalRequestTests {
    @Test("Matches the backend protocol vector")
    func matchesBackendVector() throws {
        let url = try #require(URL(string: "https://kara.test/v1/metals-spot.json?metal=XAU&currency=EUR"))
        let binding = try AppAttestRequestBinding(
            method: "get",
            url: url,
            body: nil
        )

        #expect(binding.query == "currency=EUR&metal=XAU")
        #expect(binding.canonicalPayload(challenge: "AQIDBA") == [
            "KARA-APP-ATTEST-V1",
            "AQIDBA",
            "GET",
            "/v1/metals-spot.json",
            "currency=EUR&metal=XAU",
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        ].joined(separator: "\n"))
    }
}
