#if os(Linux)
import Glibc
#else
import Darwin
#endif
import Foundation
import libark

public class CommandDispatcher {
    public var environment: [String: String] = [:]
    public var lastExitStatus: Int = 0
    public var scriptName: String = "sash"
    public var positionalArguments: [String] = []
    public var lastBackgroundPID: Int = 0
    
    public init() {}

    private struct Redirection {
        var type: String // ">", ">>", "2>", ">&2", "2>&1", "<<"
        var target: String 
    }
    
    private struct Command {
        var args: [String]
        var redirections: [Redirection]
    }

    private func splitIntoCommands(_ tokens: [String], by separators: [String]) -> [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        for token in tokens {
            if separators.contains(token) {
                // We don't drop the separator if we want to know what it is?
                // Actually, we do if we split.
                fatalError("Use split with separators kept to maintain logical ops")
            } else {
                current.append(token)
            }
        }
        return result
    }

    @discardableResult
    public func execute(script: String, captureOutput: Bool = false) -> String? {
        let allTokens = parse(script)
        guard !allTokens.isEmpty else { return nil }

        // We will execute tokens via a recursive descent or loop that understands if/then/else/fi and &&/||
        return executeTokens(allTokens, captureOutput: captureOutput)
    }

    @discardableResult
    public func execute(commandLine: String, captureOutput: Bool = false) -> String? {
        return execute(script: commandLine, captureOutput: captureOutput)
    }

    private func executeTokens(_ tokens: [String], captureOutput: Bool) -> String? {
        // Let's iterate through statements.
        // Let's iterate through statements.
        var i = 0
        var lastOutput: String? = nil
        
        while i < tokens.count {
            let token = tokens[i]
            
            if token == ";" {
                i += 1
                continue
            }
            
            if token == "if" {
                // parse condition
                i += 1
                var conditionTokens: [String] = []
                while i < tokens.count && tokens[i] != "then" && tokens[i] != ";" {
                    conditionTokens.append(tokens[i])
                    i += 1
                }
                
                // execute condition
                _ = executePipelineTokens(conditionTokens, captureOutput: false)
                let conditionTrue = (self.lastExitStatus == 0)
                
                // skip 'then' or ';'
                while i < tokens.count && (tokens[i] == "then" || tokens[i] == ";") { i += 1 }
                
                var trueBranch: [String] = []
                var falseBranch: [String] = []
                var inFalseBranch = false
                var nestLevel = 0
                
                while i < tokens.count {
                    if tokens[i] == "if" { nestLevel += 1 }
                    if tokens[i] == "fi" {
                        if nestLevel == 0 { break }
                        nestLevel -= 1
                    }
                    if tokens[i] == "else" && nestLevel == 0 {
                        inFalseBranch = true
                        i += 1
                        continue
                    }
                    if inFalseBranch {
                        falseBranch.append(tokens[i])
                    } else {
                        trueBranch.append(tokens[i])
                    }
                    i += 1
                }
                
                if i < tokens.count && tokens[i] == "fi" { i += 1 } // consume fi
                
                if conditionTrue {
                    lastOutput = executeTokens(trueBranch, captureOutput: captureOutput)
                } else {
                    lastOutput = executeTokens(falseBranch, captureOutput: captureOutput)
                }
                continue
            }
            
            // Collect one logical command (until ;, &&, ||)
            var pipelineTokens: [String] = []
            while i < tokens.count && tokens[i] != ";" && tokens[i] != "&&" && tokens[i] != "||" {
                pipelineTokens.append(tokens[i])
                i += 1
            }
            
            if !pipelineTokens.isEmpty {
                lastOutput = executePipelineTokens(pipelineTokens, captureOutput: captureOutput)
            }
            
            // Handle logical operators
            if i < tokens.count && (tokens[i] == "&&" || tokens[i] == "||") {
                let op = tokens[i]
                i += 1
                
                if (op == "&&" && self.lastExitStatus != 0) || (op == "||" && self.lastExitStatus == 0) {
                    // Skip the next pipeline
                    var nestLevel = 0
                    while i < tokens.count {
                        if tokens[i] == "if" { nestLevel += 1 }
                        if tokens[i] == "fi" && nestLevel > 0 { nestLevel -= 1 }
                        
                        if nestLevel == 0 && (tokens[i] == ";" || tokens[i] == "&&" || tokens[i] == "||") {
                            break
                        }
                        i += 1
                    }
                }
            }
        }
        
        return lastOutput
    }

