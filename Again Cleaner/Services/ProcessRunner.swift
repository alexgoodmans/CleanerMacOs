//
//  ProcessRunner.swift
//  Again Cleaner
//
//  Runs external tools (docker, brew, tmutil) via the Process API with an
//  explicit argument array — never a shell string, so there is no command
//  injection surface. Includes a timeout and a binary locator that checks
//  known install dirs instead of relying on the app's PATH.
//

import Foundation

struct ProcessRunner: Sendable {

    nonisolated struct Output: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
        var ok: Bool { status == 0 }
    }

    enum RunError: Error, Sendable { case notFound(String), timedOut, launch(String) }

    /// Directories we look in for CLI tools, in order.
    private nonisolated static let searchDirs = [
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
        "/Applications/Docker.app/Contents/Resources/bin",
    ]

    /// Absolute path of a tool by name, or nil if not installed.
    nonisolated static func locate(_ tool: String) -> String? {
        let fm = FileManager.default
        for dir in searchDirs {
            let p = dir + "/" + tool
            if fm.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    /// Run `launchPath args…`, capturing output. Throws on timeout / launch
    /// failure. Never interprets a shell.
    nonisolated static func run(
        _ launchPath: String,
        _ args: [String],
        timeout: Duration = .seconds(30)
    ) async throws -> Output {
        try await withThrowingTaskGroup(of: Output.self) { group in
            group.addTask {
                try await runProcess(launchPath, args)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw RunError.timedOut
            }
            guard let first = try await group.next() else { throw RunError.timedOut }
            group.cancelAll()
            return first
        }
    }

    private nonisolated static func runProcess(
        _ launchPath: String, _ args: [String]
    ) async throws -> Output {
        try await withCheckedThrowingContinuation { cont in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = args
            let outPipe = Pipe(), errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            process.terminationHandler = { proc in
                let out = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                let err = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                cont.resume(returning: Output(status: proc.terminationStatus, stdout: out, stderr: err))
            }
            do { try process.run() }
            catch { cont.resume(throwing: RunError.launch(error.localizedDescription)) }
        }
    }
}
