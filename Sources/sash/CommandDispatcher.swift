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
import libark

public class CommandDispatcher {
    public var environment: [String: String] = [:]
    
    public init() {}
    
    @discardableResult
    public func execute(commandLine: String, captureOutput: Bool = false) -> String? {
        let tokens = parse(commandLine)
        guard !tokens.isEmpty else { return nil }
        
        // Check for variable assignment
        let firstToken = tokens[0]
        if firstToken.contains("=") && !firstToken.hasPrefix("=") {
            let parts = firstToken.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let varName = String(parts[0])
                let varValue = String(parts[1])
                environment[varName] = varValue
                return nil
            }
        }
        
        let cmd = tokens[0]
        let args = Array(tokens.dropFirst())
        
        let builtins = ["cd", "pwd", "ls", "cat", "echo", "mkdir", "rmdir", "touch", "rm", "mv", "cp"]
        let isBuiltin = builtins.contains(cmd)
        
        var capturedString: String? = nil
        var originalStdout: Int32 = -1
        var tempFileUrl: URL? = nil
        
        if captureOutput && isBuiltin {
            originalStdout = dup(STDOUT_FILENO)
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let fileUrl = tempDir.appendingPathComponent(UUID().uuidString)
            tempFileUrl = fileUrl
            let fd = open(fileUrl.path, O_RDWR | O_CREAT | O_TRUNC, 0o600)
            if fd >= 0 {
                dup2(fd, STDOUT_FILENO)
                close(fd)
            }
        }
        
        do {
            if isBuiltin {
                switch cmd {
                case "cd": try Builtins.cd(args: args)
                case "pwd": try Builtins.pwd(args: args)
                case "ls": try Builtins.ls(args: args)
                case "cat": try Builtins.cat(args: args)
                case "echo": try Builtins.echo(args: args)
                case "mkdir": try Builtins.mkdir(args: args)
                case "rmdir": try Builtins.rmdir(args: args)
                case "touch": try Builtins.touch(args: args)
                case "rm": try Builtins.rm(args: args)
                case "mv": try Builtins.mv(args: args)
                case "cp": try Builtins.cp(args: args)
                default: break
                }
                
                if captureOutput, let fileUrl = tempFileUrl {
                    fflush(stdout)
                    dup2(originalStdout, STDOUT_FILENO)
                    close(originalStdout)
                    
                    let data = try? Data(contentsOf: fileUrl)
                    try? FileManager.default.removeItem(at: fileUrl)
                    if let data = data {
                        capturedString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines)
                    }
                }
            } else {
                capturedString = executeExternal(cmd: cmd, args: args, captureOutput: captureOutput)
            }
        } catch {
            // Restore stdout if we threw an error while capturing
            if captureOutput && isBuiltin && originalStdout != -1 {
                fflush(stdout)
                dup2(originalStdout, STDOUT_FILENO)
                close(originalStdout)
                if let fileUrl = tempFileUrl {
                    try? FileManager.default.removeItem(at: fileUrl)
                }
            }
            print("sash: \(cmd): error executing - \(error)")
        }
        
        return capturedString
    }
    
    private func executeExternal(cmd: String, args: [String], captureOutput: Bool) -> String? {
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
            return nil
        }
        
        process.executableURL = url
        process.arguments = args
        
        var env = ProcessInfo.processInfo.environment
        for (k, v) in self.environment {
            env[k] = v
        }
        process.environment = env
        
        let pipe = Pipe()
        if captureOutput {
            process.standardOutput = pipe
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if captureOutput {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    return output.trimmingCharacters(in: .newlines)
                }
            }
        } catch {
            print("sash: \(cmd): error executing - \(error)")
        }
        
        return nil
    }
    
    private func parse(_ line: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inSingleQuotes = false
        var inDoubleQuotes = false
        var escapeNext = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if escapeNext {
                currentToken.append(char)
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
                                i = line.index(after: i) // skip first )
                                // i will be incremented by the outer loop for the second )
                            }
                            
                            let evaluator = MathEvaluator()
                            if let res = try? evaluator.evaluate(mathExpr) {
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
                        while i < line.endIndex && (line[i].isLetter || line[i].isNumber || line[i] == "_") {
                            varName.append(line[i])
                            i = line.index(after: i)
                        }
                        if i > line.startIndex {
                            i = line.index(before: i) // step back so the loop advances properly
                        }
                        if let value = environment[varName] {
                            currentToken.append(value)
                        } else if let envVal = getenv(varName) {
                            currentToken.append(String(cString: envVal))
                        }
                    }
                }
            } else if char.isWhitespace {
                if inSingleQuotes || inDoubleQuotes {
                    currentToken.append(char)
                } else {
                    if !currentToken.isEmpty {
                        tokens.append(currentToken)
                        currentToken = ""
                    }
                }
            } else {
                currentToken.append(char)
            }
            
            i = line.index(after: i)
        }
        
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }
        
        return tokens
    }
}
