//
//  CacheCommand.swift
//  SwiftLint
//
//  Created by Keith Smiley on 8/7/15.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import Commandant
import Foundation
import LlamaKit
import SourceKittenFramework
import SwiftLintFramework
import SwiftXPC

let cacheFile = "cache.json"

struct CacheCommand: CommandType {
    let verb = "cache"
    let function = "Cache protocols and their paths"

    func run(mode: CommandMode) -> Result<(), CommandantError<()>> {
        return CacheOptions.evaluate(mode).flatMap { options in
            if let URL = NSURL(fileURLWithPath: options.cachePath) {
                self.cache(URL, directories: options.directories, paths: options.paths)
                return success()
            }

            return failure(CommandantError<()>.CommandError(Box()))
        }
    }

    private func cache(cacheURL: NSURL, directories: [String], paths: [String]) {
        let absoluteDirectories = directories.map { $0.absolutePathRepresentation() }
        var filesToLint = paths.flatMap(filesToLintAtPath)
        var pathForProtocol = [String: String]()

        if let data = NSData(contentsOfURL: cacheURL),
            let json: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil),
            let protocols = json as? [String: String]
        {
            pathForProtocol = protocols
            NSLog("loading \(pathForProtocol)")
        } else {
            filesToLint += directories.flatMap(filesToLintAtPath)
        }

        let files = filesToLint.map { File(path: $0) }.filter { $0 != nil }.map { $0! }
        NSLog("Files: \(files)")
        for file in files {
            NSLog("checking \(file)")
            let protocols = self.protocolsFromFile(file)
            for (k, v) in protocols {
                NSLog("adding \(k) \(v)")
                pathForProtocol[k] = v
            }
        }

        NSLog("protocols: \(pathForProtocol)")

        let dictionary = pathForProtocol as NSDictionary
        let JSON = NSJSONSerialization.dataWithJSONObject(dictionary, options: nil, error: nil)
        NSLog("writing \(cacheURL)")
        let worked = JSON?.writeToURL(cacheURL, atomically: true)
        NSLog("worked \(worked)")
    }

    private func protocolsFromFile(file: File) -> [String: String] {
        let path: String! = file.path
        if path == nil {
            NSLog("path is bad")
            return [:]
        }

        var pathForProtocol = [String: String]()
        if let structure = file.structure.dictionary["key.substructure"] as? XPCArray {
            NSLog("sub structure good")
            for a in structure {
                let contents = a as? XPCDictionary ?? [:]
                if !self.isProtocol(contents) {
                    continue
                }

                let name = contents["key.name"]
                NSLog("Is protocol \(name) \(path)")
                if let name = contents["key.name"] as? String {
                    pathForProtocol[name] = path
                }
            }
        }

        return pathForProtocol
    }

    private func isProtocol(d: XPCDictionary) -> Bool {
        return d["key.kind"] as? String == "source.lang.swift.decl.protocol"
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


private struct CacheOptions: OptionsType {
    let cachePath: String
    let directories: [String]
    let paths: [String]

    static func create(cachePath: String)(directory: String)(path: String) -> CacheOptions {
        let paths = split(path) { $0 == "," }
        let directories = split(directory) { $0 == "," }
        return CacheOptions(cachePath: cachePath, directories: directories, paths: paths)
    }

    private static func evaluate(m: CommandMode) -> Result<CacheOptions, CommandantError<()>> {
        return create
            <*> m <| Option(key: "cachePath", defaultValue: "", usage: "the path to output the cache file")
            <*> m <| Option(key: "directories", defaultValue: "", usage: "the directories to build the cache from separated by commas")
            <*> m <| Option(key: "paths", defaultValue: "", usage: "the path to changed files separated by commas")
    }
}
