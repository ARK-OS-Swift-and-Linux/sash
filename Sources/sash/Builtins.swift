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

#if canImport(Musl)
import Musl
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

@inline(__always)
func posix_uname(_ u: inout utsname) -> Int32 {
    #if canImport(Musl)
    return Musl.uname(&u)
    #elseif canImport(Glibc)
    return Glibc.uname(&u)
    #else
    return uname(&u)
    #endif
}

@inline(__always)
func posix_rmdir(_ path: String) -> Int32 {
    #if canImport(Musl)
    return Musl.rmdir(path)
    #elseif canImport(Glibc)
    return Glibc.rmdir(path)
    #else
    return rmdir(path)
    #endif
}

@inline(__always)
func posix_kill(_ pid: pid_t, _ sig: Int32) -> Int32 {
    #if canImport(Musl)
    return Musl.kill(pid, sig)
    #elseif canImport(Glibc)
    return Glibc.kill(pid, sig)
    #else
    return kill(pid, sig)
    #endif
}

@inline(__always)
func posix_mkdir(_ path: String, _ mode: mode_t) -> Int32 {
    #if canImport(Musl)
    return Musl.mkdir(path, mode)
    #elseif canImport(Glibc)
    return Glibc.mkdir(path, mode)
    #else
    return mkdir(path, mode)
    #endif
}

public struct Builtins {
    public static let builtinList: [String] = [
        "help", "cd", "pwd", "ls", "cat", "echo", "say",
        "mkdir", "rmdir", "touch", "rm", "mv", "cp",
        "clear", "uname", "ps", "free", "kill", "jobs",
        "export", "test", "[", "exit"
    ]

    // MARK: - help
    public static func help(args: [String]) {
        if args.isEmpty {
            print("sash 1.0 - The ARK-OS Interactive Shell")
            print("Builtin commands:")
            print("  \(builtinList.joined(separator: ", "))")
            print("Type 'help <command>' for specific command information.")
            return
        }
        let cmd = args[0]
        switch cmd {
        case "cd":
            print("cd [dir]       Change current working directory (default: $HOME or /)")
        case "pwd":
            print("pwd            Print current working directory")
        case "ls":
            print("ls [-l] [-a]   List directory contents")
        case "cat":
            print("cat [file...]  Display content of files")
        case "echo", "say":
            print("echo [-n] [-e] [text...] Print arguments to stdout")
        case "mkdir":
            print("mkdir [-p] dir Create directories")
        case "rmdir":
            print("rmdir dir      Remove empty directory")
        case "touch":
            print("touch file...  Create or update modification time")
        case "rm":
            print("rm [-r] [-f]   Remove files or directories")
        case "clear":
            print("clear          Clear terminal display")
        case "uname":
            print("uname [-a]     Print operating system information")
        case "ps":
            print("ps             Print process status table from /proc")
        case "free":
            print("free           Display system memory usage from /proc/meminfo")
        case "kill":
            print("kill [-sig] pid Send signal to a process")
        case "jobs":
            print("jobs           List background jobs")
        case "export":
            print("export [K=V]   Set environment variable")
        case "exit":
            print("exit [code]    Exit the shell")
        default:
            if builtinList.contains(cmd) {
                print("\(cmd): shell builtin command")
            } else {
                print("sash: help: no help topics match '\(cmd)'.")
            }
        }
    }

    // MARK: - pwd
    public static func pwd(args: [String]) {
        _ = args
        var buf = [CChar](repeating: 0, count: 1024)
        if getcwd(&buf, 1024) != nil {
            print(String(cString: buf))
        } else {
            perror("pwd")
        }
    }

    // MARK: - cd
    public static func cd(args: [String], environment: inout [String: String]) {
        let target: String
        if args.isEmpty {
            target = environment["HOME"] ?? getenv("HOME").flatMap { String(cString: $0) } ?? "/"
        } else if args[0] == "-" {
            target = environment["OLDPWD"] ?? "/"
            print(target)
        } else {
            target = args[0]
        }

        var currentBuf = [CChar](repeating: 0, count: 1024)
        if getcwd(&currentBuf, 1024) != nil {
            environment["OLDPWD"] = String(cString: currentBuf)
        }

        if chdir(target) != 0 {
            perror("sash: cd: \(target)")
        } else {
            var newBuf = [CChar](repeating: 0, count: 1024)
            if getcwd(&newBuf, 1024) != nil {
                environment["PWD"] = String(cString: newBuf)
            }
        }
    }

