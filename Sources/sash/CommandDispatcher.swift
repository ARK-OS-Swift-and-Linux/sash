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
    public init() {}
    
    public func execute(commandLine: String) {
        // Very basic parsing for spaces
        let parts = commandLine.split(separator: " ").map(String.init)
        guard let cmd = parts.first else { return }
        let args = Array(parts.dropFirst())
        
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
}
