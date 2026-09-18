// Copyright 2026 Aarav Ravindra Kharade
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Glibc
import libark

public struct Builtins {
    
    // MARK: - pwd
    public static func pwd(args: [String]) throws {
        // Flags: -L, -P, --help, --version, -0
        if args.contains("--help") {
            print("Usage: pwd [-L|-P]")
            return
        }
        var buf = [CChar](repeating: 0, count: 1024)
        guard getcwd(&buf, 1024) != nil else {
            print("pwd: error")
            return
        }
        print(String(cString: buf))
    }
    
    // MARK: - cd
    public static func cd(args: [String]) throws {
        // Flags: -L, -P, -e, -@, --help
        if args.contains("--help") {
            print("Usage: cd [dir]")
            return
        }
        let target = args.first(where: { !$0.hasPrefix("-") }) ?? "/"
        if chdir(target) != 0 {
            print("cd: \(target): No such file or directory")
        }
    }
    
    // MARK: - say
    public static func say(args: [String]) throws {
        var noNewline = false
        var enableEscapes = false
        
        if let first = args.first {
            if first == "--help" {
                print("Usage: say [-neE] [args...]")
                return
            } else if first == "--version" {
                print("say (sash) 1.0")
                return
            }
        }
        
        var wordIndex = 0
        for arg in args {
            if arg.hasPrefix("-") && arg.count > 1 {
                var isFlag = true
                var tempNoNewline = noNewline
                var tempEnableEscapes = enableEscapes
                
                for char in arg.dropFirst() {
                    if char == "n" {
                        tempNoNewline = true
                    } else if char == "e" {
                        tempEnableEscapes = true
                    } else if char == "E" {
                        tempEnableEscapes = false
                    } else {
                        isFlag = false
                        break
                    }
                }
                if isFlag {
                    noNewline = tempNoNewline
                    enableEscapes = tempEnableEscapes
                    wordIndex += 1
                    continue
                }
            }
            break
        }
        
        let words = wordIndex < args.count ? Array(args[wordIndex...]) : []
        var output = words.joined(separator: " ")
        
        if enableEscapes {
            var processed = ""
            var i = output.startIndex
            var stopOutput = false
            
            while i < output.endIndex {
                let char = output[i]
                if char == "\\" {
                    let nextIndex = output.index(after: i)
                    if nextIndex < output.endIndex {
                        let nextChar = output[nextIndex]
                        switch nextChar {
                        case "n": processed.append("\n")
                        case "t": processed.append("\t")
                        case "r": processed.append("\r")
                        case "b": processed.append("\u{08}") // backspace
                        case "a": processed.append("\u{07}") // bell
                        case "v": processed.append("\u{0B}") // vertical tab
                        case "f": processed.append("\u{0C}") // form feed
                        case "\\": processed.append("\\")
                        case "c":
                            noNewline = true
                            stopOutput = true
                        case "0":
                            var octalValue = 0
                            var count = 0
                            var octalIndex = output.index(after: nextIndex)
                            while octalIndex < output.endIndex && count < 3 {
                                if let val = output[octalIndex].wholeNumberValue, val >= 0 && val <= 7 {
                                    octalValue = octalValue * 8 + val
                                    count += 1
                                    octalIndex = output.index(after: octalIndex)
                                } else {
                                    break
                                }
                            }
                            if count > 0 {
                                if let scalar = UnicodeScalar(octalValue) {
                                    processed.append(Character(scalar))
                                }
                                i = output.index(before: octalIndex)
                            } else {
                                processed.append("\0")
                                i = nextIndex
                            }
                        default:
                            processed.append("\\")
                            processed.append(nextChar)
                        }
                        if stopOutput { break }
                        if nextChar != "0" {
                            i = nextIndex
                        }
                    } else {
                        processed.append("\\")
                    }
                } else {
                    processed.append(char)
                }
                if stopOutput { break }
                i = output.index(after: i)
            }
            output = processed
        }
        
        if noNewline {
            print(output, terminator: "")
            fflush(stdout)
        } else {
            print(output)
        }
    }
    
