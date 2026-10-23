import AppKit
import Observation

/// Holt neue Versionen aus dem Git-Checkout, aus dem die App gebaut wurde, und startet sie neu.
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

    private(set) var status: Status = .idle
    let commit: String?
    private let source: URL?
    private let installed: URL

    init(bundle: Bundle = .main) {
        source = (bundle.object(forInfoDictionaryKey: "Flip7SourceDirectory") as? String).map { URL(filePath: $0, directoryHint: .isDirectory) }
        commit = bundle.object(forInfoDictionaryKey: "Flip7Commit") as? String
        installed = bundle.bundleURL
    }

    var isAvailable: Bool {
        source.map { FileManager.default.fileExists(atPath: $0.appending(path: ".git").path) } ?? false
    }

    func check() async {
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
    func install() async {
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
