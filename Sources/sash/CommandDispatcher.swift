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

public class CommandDispatcher {
    public var environment: [String: String] = [:]
    
    public init() {}
    
    public func execute(commandLine: String) {
        let tokens = parse(commandLine)
        guard !tokens.isEmpty else { return }
        
        // Check for variable assignment
        let firstToken = tokens[0]
        if firstToken.contains("=") && !firstToken.hasPrefix("=") {
            let parts = firstToken.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let varName = String(parts[0])
                let varValue = String(parts[1])
                environment[varName] = varValue
                return // just assignment
            }
        }
        
        let cmd = tokens[0]
        let args = Array(tokens.dropFirst())
        
        do {
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
            default:
                print("sash: command not found: \(cmd)")
            }
        } catch {
            print("sash: \(cmd): error executing - \(error)")
        }
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
            } else if char == "$" {
                if inSingleQuotes {
                    currentToken.append(char)
                } else {
                    // Variable expansion
                    var varName = ""
                    i = line.index(after: i)
                    if i < line.endIndex && line[i] == "{" {
                        // ${var}
                        i = line.index(after: i)
                        while i < line.endIndex && line[i] != "}" {
                            varName.append(line[i])
                            i = line.index(after: i)
                        }
                    } else {
                        // $var
                        while i < line.endIndex && (line[i].isLetter || line[i].isNumber || line[i] == "_") {
                            varName.append(line[i])
                            i = line.index(after: i)
                        }
                        if i > line.startIndex {
                            i = line.index(before: i) // step back so the loop advances properly
                        }
                    }
                    if let value = environment[varName] {
                        currentToken.append(value)
                    } else if let envVal = getenv(varName) { // fallback to OS environment
                        currentToken.append(String(cString: envVal))
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
