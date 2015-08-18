//
//  LintCommand.swift
//  SwiftLint
//
//  Created by JP Simard on 2015-05-16.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import Commandant
import Foundation
import LlamaKit
import SourceKittenFramework
import SwiftLintFramework

let fileManager = NSFileManager.defaultManager()

struct LintCommand: CommandType {
    let verb = "lint"
    let function = "Print lint warnings and errors for the Swift files in the current directory " +
                   "(default command)"

    func run(mode: CommandMode) -> Result<(), CommandantError<()>> {
        return LintOptions.evaluate(mode).flatMap { options in
            Linter.cachePath = options.cachePath
            if options.useSTDIN {
                let standardInput = NSFileHandle.fileHandleWithStandardInput()
                let stdinData = standardInput.readDataToEndOfFile()
                let stdinNSString = NSString(data: stdinData, encoding: NSUTF8StringEncoding)
                if let stdinString = stdinNSString as? String {
                    let violations = Linter(file: File(contents: stdinString)).styleViolations
                    println(join("\n", violations.map { $0.description }))
                    return success()
                }
                return failure(CommandantError<()>.CommandError(Box()))
            }

            // Otherwise parse path.
            return self.lint(options.paths)
        }
    }

    private func lint(paths: [String]) -> Result<(), CommandantError<()>> {
        let filesToLint = paths.flatMap(filesToLintAtPath)
        let pathsString = " ".join(paths)
        if filesToLint.count > 0 {

            if paths.isEmpty {
                println("Linting Swift files in current working directory")
            } else {
                println("Linting Swift files at paths \(pathsString)")
            }

            var numberOfViolations = 0
            for (index, file) in enumerate(filesToLint) {
                println("Linting '\(file.lastPathComponent)' (\(index + 1)/\(filesToLint.count))")
                for violation in Linter(file: File(path: file)!).styleViolations {
                    println(violation)
                    numberOfViolations++
                }
            }
            let violationSuffix = (numberOfViolations != 1 ? "s" : "")
            let filesSuffix = (filesToLint.count != 1 ? "s." : ".")
            println(
                "Done linting!" +
                " Found \(numberOfViolations) violation\(violationSuffix)," +
                " in \(filesToLint.count) file\(filesSuffix)"
            )
            if numberOfViolations > 0 {
                // This represents failure of the content (i.e. violations in the files linted)
                // and not failure of the scanning process itself. The current command architecture
                // doesn't discriminate between these types.
                return failure(CommandantError<()>.CommandError(Box()))
            } else {
                return success()
            }
        }
        return failure(CommandantError<()>.UsageError(description: "No lintable files found at" +
            " path \(pathsString)"))
    }
}

private func filesToLintAtPath(path: String) -> [String] {
    let absolutePath = path.absolutePathRepresentation()
    var isDirectory: ObjCBool = false
    if fileManager.fileExistsAtPath(absolutePath, isDirectory: &isDirectory) {
        if isDirectory {
            return fileManager.allFilesRecursively(directory: absolutePath).filter {
                $0.isSwiftFile()
            }
        } else if absolutePath.isSwiftFile() {
            return [absolutePath]
        }
    }
    return []
}

struct LintOptions: OptionsType {
    let paths: [String]
    let useSTDIN: Bool
    let cachePath: String

    static func create(path: String)(useSTDIN: Bool)(cachePath: String) -> LintOptions {
        let paths = split(path) { $0 == "," }
        return LintOptions(paths: paths, useSTDIN: useSTDIN, cachePath: cachePath)
    }

    static func evaluate(m: CommandMode) -> Result<LintOptions, CommandantError<()>> {
        return create
            <*> m <| Option(key: "paths", defaultValue: "", usage: "the path to the file or" +
                        " directory to lint (multiple separated by commas)")
            <*> m <| Option(key: "use-stdin", defaultValue: false, usage: "lint standard input")
            <*> m <| Option(key: "cachePath", defaultValue: "", usage: "path for protocol cache")
    }
}