    private func executePipelineTokens(_ tokens: [String], captureOutput: Bool) -> String? {
        var stages: [[String]] = []
        var current: [String] = []
        for token in tokens {
            if token == "|" {
                stages.append(current)
                current = []
            } else {
                current.append(token)
            }
        }
        if !current.isEmpty { stages.append(current) }
        
        guard !stages.isEmpty else { return nil }
        
        var commands: [Command] = []
        for stageTokens in stages {
            guard !stageTokens.isEmpty else { continue }
            var args: [String] = []
            var redirections: [Redirection] = []
            var i = 0
            while i < stageTokens.count {
                let token = stageTokens[i]
                if token == ">" || token == ">>" || token == "2>" || token == "<<" {
                    if i + 1 < stageTokens.count {
                        redirections.append(Redirection(type: token, target: stageTokens[i+1]))
                        i += 1
                    }
                } else if token == ">&2" || token == "2>&1" {
                    redirections.append(Redirection(type: token, target: ""))
                } else {
                    args.append(token)
                }
                i += 1
            }
            if !args.isEmpty {
                commands.append(Command(args: args, redirections: redirections))
            }
        }
        
        guard !commands.isEmpty else { return nil }

        if commands.count == 1 {
            let firstToken = commands[0].args[0]
            if firstToken.contains("=") && !firstToken.hasPrefix("=") {
                let parts = firstToken.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if parts.count == 2 {
                    environment[String(parts[0])] = String(parts[1])
                    return nil
                }
            }
        }

        let builtins = ["cd", "pwd", "ls", "cat", "say", "mkdir", "rmdir", "touch", "rm", "mv", "cp", "[", "test", "printf", "type", "command", "help"]
        
        var previousPipe: Pipe? = nil
        var capturedString: String? = nil
        var processes: [Process] = []

        var originalStdout: Int32 = -1
        var originalStderr: Int32 = -1
        var originalStdin: Int32 = -1

        for (index, command) in commands.enumerated() {
            var cmd = command.args[0]
            var args = Array(command.args.dropFirst())
            var forceExternal = false
            
            if cmd == "command" {
                if args.first != "-V" && args.first != "-v" {
                    forceExternal = true
                    if !args.isEmpty {
                        cmd = args[0]
                        args = Array(args.dropFirst())
                    } else {
                        // Just 'command' alone, do nothing
                        continue
                    }
                }
            }
            
            let isBuiltin = !forceExternal && builtins.contains(cmd)
            
            let isLast = (index == commands.count - 1)
            let nextPipe = isLast ? nil : Pipe()
            
            var hereDocPipe: Pipe? = nil
            for redir in command.redirections {
                if redir.type == "<<" {
                    hereDocPipe = Pipe()
                    if let data = (redir.target + "\n").data(using: .utf8) {
                        hereDocPipe?.fileHandleForWriting.write(data)
                    }
                    try? hereDocPipe?.fileHandleForWriting.close()
                }
            }

            if isBuiltin {
                originalStdout = dup(STDOUT_FILENO)
                originalStderr = dup(STDERR_FILENO)
                originalStdin = dup(STDIN_FILENO)
                
                if let here = hereDocPipe {
                    dup2(here.fileHandleForReading.fileDescriptor, STDIN_FILENO)
                } else if let prev = previousPipe {
                    dup2(prev.fileHandleForReading.fileDescriptor, STDIN_FILENO)
                }
                if let next = nextPipe {
                    dup2(next.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
                }
                
                var tempFileUrl: URL? = nil
                if captureOutput && isLast {
                    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                    let fileUrl = tempDir.appendingPathComponent(UUID().uuidString)
                    tempFileUrl = fileUrl
                    let fd = open(fileUrl.path, O_RDWR | O_CREAT | O_TRUNC, 0o600)
                    if fd >= 0 {
                        dup2(fd, STDOUT_FILENO)
                        close(fd)
                    }
                }
                
                for redir in command.redirections {
                    if redir.type == ">" || redir.type == ">>" {
                        let flags = redir.type == ">" ? (O_WRONLY | O_CREAT | O_TRUNC) : (O_WRONLY | O_CREAT | O_APPEND)
                        let fd = open(redir.target, flags, 0o644)
                        if fd >= 0 {
                            dup2(fd, STDOUT_FILENO)
                            close(fd)
                        }
                    } else if redir.type == "2>" {
                        let fd = open(redir.target, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
                        if fd >= 0 {
                            dup2(fd, STDERR_FILENO)
                            close(fd)
                        }
                    } else if redir.type == ">&2" {
                        dup2(STDERR_FILENO, STDOUT_FILENO)
                    } else if redir.type == "2>&1" {
                        dup2(STDOUT_FILENO, STDERR_FILENO)
                    }
                }
                
                do {
                    switch cmd {
                    case "cd": try Builtins.cd(args: args)
                    case "pwd": try Builtins.pwd(args: args)
                    case "ls": try Builtins.ls(args: args)
                    case "cat": try Builtins.cat(args: args)
                    case "say": try Builtins.say(args: args)
                    case "mkdir": try Builtins.mkdir(args: args)
                    case "rmdir": try Builtins.rmdir(args: args)
                    case "touch": try Builtins.touch(args: args)
                    case "rm": try Builtins.rm(args: args)
                    case "mv": try Builtins.mv(args: args)
                    case "cp": try Builtins.cp(args: args)
                    case "printf": try Builtins.printf(args: args)
                    case "type": try Builtins.typeCmd(args: args, environment: self.environment)
                    case "command": try Builtins.command(args: args, environment: self.environment)
                    case "help": try Builtins.help(args: args)
                    case "[", "test":
                        let testArgs = cmd == "[" ? Array(args.dropLast()) : args // drop ]
                        self.lastExitStatus = try Builtins.test(args: testArgs) ? 0 : 1
                    default: break
                    }
                    if cmd != "[" && cmd != "test" {
                        self.lastExitStatus = 0
                    }
                } catch {
                    print("sash: \(cmd): error executing - \(error)")
                    self.lastExitStatus = 1
                }
                
                fflush(stdout)
                fflush(stderr)
                dup2(originalStdin, STDIN_FILENO)
                dup2(originalStdout, STDOUT_FILENO)
                dup2(originalStderr, STDERR_FILENO)
                close(originalStdin)
                close(originalStdout)
                close(originalStderr)
                
                if captureOutput && isLast, let fileUrl = tempFileUrl {
                    let data = try? Data(contentsOf: fileUrl)
                    try? FileManager.default.removeItem(at: fileUrl)
                    if let data = data {
                        capturedString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
                    }
                }
                
                if let next = nextPipe {
                    try? next.fileHandleForWriting.close()
                }
            } else {
                let process = Process()
                
                let pathVar = environment["PATH"] ?? getenv("PATH").flatMap { String(cString: $0) } ?? "/bin:/usr/bin"
                let paths = ["/system/apps", "/arkrt/apps"] + pathVar.split(separator: ":").map(String.init)
                
                var executableURL: URL? = nil
                if cmd.hasPrefix("/") || cmd.hasPrefix("./") || cmd.hasPrefix("../") {
                    executableURL = URL(fileURLWithPath: cmd)
                } else {
                    for path in paths {
                        let fullPath = path + "/" + cmd
                        if FileManager.default.isExecutableFile(atPath: fullPath) {
                            executableURL = URL(fileURLWithPath: fullPath)
                            break
                        }
                    }
                }
                
                guard let url = executableURL else {
                    print("sash: command not found: \(cmd)")
                    self.lastExitStatus = 127
                    if let next = nextPipe { try? next.fileHandleForWriting.close() }
                    previousPipe = nextPipe
                    continue
                }
                
                process.executableURL = url
                process.arguments = args
                
                var env = ProcessInfo.processInfo.environment
                for (k, v) in self.environment {
                    env[k] = v
                }
                process.environment = env
                
                if let here = hereDocPipe {
                    process.standardInput = here
                } else if let prev = previousPipe {
                    process.standardInput = prev
                }
                
                var capturePipe: Pipe? = nil
                if let next = nextPipe {
                    process.standardOutput = next
                } else if captureOutput && isLast {
                    capturePipe = Pipe()
                    process.standardOutput = capturePipe
                }
                
                for redir in command.redirections {
                    if redir.type == ">" || redir.type == ">>" {
                        let flags = redir.type == ">" ? (O_WRONLY | O_CREAT | O_TRUNC) : (O_WRONLY | O_CREAT | O_APPEND)
                        if let fd = try? FileDescriptor.open(path: Path(redir.target), flags: flags, mode: 0o644) {
                            let handle = FileHandle(fileDescriptor: fd.rawValue, closeOnDealloc: true)
                            process.standardOutput = handle
                        }
                    } else if redir.type == "2>" {
                        let flags = O_WRONLY | O_CREAT | O_TRUNC
                        if let fd = try? FileDescriptor.open(path: Path(redir.target), flags: flags, mode: 0o644) {
                            let handle = FileHandle(fileDescriptor: fd.rawValue, closeOnDealloc: true)
                            process.standardError = handle
                        }
                    } else if redir.type == ">&2" {
                        process.standardOutput = process.standardError
                    } else if redir.type == "2>&1" {
                        process.standardError = process.standardOutput
                    }
                }
                
                do {
                    try process.run()
                    processes.append(process)
                } catch {
                    print("sash: \(cmd): error executing - \(error)")
                    self.lastExitStatus = 1
                }
                
                if let next = nextPipe {
                    try? next.fileHandleForWriting.close()
                }
                
                if captureOutput && isLast, let outPipe = capturePipe {
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    capturedString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
                }
            }
            
            previousPipe = nextPipe
        }
        
        for process in processes {
            process.waitUntilExit()
            self.lastExitStatus = Int(process.terminationStatus)
        }
        
        return capturedString
    }


    
    private func expandBraces(_ str: String) -> [String] {
        if !str.contains("{") || !str.contains("}") { return [str] }
        
        let chars = Array(str)
        var openIdx = -1
        var closeIdx = -1
        var nest = 0
        var i = 0
        
        while i < chars.count {
            if chars[i] == "{" {
                if nest == 0 { openIdx = i }
                nest += 1
            } else if chars[i] == "}" {
                if nest > 0 {
                    nest -= 1
                    if nest == 0 {
                        closeIdx = i
                        let inside = String(chars[(openIdx+1)..<closeIdx])
                        
                        var isRange = false
                        let parts = inside.components(separatedBy: "..")
                        if parts.count == 2, let _ = Int(parts[0]), let _ = Int(parts[1]) {
                            isRange = true
                        }
                        
                        var hasComma = false
                        var insideNest = 0
                        for char in inside {
                            if char == "{" { insideNest += 1 }
                            else if char == "}" { insideNest -= 1 }
                            else if char == "," && insideNest == 0 {
                                hasComma = true
                                break
                            }
                        }
                        
                        if isRange || hasComma {
                            break
                        } else {
                            openIdx = -1
                            closeIdx = -1
                        }
                    }
                }
            }
            i += 1
        }
        
        if openIdx == -1 || closeIdx == -1 {
            return [str]
        }
        
        let prefix = String(chars[0..<openIdx])
        let suffix = String(chars[(closeIdx+1)...])
        let insideStr = String(chars[(openIdx+1)..<closeIdx])
        
        let parts = insideStr.components(separatedBy: "..")
        if parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]) {
            var results: [String] = []
            let step = start <= end ? 1 : -1
            var current = start
            while true {
                let expandedStr = prefix + String(current) + suffix
                results.append(contentsOf: expandBraces(expandedStr))
                if current == end { break }
                current += step
            }
            return results
        }
        
        var items: [String] = []
        var currentItem = ""
        var insideNest = 0
        for char in insideStr {
            if char == "{" { insideNest += 1 }
            else if char == "}" { insideNest -= 1 }
            
            if char == "," && insideNest == 0 {
                items.append(currentItem)
                currentItem = ""
            } else {
                currentItem.append(char)
            }
        }
        items.append(currentItem)
        
        var results: [String] = []
        for item in items {
            let expandedStr = prefix + item + suffix
            results.append(contentsOf: expandBraces(expandedStr))
        }
        return results
    }

