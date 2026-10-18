import Foundation

/// Accepts a snapshot array (current wire format) or a single payload object (legacy format).
enum EchoWireDecoder {
    static func decode(_ data: Data, using decoder: JSONDecoder) -> [EchoStockPayload]? {
        if let batch = try? decoder.decode([EchoStockPayload].self, from: data) {
            return batch
        }
        if let single = try? decoder.decode(EchoStockPayload.self, from: data) {
            return [single]
        }
        return nil
    }
}