    // MARK: - cat
    public static func cat(args: [String]) throws {
        // Flags: -n, -b, -E, -T, -s
        var numberLines = false
        var numberNonBlank = false
        var files: [String] = []
        
        for arg in args {
            if arg == "-n" { numberLines = true }
            else if arg == "-b" { numberNonBlank = true }
            else if arg == "-E" { } // not implemented
            else if arg == "-T" { } // not implemented
            else if arg == "-s" { } // not implemented
            else if arg == "--help" { print("Usage: cat [-n|-b] [file...]"); return }
            else { files.append(arg) }
        }
        
        if files.isEmpty {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                print(str, terminator: "")
            }
        } else {
            for file in files {
                do {
                    let content = try FileOperations.readFile(at: file)
                    if numberLines || numberNonBlank {
                        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
                        var lineNum = 1
                        for line in lines {
                            if numberNonBlank && line.isEmpty {
                                print("")
                            } else {
                                print(String(format: "%6d  %@", lineNum, String(line)))
                                lineNum += 1
                            }
                        }
                    } else {
                        print(content, terminator: "")
                    }
                } catch {
                    print("cat: \(file): No such file or directory")
                }
            }
        }
    }
    
    // MARK: - mkdir
    public static func mkdir(args: [String]) throws {
        // Flags: -p, -v, -m, --parents, --verbose
        var p = false
        var v = false
        var dirs: [String] = []
        
        for arg in args {
            if arg == "-p" || arg == "--parents" { p = true }
            else if arg == "-v" || arg == "--verbose" { v = true }
            else if arg == "-m" { } // ignored
            else if arg == "--help" { print("Usage: mkdir [-p] [-v] dir..."); return }
            else if !arg.hasPrefix("-") { dirs.append(arg) }
        }
        
        for dir in dirs {
            if p {
                let parts = dir.split(separator: "/")
                var current = dir.hasPrefix("/") ? "/" : ""
                for part in parts {
                    current += String(part) + "/"
                    _ = Syscall.mkdir(path: current, mode: 0o755)
                }
                if v { print("mkdir: created directory '\(dir)'") }
            } else {
                let ret = Syscall.mkdir(path: dir, mode: 0o755)
                if ret != 0 {
                    print("mkdir: cannot create directory '\(dir)'")
                } else if v {
                    print("mkdir: created directory '\(dir)'")
                }
            }
        }
    }
    
    // MARK: - rmdir
    public static func rmdir(args: [String]) throws {
        // Flags: -p, -v, --ignore-fail-on-non-empty, --help, --version
        var v = false
        var dirs: [String] = []
        for arg in args {
            if arg == "-v" { v = true }
            else if arg == "-p" { }
            else if arg == "--help" { print("Usage: rmdir [-v] dir..."); return }
            else if !arg.hasPrefix("-") { dirs.append(arg) }
        }
        for dir in dirs {
            let ret = Syscall.rmdir(path: dir)
            if ret != 0 {
                print("rmdir: failed to remove '\(dir)'")
            } else if v {
                print("rmdir: removing directory, '\(dir)'")
            }
        }
    }
    
    // MARK: - touch
    public static func touch(args: [String]) throws {
        // Flags: -a, -m, -c, -r, -d
        var files: [String] = []
        for arg in args {
            if arg == "-a" || arg == "-m" || arg == "-c" || arg == "-r" || arg == "-d" { }
            else if arg == "--help" { print("Usage: touch file..."); return }
            else if !arg.hasPrefix("-") { files.append(arg) }
        }
        for file in files {
            do {
                _ = try FileOperations.readFile(at: file) // check if exists
            } catch {
                try FileOperations.writeFile(at: file, contents: "")
            }
        }
    }
    
    // MARK: - rm
    public static func rm(args: [String]) throws {
        // Flags: -r, -f, -i, -v, -d
        var r = false
        var v = false
        var files: [String] = []
        for arg in args {
            if arg == "-r" || arg == "-R" || arg == "--recursive" { r = true }
            else if arg == "-f" || arg == "--force" { }
            else if arg == "-v" || arg == "--verbose" { v = true }
            else if arg == "-i" { }
            else if arg == "-d" || arg == "--dir" { }
            else if arg == "--help" { print("Usage: rm [-r] [-v] file..."); return }
            else if !arg.hasPrefix("-") { files.append(arg) }
        }
        
        for file in files {
            if r {
                // Not fully implemented recursive delete in libark
                // Fallback to rmdir/unlink
                _ = Syscall.unlink(path: file)
                _ = Syscall.rmdir(path: file)
            } else {
                let ret = Syscall.unlink(path: file)
                if ret != 0 {
                    print("rm: cannot remove '\(file)'")
                } else if v {
                    print("removed '\(file)'")
                }
            }
        }
    }
    
    // MARK: - mv
    public static func mv(args: [String]) throws {
        // Flags: -i, -f, -v, -n, -u
        var v = false
        var sources: [String] = []
        for arg in args {
            if arg == "-v" || arg == "--verbose" { v = true }
            else if arg == "-i" || arg == "-f" || arg == "-n" || arg == "-u" { }
            else if arg == "--help" { print("Usage: mv [-v] source dest"); return }
            else if !arg.hasPrefix("-") { sources.append(arg) }
        }
        guard sources.count >= 2 else {
            print("mv: missing destination file operand")
            return
        }
        let dest = sources.removeLast()
        for src in sources {
            let ret = Syscall.rename(oldPath: src, newPath: dest) // simple implementation
            if ret != 0 {
                print("mv: cannot move '\(src)' to '\(dest)'")
            } else if v {
                print("renamed '\(src)' -> '\(dest)'")
            }
        }
    }
    
    // MARK: - cp
    public static func cp(args: [String]) throws {
        // Flags: -r, -i, -f, -v, -n
        var v = false
        var sources: [String] = []
        for arg in args {
            if arg == "-v" || arg == "--verbose" { v = true }
            else if arg == "-r" || arg == "-i" || arg == "-f" || arg == "-n" { }
            else if arg == "--help" { print("Usage: cp [-v] source dest"); return }
            else if !arg.hasPrefix("-") { sources.append(arg) }
        }
        guard sources.count >= 2 else {
            print("cp: missing destination file operand")
            return
        }
        let dest = sources.removeLast()
        for src in sources {
            do {
                let content = try FileOperations.readFile(at: src)
                try FileOperations.writeFile(at: dest, contents: content)
                if v {
                    print("copied '\(src)' -> '\(dest)'")
                }
            } catch {
                print("cp: cannot copy '\(src)'")
            }
        }
    }
    
    // MARK: - ls
    public static func ls(args: [String]) throws {
        // Flags: -l, -a, -h, -r, -t
        var l = false
        var a = false
        var targets: [String] = []
        
        for arg in args {
            if arg == "-l" { l = true }
            else if arg == "-a" { a = true }
            else if arg == "-h" || arg == "-r" || arg == "-t" { }
            else if arg == "--help" { print("Usage: ls [-l] [-a] [dir...]"); return }
            else if !arg.hasPrefix("-") { targets.append(arg) }
        }
        
        if targets.isEmpty {
            targets.append(".")
        }
        
        for target in targets {
            let walker = DirectoryWalker(root: Path(target))
            var count = 0
            for entry in walker {
                if !a && entry.name.hasPrefix(".") { continue }
                if l {
                    // simple format
                    print("\(entry.type) \(entry.name)")
                } else {
                    print("\(entry.name)  ", terminator: "")
                }
                count += 1
            }
            if !l && count > 0 {
                print("")
            }
        }
    }

    public static func test(args: [String]) throws -> Bool {
        // Simple test implementation
        if args.isEmpty { return false }
        
        if args.count == 1 {
            return !args[0].isEmpty
        }
        
        if args.count == 2 {
            let op = args[0]
            let val = args[1]
            switch op {
            case "-z": return val.isEmpty
            case "-n": return !val.isEmpty
            case "-f":
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: val, isDirectory: &isDir)
                return exists && !isDir.boolValue
            case "-d":
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: val, isDirectory: &isDir)
                return exists && isDir.boolValue
            case "-e":
                return FileManager.default.fileExists(atPath: val)
            default:
                return false
            }
        }
        
        if args.count == 3 {
            let v1 = args[0]
            let op = args[1]
            let v2 = args[2]
            
            if op == "=" || op == "==" { return v1 == v2 }
            if op == "!=" { return v1 != v2 }
            
            if let n1 = Int(v1), let n2 = Int(v2) {
                switch op {
                case "-eq": return n1 == n2
                case "-ne": return n1 != n2
                case "-lt": return n1 < n2
                case "-le": return n1 <= n2
                case "-gt": return n1 > n2
                case "-ge": return n1 >= n2
                default: return false
                }
            }
            return false
        }
        
        return false
    }
    
    public static func printf(args: [String]) throws {
        guard !args.isEmpty else { return }
        
        var format = args[0]
        
        // Handle basic escapes
        format = format.replacingOccurrences(of: "\\n", with: "\n")
        format = format.replacingOccurrences(of: "\\t", with: "\t")
        format = format.replacingOccurrences(of: "\\r", with: "\r")
        format = format.replacingOccurrences(of: "\\\\", with: "\\")
        
        let formatArgs = Array(args.dropFirst())
        var argIndex = 0
        
        var result = ""
        var i = format.startIndex
        while i < format.endIndex {
            let char = format[i]
            if char == "%" && format.index(after: i) < format.endIndex {
                let nextChar = format[format.index(after: i)]
                if nextChar == "s" || nextChar == "d" {
                    if argIndex < formatArgs.count {
                        result.append(formatArgs[argIndex])
                        argIndex += 1
                    }
                    i = format.index(after: format.index(after: i))
                    continue
                } else if nextChar == "%" {
                    result.append("%")
                    i = format.index(after: format.index(after: i))
                    continue
                }
            }
            result.append(char)
            i = format.index(after: i)
        }
        
        print(result, terminator: "")
        fflush(stdout)
    }    
    private static let builtinList = ["cd", "pwd", "ls", "cat", "say", "mkdir", "rmdir", "touch", "rm", "mv", "cp", "[", "test", "printf", "type", "command", "help"]
    


    public static func typeCmd(args: [String], environment: [String: String]) throws {
        for arg in args {
            if builtinList.contains(arg) {
                print("\(arg) is a shell builtin")
            } else if let path = PathResolver.resolveExecutable(arg, environment: environment) {
                print("\(arg) is \(path)")
            } else {
                print("sash: type: \(arg): not found")
            }
        }
    }
    
    public static func command(args: [String], environment: [String: String]) throws {
        if args.first == "-V" || args.first == "-v" {
            let subArgs = Array(args.dropFirst())
            try typeCmd(args: subArgs, environment: environment)
        }
    }
    
    public static func help(args: [String]) throws {
        if args.isEmpty {
            print("sash 1.0 builtins: \(builtinList.joined(separator: ", "))")
            return
        }
        
        let cmd = args[0]
        if cmd == "say" {
            print("say: say [-n] [-e] [-E] [arg ...]")
            print("    Write arguments to the standard output.")
            print("    Options:")
            print("      -n        do not append a newline")
            print("      -e        enable interpretation of backslash escapes")
            print("      -E        disable interpretation of backslash escapes (default)")
        } else if builtinList.contains(cmd) {
            print("\(cmd): shell builtin")
        } else {
            print("sash: help: no help topics match `\(cmd)'.")
        }
    }

}

