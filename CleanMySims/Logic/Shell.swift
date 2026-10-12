//
//  Shell.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import Foundation

nonisolated enum Shell {
    /// Runs an executable with explicit arguments (no shell, so paths with spaces are safe). Blocking.
    @discardableResult
    static func run(_ executable: String, arguments: [String]) -> (output: String, status: Int32) {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = pipe
        task.standardInput = nil

        do {
            try task.run()
        } catch {
            return (error.localizedDescription, -1)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (String(data: data, encoding: .utf8) ?? "", task.terminationStatus)
    }

    /// Runs `xcrun simctl …`.
    @discardableResult
    static func simctl(_ arguments: String...) -> (output: String, status: Int32) {
        run("/usr/bin/xcrun", arguments: ["simctl"] + arguments)
    }
}