    // MARK: - echo / say
    public static func echo(args: [String]) {
        var noNewline = false
        var enableEscapes = false
        var wordIndex = 0

        while wordIndex < args.count {
            let arg = args[wordIndex]
            if arg == "-n" {
                noNewline = true
            } else if arg == "-e" {
                enableEscapes = true
            } else if arg == "-ne" || arg == "-en" {
                noNewline = true
                enableEscapes = true
            } else {
                break
            }
            wordIndex += 1
        }

        var text = args[wordIndex...].joined(separator: " ")
        if enableEscapes {
            text = text.replacingOccurrences(of: "\\n", with: "\n")
            text = text.replacingOccurrences(of: "\\t", with: "\t")
            text = text.replacingOccurrences(of: "\\r", with: "\r")
            text = text.replacingOccurrences(of: "\\\\", with: "\\")
        }

        if noNewline {
            print(text, terminator: "")
            fflush(stdout)
        } else {
            print(text)
        }
    }

    // MARK: - clear
    public static func clear() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
    }

    // MARK: - uname
    public static func uname(args: [String]) {
        _ = args
        var u = utsname()
        if posix_uname(&u) == 0 {
            withUnsafePointer(to: &u.sysname) { sPtr in
                withUnsafePointer(to: &u.nodename) { nPtr in
                    withUnsafePointer(to: &u.release) { rPtr in
                        withUnsafePointer(to: &u.version) { vPtr in
                            withUnsafePointer(to: &u.machine) { mPtr in
                                let sys = String(cString: UnsafeRawPointer(sPtr).assumingMemoryBound(to: CChar.self))
                                let node = String(cString: UnsafeRawPointer(nPtr).assumingMemoryBound(to: CChar.self))
                                let rel = String(cString: UnsafeRawPointer(rPtr).assumingMemoryBound(to: CChar.self))
                                let ver = String(cString: UnsafeRawPointer(vPtr).assumingMemoryBound(to: CChar.self))
                                let mach = String(cString: UnsafeRawPointer(mPtr).assumingMemoryBound(to: CChar.self))
                                print("\(sys) \(node) \(rel) \(ver) \(mach)")
                            }
                        }
                    }
                }
            }
        } else {
            print("Linux ARK-OS 7.2.10-zen1 x86_64")
        }
    }

    // MARK: - ls
    public static func ls(args: [String]) {
        var showAll = false
        var longListing = false
        var targets: [String] = []

        for arg in args {
            if arg == "-a" { showAll = true }
            else if arg == "-l" { longListing = true }
            else if arg == "-la" || arg == "-al" { showAll = true; longListing = true }
            else if !arg.hasPrefix("-") { targets.append(arg) }
        }

        if targets.isEmpty {
            targets.append(".")
        }

        for (idx, target) in targets.enumerated() {
            if targets.count > 1 {
                if idx > 0 { print("") }
                print("\(target):")
            }

            guard let dir = opendir(target) else {
                perror("sash: ls: \(target)")
                continue
            }
            defer { closedir(dir) }

            var entries: [(name: String, isDir: Bool, size: Int64)] = []
            while let entry = readdir(dir) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) { ptr in
                    String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
                }
                if !showAll && name.hasPrefix(".") {
                    continue
                }

                let isDir = (entry.pointee.d_type == DT_DIR)
                var size: Int64 = 0

                if longListing {
                    let subPath = (target == ".") ? name : "\(target)/\(name)"
                    var st = stat()
                    if stat(subPath, &st) == 0 {
                        size = Int64(st.st_size)
                    }
                }
                entries.append((name: name, isDir: isDir, size: size))
            }

            entries.sort { $0.name < $1.name }

            if longListing {
                for e in entries {
                    let typeChar = e.isDir ? "d" : "-"
                    print(String(format: "%srwxr-xr-x  %8lld  %@", typeChar, e.size, e.name))
                }
            } else {
                for e in entries {
                    if e.isDir {
                        print("\u{001B}[1;34m\(e.name)/\u{001B}[0m  ", terminator: "")
                    } else {
                        print("\(e.name)  ", terminator: "")
                    }
                }
                print("")
            }
        }
    }

    // MARK: - cat
    public static func cat(args: [String]) {
        if args.isEmpty {
            // Read from stdin until EOF
            var buf = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = read(STDIN_FILENO, &buf, buf.count)
                if n <= 0 { break }
                write(STDOUT_FILENO, buf, n)
            }
            return
        }

        for path in args {
            let fd = open(path, O_RDONLY)
            if fd < 0 {
                perror("sash: cat: \(path)")
                continue
            }
            var buf = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = read(fd, &buf, buf.count)
                if n <= 0 { break }
                write(STDOUT_FILENO, buf, n)
            }
            close(fd)
        }
    }

    // MARK: - touch
    public static func touch(args: [String]) {
        for path in args {
            if path.hasPrefix("-") { continue }
            let fd = open(path, O_WRONLY | O_CREAT, 0o644)
            if fd >= 0 {
                close(fd)
            } else {
                perror("sash: touch: \(path)")
            }
        }
    }

    // MARK: - mkdir
    public static func mkdir(args: [String]) {
        var createParents = false
        var dirs: [String] = []

        for arg in args {
            if arg == "-p" { createParents = true }
            else if !arg.hasPrefix("-") { dirs.append(arg) }
        }

        for dir in dirs {
            if createParents {
                var current = ""
                for part in dir.split(separator: "/") {
                    current += (current.isEmpty && dir.hasPrefix("/")) ? "/\(part)" : "/\(part)"
                    _ = posix_mkdir(current, 0o755)
                }
            } else {
                if posix_mkdir(dir, 0o755) != 0 {
                    perror("sash: mkdir: \(dir)")
                }
            }
        }
    }

    // MARK: - rmdir
    public static func rmdir(args: [String]) {
        for dir in args {
            if dir.hasPrefix("-") { continue }
            if posix_rmdir(dir) != 0 {
                perror("sash: rmdir: \(dir)")
            }
        }
    }

    // MARK: - rm
    public static func rm(args: [String]) {
        var recursive = false
        var force = false
        var paths: [String] = []

        for arg in args {
            if arg == "-r" || arg == "-R" { recursive = true }
            else if arg == "-f" { force = true }
            else if arg == "-rf" || arg == "-fr" { recursive = true; force = true }
            else if !arg.hasPrefix("-") { paths.append(arg) }
        }

        for path in paths {
            if recursive {
                removeRecursive(path: path, force: force)
            } else {
                if unlink(path) != 0 && !force {
                    perror("sash: rm: \(path)")
                }
            }
        }
    }

    private static func removeRecursive(path: String, force: Bool) {
        var st = stat()
        if lstat(path, &st) != 0 {
            if !force { perror("sash: rm: \(path)") }
            return
        }

        if (st.st_mode & S_IFMT) == S_IFDIR {
            if let dir = opendir(path) {
                while let entry = readdir(dir) {
                    let name = withUnsafePointer(to: &entry.pointee.d_name) { ptr in
                        String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
                    }
                    if name == "." || name == ".." { continue }
                    removeRecursive(path: "\(path)/\(name)", force: force)
                }
                closedir(dir)
            }
            _ = posix_rmdir(path)
        } else {
            _ = unlink(path)
        }
    }

    // MARK: - ps
    public static func ps() {
        guard let dir = opendir("/proc") else {
            print("sash: ps: /proc is not mounted")
            return
        }
        defer { closedir(dir) }

        print(String(format: "%-7s %-8s %-6s %s", "PID", "TTY", "STAT", "CMD"))

        var pids: [Int] = []
        while let entry = readdir(dir) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { ptr in
                String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
            }
            if let pid = Int(name) {
                pids.append(pid)
            }
        }
        pids.sort()

        for pid in pids {
            let cmdlinePath = "/proc/\(pid)/cmdline"
            var cmd = ""
            if let data = try? Data(contentsOf: URL(fileURLWithPath: cmdlinePath)) {
                let parts = data.split(separator: 0).compactMap { String(bytes: $0, encoding: .utf8) }
                cmd = parts.joined(separator: " ")
            }
            if cmd.isEmpty {
                // Read from /proc/[pid]/comm
                if let comm = try? String(contentsOfFile: "/proc/\(pid)/comm") {
                    cmd = "[\(comm.trimmingCharacters(in: .whitespacesAndNewlines))]"
                } else {
                    cmd = "[\(pid)]"
                }
            }
            print(String(format: "%-7d %-8s %-6s %s", pid, "?", "S", cmd))
        }
    }

    // MARK: - free
    public static func free() {
        guard let meminfo = try? String(contentsOfFile: "/proc/meminfo") else {
            print("sash: free: cannot read /proc/meminfo")
            return
        }

        var totalKB: Int64 = 0
        var freeKB: Int64 = 0
        var availKB: Int64 = 0

        for line in meminfo.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0.isWhitespace || $0 == ":" })
            if parts.count >= 2 {
                let key = parts[0]
                if let val = Int64(parts[1]) {
                    if key == "MemTotal" { totalKB = val }
                    else if key == "MemFree" { freeKB = val }
                    else if key == "MemAvailable" { availKB = val }
                }
            }
        }

        print(String(format: "%-12s %10s %10s %10s", "Type", "total", "free", "available"))
        print(String(format: "%-12s %9lldK %9lldK %9lldK", "Mem:", totalKB, freeKB, availKB))
    }

    // MARK: - kill
    public static func kill(args: [String]) {
        var sig: Int32 = SIGTERM
        var targetPid: pid_t = 0

        for arg in args {
            if arg.hasPrefix("-") {
                let sigStr = String(arg.dropFirst())
                if let num = Int32(sigStr) {
                    sig = num
                } else if sigStr == "9" || sigStr == "KILL" {
                    sig = SIGKILL
                } else if sigStr == "15" || sigStr == "TERM" {
                    sig = SIGTERM
                } else if sigStr == "2" || sigStr == "INT" {
                    sig = SIGINT
                }
            } else if let p = Int32(arg) {
                targetPid = p
            }
        }

        guard targetPid > 0 else {
            print("sash: kill: usage: kill [-sig] <pid>")
            return
        }

        if posix_kill(targetPid, sig) != 0 {
            perror("sash: kill: \(targetPid)")
        }
    }

    // MARK: - jobs
    public static func jobs() {
        JobManager.shared.pollCompletedJobs()
        let activeJobs = JobManager.shared.jobs
        if activeJobs.isEmpty {
            print("sash: no active background jobs")
            return
        }
        for job in activeJobs {
            let statusStr = job.isRunning ? "Running" : "Done"
            print("[\(job.id)] + \(job.pid) \(statusStr)  \(job.command)")
        }
    }

    // MARK: - test / [
    public static func test(args: [String]) -> Bool {
        var cleanArgs = args
        if cleanArgs.last == "]" {
            cleanArgs.removeLast()
        }
        if cleanArgs.isEmpty { return false }
        if cleanArgs.count == 1 { return !cleanArgs[0].isEmpty }

        if cleanArgs.count == 2 {
            let op = cleanArgs[0]
            let path = cleanArgs[1]
            var st = stat()
            switch op {
            case "-z": return path.isEmpty
            case "-n": return !path.isEmpty
            case "-e": return stat(path, &st) == 0
            case "-f": return stat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFREG
            case "-d": return stat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR
            default: return false
            }
        }

        if cleanArgs.count == 3 {
            let v1 = cleanArgs[0]
            let op = cleanArgs[1]
            let v2 = cleanArgs[2]
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
        }
        return false
    }
}
