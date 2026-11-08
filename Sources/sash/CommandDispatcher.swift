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

public final class CommandDispatcher {
    public var environment: [String: String] = [:]
    public var lastExitStatus: Int = 0
    public var lastBackgroundPID: Int = 0
    public var shouldExit: Bool = false
    public var exitCode: Int32 = 0

    public init() {
        // Initialize environment from host ProcessInfo
        for (k, v) in ProcessInfo.processInfo.environment {
            environment[k] = v
        }
        if environment["PATH"] == nil {
            environment["PATH"] = "/sbin:/bin:/usr/bin"
        }
    }

    private struct Redirection {
        let op: String      // ">", ">>", "<", "2>", "2>&1"
        let target: String
    }

    private struct SingleCommand {
        var args: [String]
        var redirections: [Redirection]
        var isBackground: Bool
    }

    /// Execute a multi-line script or compound statement.
    public func execute(script: String) {
        let lines = script.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            execute(commandLine: trimmed)
            if shouldExit { break }
        }
    }

    /// Execute a single command line, handling ;, &&, ||.
    public func execute(commandLine: String) {
        JobManager.shared.pollCompletedJobs()

        let trimmed = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }

        // Tokenize top-level line splitting by ; or && or ||
        let tokens = tokenize(trimmed)
        if tokens.isEmpty { return }

        var i = 0
        while i < tokens.count {
            var cmdTokens: [String] = []
            var nextOp = ";"

            while i < tokens.count {
                let t = tokens[i]
                if t == ";" || t == "&&" || t == "||" {
                    nextOp = t
                    i += 1
                    break
                }
                cmdTokens.append(t)
                i += 1
            }

            if !cmdTokens.isEmpty {
                executePipelineTokens(cmdTokens)
            }

            if nextOp == "&&" && lastExitStatus != 0 {
                // Skip next command
                while i < tokens.count && tokens[i] != ";" && tokens[i] != "||" {
                    i += 1
                }
                if i < tokens.count && tokens[i] == ";" { i += 1 }
            } else if nextOp == "||" && lastExitStatus == 0 {
                // Skip next command
                while i < tokens.count && tokens[i] != ";" && tokens[i] != "&&" {
                    i += 1
                }
                if i < tokens.count && tokens[i] == ";" { i += 1 }
            }

            if shouldExit { break }
        }
    }

    private func executePipelineTokens(_ tokens: [String]) {
        // Split by pipe '|'
        var stages: [[String]] = []
        var current: [String] = []

        for token in tokens {
            if token == "|" {
                if !current.isEmpty {
                    stages.append(current)
                    current = []
                }
            } else {
                current.append(token)
            }
        }
        if !current.isEmpty {
            stages.append(current)
        }

        if stages.isEmpty { return }

        if stages.count == 1 {
            // Single command
            let cmd = parseSingleCommand(stages[0])
            executeSingleCommand(cmd)
        } else {
            // Pipeline of 2 or more commands
            executePipeline(stages: stages.map { parseSingleCommand($0) })
        }
    }

    private func parseSingleCommand(_ tokens: [String]) -> SingleCommand {
        var args: [String] = []
        var redirections: [Redirection] = []
        var isBackground = false
        var i = 0

        while i < tokens.count {
            let t = tokens[i]
            if t == "&" {
                isBackground = true
                i += 1
            } else if t == ">" || t == ">>" || t == "<" || t == "2>" {
                if i + 1 < tokens.count {
                    redirections.append(Redirection(op: t, target: tokens[i + 1]))
                    i += 2
                } else {
                    i += 1
                }
            } else if t == "2>&1" {
                redirections.append(Redirection(op: t, target: ""))
                i += 1
            } else {
                args.append(t)
                i += 1
            }
        }

        return SingleCommand(args: args, redirections: redirections, isBackground: isBackground)
    }

    private func executeSingleCommand(_ cmd: SingleCommand) {
        guard !cmd.args.isEmpty else { return }

        let first = cmd.args[0]

        // Check for variable assignment: VAR=VAL
        if cmd.args.count == 1 && first.contains("=") && !first.hasPrefix("=") {
            let parts = first.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                environment[String(parts[0])] = String(parts[1])
                lastExitStatus = 0
                return
            }
        }

        // Check for export VAR=VAL or export VAR
        if first == "export" {
            if cmd.args.count > 1 {
                for arg in cmd.args.dropFirst() {
                    let parts = arg.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                    if parts.count == 2 {
                        environment[String(parts[0])] = String(parts[1])
                    }
                }
            } else {
                for (k, v) in environment.sorted(by: { $0.key < $1.key }) {
                    print("export \(k)=\"\(v)\"")
                }
            }
            lastExitStatus = 0
            return
        }

        // Check for exit
        if first == "exit" {
            shouldExit = true
            if cmd.args.count > 1, let code = Int32(cmd.args[1]) {
                exitCode = code
            } else {
                exitCode = Int32(lastExitStatus)
            }
            return
        }

        // Check for builtin commands
        if Builtins.builtinList.contains(first) {
            executeBuiltin(cmd)
            return
        }

        // External executable execution
        executeExternal(cmd)
    }

    private func executeBuiltin(_ cmd: SingleCommand) {
        let name = cmd.args[0]
        let args = Array(cmd.args.dropFirst())

        // Save original descriptors if redirection requested
        var savedStdout: Int32 = -1
        var savedStderr: Int32 = -1
        var savedStdin: Int32 = -1

        if !cmd.redirections.isEmpty {
            savedStdout = dup(STDOUT_FILENO)
            savedStderr = dup(STDERR_FILENO)
            savedStdin = dup(STDIN_FILENO)
            applyRedirections(cmd.redirections)
        }

        switch name {
        case "help":
            Builtins.help(args: args)
            lastExitStatus = 0
        case "cd":
            Builtins.cd(args: args, environment: &self.environment)
            lastExitStatus = 0
        case "pwd":
            Builtins.pwd(args: args)
            lastExitStatus = 0
        case "ls":
            Builtins.ls(args: args)
            lastExitStatus = 0
        case "cat":
            Builtins.cat(args: args)
            lastExitStatus = 0
        case "echo", "say":
            Builtins.echo(args: args)
            lastExitStatus = 0
        case "mkdir":
            Builtins.mkdir(args: args)
            lastExitStatus = 0
        case "rmdir":
            Builtins.rmdir(args: args)
            lastExitStatus = 0
        case "touch":
            Builtins.touch(args: args)
            lastExitStatus = 0
        case "rm":
            Builtins.rm(args: args)
            lastExitStatus = 0
        case "clear":
            Builtins.clear()
            lastExitStatus = 0
        case "uname":
            Builtins.uname(args: args)
            lastExitStatus = 0
        case "ps":
            Builtins.ps()
            lastExitStatus = 0
        case "free":
            Builtins.free()
            lastExitStatus = 0
        case "kill":
            Builtins.kill(args: args)
            lastExitStatus = 0
        case "jobs":
            Builtins.jobs()
            lastExitStatus = 0
        case "test", "[":
            let passed = Builtins.test(args: args)
            lastExitStatus = passed ? 0 : 1
        default:
            print("sash: \(name): builtin not implemented")
            lastExitStatus = 1
        }

        if !cmd.redirections.isEmpty {
            fflush(stdout)
            fflush(stderr)
            dup2(savedStdout, STDOUT_FILENO)
            dup2(savedStderr, STDERR_FILENO)
            dup2(savedStdin, STDIN_FILENO)
            close(savedStdout)
            close(savedStderr)
            close(savedStdin)
        }
    }

    private func executeExternal(_ cmd: SingleCommand) {
        let binaryName = cmd.args[0]
        guard let binaryPath = resolveExecutable(binaryName) else {
            print("sash: \(binaryName): command not found")
            lastExitStatus = 127
            return
        }

        let pid = fork()
        if pid == 0 {
            // Child process
            setpgid(0, 0)
            if !cmd.isBackground && JobManager.shared.isInteractive {
                tcsetpgrp(STDIN_FILENO, getpid())
            }

            // Restore default signal handling
            signal(SIGINT, SIG_DFL)
            signal(SIGQUIT, SIG_DFL)
            signal(SIGTSTP, SIG_DFL)
            signal(SIGTTIN, SIG_DFL)
            signal(SIGTTOU, SIG_DFL)

            applyRedirections(cmd.redirections)

            // Prepare argv and envp
            var cArgs: [UnsafeMutablePointer<CChar>?] = cmd.args.map { strdup($0) }
            cArgs.append(nil)

            var envStrings: [String] = []
            for (k, v) in environment {
                envStrings.append("\(k)=\(v)")
            }
            var cEnv: [UnsafeMutablePointer<CChar>?] = envStrings.map { strdup($0) }
            cEnv.append(nil)

            execve(binaryPath, &cArgs, &cEnv)
            perror("sash: execve \(binaryPath)")
            _exit(126)
        } else if pid > 0 {
            // Parent process
            setpgid(pid, pid)

            if cmd.isBackground {
                let job = JobManager.shared.addJob(pid: pid, command: cmd.args.joined(separator: " "))
                lastBackgroundPID = Int(pid)
                print("[\(job.id)] \(pid)")
                lastExitStatus = 0
            } else {
                let code = JobManager.shared.putJobInForeground(pgid: pid)
                lastExitStatus = Int(code)
            }
        } else {
            perror("sash: fork")
            lastExitStatus = 1
        }
    }

    private func executePipeline(stages: [SingleCommand]) {
        let stageCount = stages.count
        var pipes = [[Int32]](repeating: [-1, -1], count: stageCount - 1)

        for i in 0..<(stageCount - 1) {
            var fds: [Int32] = [0, 0]
            if pipe(&fds) != 0 {
                perror("sash: pipe")
                lastExitStatus = 1
                return
            }
            pipes[i] = fds
        }

        var pids: [pid_t] = []
        var pipelinePgid: pid_t = 0

        for i in 0..<stageCount {
            let cmd = stages[i]
            let pid = fork()

            if pid == 0 {
                // Child
                if i == 0 {
                    setpgid(0, 0)
                } else {
                    setpgid(0, pipelinePgid)
                }

                if JobManager.shared.isInteractive {
                    tcsetpgrp(STDIN_FILENO, getpgrp())
                }

                // Connect read end of previous pipe
                if i > 0 {
                    dup2(pipes[i - 1][0], STDIN_FILENO)
                }
                // Connect write end of next pipe
                if i < stageCount - 1 {
                    dup2(pipes[i][1], STDOUT_FILENO)
                }

                // Close all pipes in child
                for p in pipes {
                    close(p[0])
                    close(p[1])
                }

                applyRedirections(cmd.redirections)

                if Builtins.builtinList.contains(cmd.args[0]) {
                    executeBuiltin(cmd)
                    _exit(Int32(lastExitStatus))
                } else {
                    guard let binaryPath = resolveExecutable(cmd.args[0]) else {
                        print("sash: \(cmd.args[0]): command not found")
                        _exit(127)
                    }
                    var cArgs: [UnsafeMutablePointer<CChar>?] = cmd.args.map { strdup($0) }
                    cArgs.append(nil)
                    var cEnv: [UnsafeMutablePointer<CChar>?] = environment.map { strdup("\($0.key)=\($0.value)") }
                    cEnv.append(nil)
                    execve(binaryPath, &cArgs, &cEnv)
                    _exit(126)
                }
            } else if pid > 0 {
                // Parent
                if i == 0 {
                    pipelinePgid = pid
                }
                setpgid(pid, pipelinePgid)
                pids.append(pid)
            } else {
                perror("sash: pipeline fork")
            }
        }

        // Close all pipe fds in parent
        for p in pipes {
            close(p[0])
            close(p[1])
        }

        if JobManager.shared.isInteractive {
            tcsetpgrp(STDIN_FILENO, pipelinePgid)
        }

        var finalCode: Int32 = 0
        for pid in pids {
            var status: Int32 = 0
            while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
            if pid == pids.last {
                if (status & 0x7f) == 0 {
                    finalCode = (status >> 8) & 0xff
                } else {
                    finalCode = 128 + (status & 0x7f)
                }
            }
        }

        if JobManager.shared.isInteractive {
            tcsetpgrp(STDIN_FILENO, JobManager.shared.shellPGID)
        }

        lastExitStatus = Int(finalCode)
    }

    private func applyRedirections(_ redirections: [Redirection]) {
        for redir in redirections {
            switch redir.op {
            case ">":
                let fd = open(redir.target, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
                if fd >= 0 {
                    dup2(fd, STDOUT_FILENO)
                    close(fd)
                } else {
                    perror("sash: \(redir.target)")
                }
            case ">>":
                let fd = open(redir.target, O_WRONLY | O_CREAT | O_APPEND, 0o644)
                if fd >= 0 {
                    dup2(fd, STDOUT_FILENO)
                    close(fd)
                } else {
                    perror("sash: \(redir.target)")
                }
            case "<":
                let fd = open(redir.target, O_RDONLY)
                if fd >= 0 {
                    dup2(fd, STDIN_FILENO)
                    close(fd)
                } else {
                    perror("sash: \(redir.target)")
                }
            case "2>":
                let fd = open(redir.target, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
                if fd >= 0 {
                    dup2(fd, STDERR_FILENO)
                    close(fd)
                } else {
                    perror("sash: \(redir.target)")
                }
            case "2>&1":
                dup2(STDOUT_FILENO, STDERR_FILENO)
            default:
                break
            }
        }
    }

    private func resolveExecutable(_ name: String) -> String? {
        if name.contains("/") {
            if access(name, X_OK) == 0 {
                return name
            }
            return nil
        }

        let pathVar = environment["PATH"] ?? "/sbin:/bin:/usr/bin"
        for dir in pathVar.split(separator: ":") {
            let candidate = "\(dir)/\(name)"
            if access(candidate, X_OK) == 0 {
                return candidate
            }
        }
        return nil
    }

    /// Tokenize command line with variable substitution and quotation handling.
    private func tokenize(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escape = false

        func flush() {
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }

        var i = line.startIndex
        while i < line.endIndex {
            let char = line[i]

            if escape {
                current.append(char)
                escape = false
            } else if char == "\\" && !inSingle {
                escape = true
            } else if char == "'" && !inDouble {
                inSingle.toggle()
            } else if char == "\"" && !inSingle {
                inDouble.toggle()
            } else if char == "$" && !inSingle {
                // Expand variable
                i = line.index(after: i)
                if i < line.endIndex && line[i] == "?" {
                    current.append(String(lastExitStatus))
                } else if i < line.endIndex && line[i] == "$" {
                    current.append(String(getpid()))
                } else if i < line.endIndex && line[i] == "!" {
                    current.append(String(lastBackgroundPID))
                } else {
                    var varName = ""
                    while i < line.endIndex && (line[i].isLetter || line[i].isNumber || line[i] == "_") {
                        varName.append(line[i])
                        i = line.index(after: i)
                    }
                    if let val = environment[varName] {
                        current.append(val)
                    } else if let sysVal = getenv(varName) {
                        current.append(String(cString: sysVal))
                    }
                    continue
                }
            } else if (char.isWhitespace) && !inSingle && !inDouble {
                flush()
            } else if (char == ";" || char == "|" || char == ">" || char == "<" || char == "&") && !inSingle && !inDouble {
                flush()
                var op = String(char)
                let nextIdx = line.index(after: i)
                if nextIdx < line.endIndex {
                    let nextChar = line[nextIdx]
                    if (char == ">" && nextChar == ">") ||
                       (char == "&" && nextChar == "&") ||
                       (char == "|" && nextChar == "|") {
                        op.append(nextChar)
                        i = nextIdx
                    }
                }
                tokens.append(op)
            } else {
                current.append(char)
            }

            i = line.index(after: i)
        }
        flush()
        return tokens
    }
}
