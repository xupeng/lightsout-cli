import CoreGraphics

struct ResolutionTests {
    static func main() throws {
        let identifier = "00000000-0000-0000-0000-000000000001"
        let other = "00000000-0000-0000-0000-000000000002"
        let display = Display(id: 2, uuid: identifier, name: "Test")

        func check(_ expected: UInt32?, savedID: Bool, mappedID: UInt32,
                   identities: [UInt32: String], display: Display = display) throws {
            let result: UInt32
            do {
                result = try resolve(display, allowSavedID: savedID,
                                     lookupID: { _ in mappedID },
                                     lookupUUID: { identities[$0] })
            } catch {
                precondition(expected == nil, "Unexpected resolution error: \(error)")
                return
            }
            precondition(expected == result, "Unexpected resolved ID: \(result)")
        }

        try check(3, savedID: false, mappedID: 3, identities: [3: identifier])
        try check(3, savedID: true, mappedID: 3, identities: [2: other, 3: identifier])
        try check(nil, savedID: false, mappedID: 0, identities: [:])
        try check(2, savedID: true, mappedID: 0, identities: [:])
        try check(2, savedID: true, mappedID: 0, identities: [2: identifier])
        try check(nil, savedID: true, mappedID: 0, identities: [2: other])
        try check(nil, savedID: true, mappedID: 2, identities: [2: other])
        try check(nil, savedID: true, mappedID: 0, identities: [:],
                  display: Display(id: 0, uuid: identifier, name: "Invalid ID"))
        try check(nil, savedID: true, mappedID: 0, identities: [:],
                  display: Display(id: 2, uuid: "invalid", name: "Invalid UUID"))
        print("All 9 display resolution tests passed")
    }
}
