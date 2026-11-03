import AppKit
import Observation

/// Aktualisiert die App auf zwei Wegen: aus dem Git-Checkout, aus dem sie gebaut wurde, oder – bei
/// heruntergeladenen Releases – über das neueste GitHub-Release. Danach startet sie neu.
@MainActor
@Observable
final class Updater {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available([String])
        case installing
        case failed(String)
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private enum Mode { case source, release }

    private struct ReleaseInfo: Equatable {
        let tag: String
        let changes: [String]
        let asset: URL
    }

    private static let repo = "MaxBroda/flip-7-counter"

    private(set) var status: Status = .idle
    let commit: String?
    let release: String?
    private let source: URL?
    private let installed: URL
    private let mode: Mode
    private var pending: ReleaseInfo?

    init(bundle: Bundle = .main) {
        let source = (bundle.object(forInfoDictionaryKey: "Flip7SourceDirectory") as? String).map { URL(filePath: $0, directoryHint: .isDirectory) }
        self.source = source
        commit = bundle.object(forInfoDictionaryKey: "Flip7Commit") as? String
        release = bundle.object(forInfoDictionaryKey: "Flip7Release") as? String
        installed = bundle.bundleURL
        let hasCheckout = source.map { FileManager.default.fileExists(atPath: $0.appending(path: ".git").path) } ?? false
        mode = hasCheckout ? .source : .release
    }

    /// Im Git-Checkout wird gebaut, beim heruntergeladenen Release nur geladen.
    var buildsLocally: Bool { mode == .source }
    var versionLabel: String { (buildsLocally ? commit : release) ?? "–" }

    func check() async {
        switch mode {
        case .source: await checkSource()
        case .release: await checkRelease()
        }
    }

    func install() async {
        switch mode {
        case .source: await installSource()
        case .release: if let pending { await installRelease(pending) }
        }
    }

    private func checkSource() async {
        guard let source else { return }
        status = .checking
        do {
            try await run("/usr/bin/git", ["fetch", "--quiet", "origin"], in: source)
            let log = try await run("/usr/bin/git", ["log", "--format=%s", "HEAD..@{u}"], in: source)
            let changes = log.split(separator: "\n").map(String.init)
            status = changes.isEmpty ? .upToDate : .available(changes)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Baut zuerst fertig und tauscht erst danach die App aus, damit ein Fehler die laufende Version nicht beschädigt.
    private func installSource() async {
        guard let source else { return }
        status = .installing
        do {
            try await run("/usr/bin/git", ["pull", "--ff-only", "--quiet"], in: source)
            try await run("/bin/zsh", ["scripts/build-app.sh"], in: source)
            try relaunch(replacingWith: source.appending(path: "build/Flip 7.app"))
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func checkRelease() async {
        status = .checking
        do {
            let info = try await latestRelease()
            if isNewer(info.tag, than: release) {
                pending = info
                status = .available(info.changes)
            } else {
                status = .upToDate
            }
        } catch {
            status = .failed(releaseError(error))
        }
    }

    /// Lädt das Release-ZIP, entpackt es und tauscht erst danach die installierte App aus.
    private func installRelease(_ info: ReleaseInfo) async {
        status = .installing
        do {
            let fresh = try await download(info.asset)
            try relaunch(replacingWith: fresh)
        } catch {
            status = .failed(releaseError(error))
        }
    }

    private func latestRelease() async throws -> ReleaseInfo {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Flip7", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw Failure(message: "GitHub ist gerade nicht erreichbar. Internetverbindung prüfen.")
        }
        let payload = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let asset = payload.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            throw Failure(message: "Im neuesten Release liegt keine App zum Laden.")
        }
        return ReleaseInfo(tag: payload.tagName, changes: Self.notes(payload.body), asset: asset.browserDownloadURL)
    }

    private func download(_ asset: URL) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(from: asset)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw Failure(message: "GitHub ist gerade nicht erreichbar. Internetverbindung prüfen.")
        }
        let temp = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: installed, create: true)
        let zip = temp.appending(path: "update.zip")
        try data.write(to: zip)
        let unpacked = temp.appending(path: "app", directoryHint: .isDirectory)
        try await run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path], in: temp)
        guard let app = try FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil).first(where: { $0.pathExtension == "app" }) else {
            throw Failure(message: "Das Update ließ sich nicht entpacken.")
        }
        return app
    }

    /// `v2` ist neuer als `v10`? Nein – nach Zahlen vergleichen. Ohne eingebettete Version (alte ZIPs) gilt jedes Release als neuer.
    private func isNewer(_ candidate: String, than current: String?) -> Bool {
        guard let current else { return true }
        let new = Self.numbers(candidate), old = Self.numbers(current)
        for index in 0 ..< max(new.count, old.count) {
            let a = index < new.count ? new[index] : 0
            let b = index < old.count ? old[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func numbers(_ tag: String) -> [Int] {
        tag.split(whereSeparator: { !$0.isNumber }).map { Int($0) ?? 0 }
    }

    /// Nur die Aufzählungszeilen der Release-Notes; der Installationshinweis darunter bleibt außen vor.
    private static func notes(_ body: String?) -> [String] {
        body?.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") || $0.hasPrefix("• ") }
            .map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) } ?? []
    }

    private func releaseError(_ error: Error) -> String {
        if let failure = error as? Failure { return failure.message }
        if (error as NSError).domain == NSURLErrorDomain {
            return "GitHub ist gerade nicht erreichbar. Internetverbindung prüfen."
        }
        return error.localizedDescription
    }

    private func relaunch(replacingWith built: URL) throws {
        // Wartet, bis diese Instanz beendet ist, ersetzt dann das Bundle und öffnet die neue Version.
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if [ "$2" != "$3" ]; then rm -rf "$3" && cp -R "$2" "$3"; fi
        open "$3"
        """
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = ["-c", script, "relaunch", "\(ProcessInfo.processInfo.processIdentifier)", built.path, installed.path]
        try process.run()
        NSApp.terminate(nil)
    }

    @discardableResult
    private func run(_ executable: String, _ arguments: [String], in directory: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let (output, code) = await Task.detached {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (String(decoding: data, as: UTF8.self), process.terminationStatus)
        }.value
        guard code == 0 else { throw Failure(message: Self.explain(output, command: arguments.first ?? executable)) }
        return output
    }

    private static func explain(_ output: String, command: String) -> String {
        if output.contains("Not possible to fast-forward") || output.contains("would be overwritten") || output.contains("uncommitted changes") || output.contains("unstaged changes") {
            return "Im Projektordner gibt es eigene Änderungen. Die müssen erst weg, bevor das Update klappt."
        }
        if output.contains("Could not resolve host") || output.contains("unable to access") {
            return "GitHub ist gerade nicht erreichbar. Internetverbindung prüfen."
        }
        let last = output.split(separator: "\n").last.map(String.init) ?? "unbekannter Fehler"
        return "\(command) fehlgeschlagen: \(last)"
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let body: String?
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case assets
    }
}