    private func parse(_ line: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inSingleQuotes = false
        var inDoubleQuotes = false
        var escapeNext = false
        var hasUnquotedWildcard = false
        
        func flushToken() {
            if !currentToken.isEmpty {
                if currentToken.hasPrefix("~") {
                    let home = environment["HOME"] ?? getenv("HOME").flatMap { String(cString: $0) } ?? "/home/" + (environment["USER"] ?? getenv("USER").flatMap { String(cString: $0) } ?? "user")
                    if currentToken == "~" {
                        currentToken = home
                    } else if currentToken.hasPrefix("~/") {
                        currentToken = home + String(currentToken.dropFirst())
                    }
                }
                
                let expanded = expandBraces(currentToken)
                
                if hasUnquotedWildcard {
                    for token in expanded {
                        var g = glob_t()
                        let result = glob(token, 0, nil, &g)
                        if result == 0 {
                            for j in 0..<Int(g.gl_pathc) {
                                if let ptr = g.gl_pathv[j] {
                                    tokens.append(String(cString: ptr))
                                }
                            }
                        } else {
                            tokens.append(token)
                        }
                        globfree(&g)
                    }
                } else {
                    tokens.append(contentsOf: expanded)
                }
                currentToken = ""
                hasUnquotedWildcard = false
            }
        }
        
        var i = line.startIndex
        while i < line.endIndex {
            let char = line[i]
            
            if escapeNext {
                if inDoubleQuotes {
                    if char == "\"" || char == "$" || char == "\\" || char == "`" {
                        currentToken.append(char)
                    } else {
                        currentToken.append("\\")
                        currentToken.append(char)
                    }
                } else {
                    currentToken.append(char)
                }
                escapeNext = false
            } else if char == "\\" {
                if inSingleQuotes {
                    currentToken.append(char)
                } else {
                    escapeNext = true
                }
            } else if char == "'" {
                if inDoubleQuotes {
                    currentToken.append(char)
                } else {
                    inSingleQuotes.toggle()
                }
            } else if char == "\"" {
                if inSingleQuotes {
                    currentToken.append(char)
                } else {
                    inDoubleQuotes.toggle()
                }
            } else if char == "`" {
                if inSingleQuotes {
                    currentToken.append(char)
                } else {
                    var subCmd = ""
                    i = line.index(after: i)
                    while i < line.endIndex && line[i] != "`" {
                        subCmd.append(line[i])
                        i = line.index(after: i)
                    }
                    if let out = execute(commandLine: subCmd, captureOutput: true) {
                        currentToken.append(out)
                    }
                }
            } else if char == "$" {
                if inSingleQuotes {
                    currentToken.append(char)
                } else {
                    i = line.index(after: i)
                    if i < line.endIndex && line[i] == "(" {
                        i = line.index(after: i)
                        if i < line.endIndex && line[i] == "(" {
                            // Arithmetic expansion: $(( ... ))
                            i = line.index(after: i)
                            var mathExpr = ""
                            while i < line.endIndex && !(line[i] == ")" && line.index(after: i) < line.endIndex && line[line.index(after: i)] == ")") {
                                mathExpr.append(line[i])
                                i = line.index(after: i)
                            }
                            if i < line.endIndex {
                                i = line.index(after: i)
                            }
                            
                            let evaluator = MathEvaluator()
                            if let res = try? evaluator.evaluate(mathExpr, variables: self.environment) {
                                currentToken.append(String(res))
                            } else {
                                print("sash: error evaluating arithmetic: \(mathExpr)")
                            }
                        } else {
                            // Command substitution: $( ... )
                            var subCmd = ""
                            while i < line.endIndex && line[i] != ")" {
                                subCmd.append(line[i])
                                i = line.index(after: i)
                            }
                            if let out = execute(commandLine: subCmd, captureOutput: true) {
                                currentToken.append(out)
                            }
                        }
                    } else if i < line.endIndex && line[i] == "{" {
                        // ${var}
                        var varName = ""
                        i = line.index(after: i)
                        while i < line.endIndex && line[i] != "}" {
                            varName.append(line[i])
                            i = line.index(after: i)
                        }
                        if let value = environment[varName] {
                            currentToken.append(value)
                        } else if let envVal = getenv(varName) {
                            currentToken.append(String(cString: envVal))
                        }
                    } else {
                        // $var
                        var varName = ""
                        var isSpecial = false
                        if i < line.endIndex {
                            let nextChar = line[i]
                            if nextChar == "?" || nextChar == "$" || nextChar == "!" || nextChar == "#" || nextChar == "@" || nextChar == "*" || nextChar.isNumber {
                                varName.append(nextChar)
                                i = line.index(after: i)
                                isSpecial = true
                                if nextChar.isNumber {
                                    while i < line.endIndex && line[i].isNumber {
                                        varName.append(line[i])
                                        i = line.index(after: i)
                                    }
                                }
                            } else {
                                while i < line.endIndex && (line[i].isLetter || line[i].isNumber || line[i] == "_") {
                                    varName.append(line[i])
                                    i = line.index(after: i)
                                }
                            }
                        }
                        
                        if i > line.startIndex {
                            i = line.index(before: i) 
                        }
                        
                        if isSpecial {
                            if varName == "?" {
                                currentToken.append(String(self.lastExitStatus))
                            } else if varName == "$" {
                                currentToken.append(String(getpid()))
                            } else if varName == "!" {
                                currentToken.append(String(self.lastBackgroundPID))
                            } else if varName == "#" {
                                currentToken.append(String(self.positionalArguments.count))
                            } else if varName == "@" || varName == "*" {
                                currentToken.append(self.positionalArguments.joined(separator: " "))
                            } else if varName == "0" {
                                currentToken.append(self.scriptName)
                            } else if let num = Int(varName), num > 0 {
                                if num <= self.positionalArguments.count {
                                    currentToken.append(self.positionalArguments[num - 1])
                                }
                            }
                        } else if let value = environment[varName] {
                            currentToken.append(value)
                        } else if let envVal = getenv(varName) {
                            currentToken.append(String(cString: envVal))
                        }
                    }
                }
            } else if (char == "*" || char == "?") && !inSingleQuotes && !inDoubleQuotes {
                hasUnquotedWildcard = true
                currentToken.append(char)
            } else if (char.isWhitespace || char == "\n") && !inSingleQuotes && !inDoubleQuotes {
                flushToken()
                if char == "\n" {
                    tokens.append(";")
                }
            } else if !inSingleQuotes && !inDoubleQuotes && (char == "|" || char == ";" || char == ">" || char == "&" || char == "<") {
                // Handle unquoted operators
                flushToken()
                var op = String(char)
                if char == ">" {
                    if i < line.endIndex && line.index(after: i) < line.endIndex && line[line.index(after: i)] == ">" {
                        op = ">>"
                        i = line.index(after: i)
                    } else if i < line.endIndex && line.index(after: i) < line.endIndex && line[line.index(after: i)] == "&" {
                        i = line.index(after: i)
                        if i < line.endIndex && line.index(after: i) < line.endIndex && line[line.index(after: i)] == "2" {
                            op = ">&2"
                            i = line.index(after: i)
                        } else {
                            op = ">&" // fallback
                        }
                    }
                } else if char == "&" {
                    if i < line.endIndex && line.index(after: i) < line.endIndex && line[line.index(after: i)] == "&" {
                        op = "&&"
                        i = line.index(after: i)
                    }
                } else if char == "|" {
                    if i < line.endIndex && line.index(after: i) < line.endIndex && line[line.index(after: i)] == "|" {
                        op = "||"
                        i = line.index(after: i)
                    }
                } else if char == "<" {
                    if i < line.endIndex && line.index(after: i) < line.endIndex && line[line.index(after: i)] == "<" {
                        op = "<<"
                        i = line.index(after: i)
                    }
                }
                
                tokens.append(op)
            } else {
                currentToken.append(char)
            }
            
            i = line.index(after: i)
        }
        
        flushToken()
        
        var finalTokens: [String] = []
        var t = 0
        while t < tokens.count {
            if t + 1 < tokens.count && tokens[t] == "2" && tokens[t+1] == ">" {
                finalTokens.append("2>")
                t += 2
                continue
            }
            if t + 2 < tokens.count && tokens[t] == "2" && tokens[t+1] == ">&" && tokens[t+2] == "1" {
                finalTokens.append("2>&1")
                t += 3
                continue
            }
            if t + 1 < tokens.count && tokens[t] == ">&" && tokens[t+1] == "2" {
                finalTokens.append(">&2")
                t += 2
                continue
            }
            
            // Collect Here-Doc immediately
            if tokens[t] == "<<" && t + 1 < tokens.count {
                let delimiter = tokens[t+1]
                finalTokens.append("<<")
                t += 2
                
                // Read lines from original line up to delimiter!
                // Wait! Since parse is given the ENTIRE script (with newlines preserved as ;)
                // we can't easily extract the raw text here because we already tokenized it!
                // Better approach: when we find <<, we just accumulate tokens into a single string until the delimiter token.
                var hereDocText = ""
                while t < tokens.count {
                    if tokens[t] == delimiter {
                        t += 1 // consume delimiter
                        break
                    }
                    if tokens[t] == ";" {
                        hereDocText += "\n"
                    } else {
                        if !hereDocText.isEmpty && !hereDocText.hasSuffix("\n") {
                            hereDocText += " "
                        }
                        hereDocText += tokens[t]
                    }
                    t += 1
                }
                finalTokens.append(hereDocText)
                continue
            }
            
            finalTokens.append(tokens[t])
            t += 1
        }
        
        return finalTokens
    }
}
