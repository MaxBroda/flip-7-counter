import Foundation

public struct SupabaseConfig: Codable, Equatable, Sendable {
    public let url: URL
    public let key: String

    public init?(url rawURL: String, key rawKey: String) {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !key.isEmpty,
            let parsed = URLComponents(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
            parsed.scheme == "https",
            let host = parsed.host, !host.isEmpty
        else { return nil }
        var origin = URLComponents()
        origin.scheme = "https"
        origin.host = host
        origin.port = parsed.port
        guard let url = origin.url else { return nil }
        self.url = url
        self.key = key
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let url = try container.decode(String.self, forKey: .url)
        let key = try container.decode(String.self, forKey: .key)
        guard let config = SupabaseConfig(url: url, key: key) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Ungültige Supabase-Verbindung"))
        }
        self = config
    }
}

public enum SharedHistoryError: Error, CustomStringConvertible {
    case unreachable(underlying: Error)
    case rejected(status: Int, message: String)
    case unreadable(underlying: Error)

    public var description: String {
        switch self {
        case .unreachable(let error): "Supabase nicht erreichbar: \(error.localizedDescription)"
        case .rejected(401, _), .rejected(403, _): "Zugriff verweigert. Stimmt der Key, und sind die Tabellen angelegt?"
        case .rejected(404, _): "Tabellen nicht gefunden. Wurde das SQL-Setup ausgeführt?"
        case .rejected(let status, let message): "Supabase meldet \(status): \(message)"
        case .unreadable: "Antwort von Supabase nicht lesbar."
        }
    }
}

/// Spricht die REST-API (PostgREST) eines Supabase-Projekts an.
/// Gelöscht wird nie, nur markiert: so erreicht eine Löschung auch Macs, die gerade offline sind.
public final class SupabaseHistory: Sendable {
    private static let pageSize = 1000

    private let config: SupabaseConfig
    private let session: URLSession

    public init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func fetch() async throws -> SharedHistory {
        let games: [StoredGame] = try await fetchAll("games", select: "id,data,deleted_at")
        let resets: [StoredReset] = try await fetchAll("player_resets", select: "name_key,data")
        return SharedHistory(games: games.map(\.entry), resets: resets.map(\.data))
    }

    public func push(_ changes: OutgoingChanges) async throws {
        if !changes.games.isEmpty {
            let rows = changes.games.map { GameUpload(id: $0.id, finishedAt: $0.finishedAt, data: $0) }
            try await send("POST", "games", query: [URLQueryItem(name: "on_conflict", value: "id")], upsert: true, body: rows)
        }
        if !changes.deletions.isEmpty {
            let ids = changes.deletions.map(\.uuidString).joined(separator: ",")
            try await send("PATCH", "games", query: [URLQueryItem(name: "id", value: "in.(\(ids))")], upsert: false, body: Deletion(deletedAt: .now))
        }
        if !changes.resets.isEmpty {
            let rows = changes.resets.map { ResetUpload(nameKey: $0.name.key, data: $0) }
            try await send("POST", "player_resets", query: [URLQueryItem(name: "on_conflict", value: "name_key")], upsert: true, body: rows)
        }
    }

    private func fetchAll<Row: Decodable>(_ table: String, select: String) async throws -> [Row] {
        var rows: [Row] = []
        while true {
            let query = [
                URLQueryItem(name: "select", value: select),
                URLQueryItem(name: "order", value: select.components(separatedBy: ",")[0]),
                URLQueryItem(name: "limit", value: String(Self.pageSize)),
                URLQueryItem(name: "offset", value: String(rows.count)),
            ]
            let data = try await perform(request("GET", table, query: query))
            let page: [Row]
            do {
                page = try Self.decoder.decode([Row].self, from: data)
            } catch {
                throw SharedHistoryError.unreadable(underlying: error)
            }
            rows += page
            if page.count < Self.pageSize { return rows }
        }
    }

    private func send(_ method: String, _ table: String, query: [URLQueryItem], upsert: Bool, body: some Encodable) async throws {
        var request = request(method, table, query: query)
        request.setValue(upsert ? "resolution=merge-duplicates,return=minimal" : "return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)
        _ = try await perform(request)
    }

    private func request(_ method: String, _ table: String, query: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(url: config.url.appending(path: "rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.httpMethod = method
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        // Alte anon keys sind JWTs und gehören zusätzlich in den Authorization-Header, neue publishable keys nicht.
        if config.key.hasPrefix("eyJ") {
            request.setValue("Bearer \(config.key)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SharedHistoryError.unreachable(underlying: error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.message ?? String(decoding: data.prefix(200), as: UTF8.self)
            throw SharedHistoryError.rejected(status: status, message: message)
        }
        return data
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct StoredGame: Decodable {
    let id: UUID
    let data: Game
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, data
        case deletedAt = "deleted_at"
    }

    var entry: SharedGame { deletedAt == nil ? .present(data) : .deleted(id) }
}

private struct StoredReset: Decodable {
    let data: PlayerReset
}

private struct GameUpload: Encodable {
    let id: UUID
    let finishedAt: Date?
    let data: Game

    enum CodingKeys: String, CodingKey {
        case id, data
        case finishedAt = "finished_at"
    }
}

private struct ResetUpload: Encodable {
    let nameKey: String
    let data: PlayerReset

    enum CodingKeys: String, CodingKey {
        case data
        case nameKey = "name_key"
    }
}

private struct Deletion: Encodable {
    let deletedAt: Date

    enum CodingKeys: String, CodingKey {
        case deletedAt = "deleted_at"
    }
}

private struct ErrorBody: Decodable {
    let message: String
}
