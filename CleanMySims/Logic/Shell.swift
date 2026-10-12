//
//  Shell.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import Foundation

class Shell {
    @discardableResult
    static func run(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.standardInput = nil
        
        do {
            try task.run()
        } catch {
            return error.localizedDescription
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return output
    }

    /// Runs an executable with explicit arguments (no shell quoting issues with spaces in paths).
    @discardableResult
    nonisolated static func run(_ executable: String, arguments: [String]) -> (output: String, status: Int32) {
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
}
