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
    
    // MARK: - echo
    public static func echo(args: [String]) throws {
        // Flags: -n, -e, -E, --help, --version
        var noNewline = false
        var words: [String] = []
        for arg in args {
            if arg == "-n" { noNewline = true }
            else if arg == "-e" { } // not implemented
            else if arg == "-E" { } // not implemented
            else if arg == "--help" { print("Usage: echo [-n] [args...]"); return }
            else if arg == "--version" { print("echo (sash) 1.0"); return }
            else { words.append(arg) }
        }
        let output = words.joined(separator: " ")
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
}
