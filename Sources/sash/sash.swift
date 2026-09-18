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

import Glibc
import libark
import Foundation
import LineNoise

@main
struct sash {
    static func main() {
        let dispatcher = CommandDispatcher()
        let args = CommandLine.arguments
        if args.count > 1 {
            if args[1] == "-c" && args.count > 2 {
                dispatcher.execute(commandLine: args[2])
                return
            }
            let scriptPath = args[1]
            dispatcher.scriptName = scriptPath
            dispatcher.positionalArguments = Array(args.dropFirst(2))
            
            if let fullScript = try? String(contentsOfFile: scriptPath) {
                dispatcher.execute(script: fullScript)
            } else {
                print("sash: cannot read file: \(scriptPath)")
            }
            return
        }

        print("sash 1.0 - The ARK-OS shell")
        let ln = LineNoise()
        
        // Try to read ~/.sashconf.ark
        if let home = getenv("HOME").flatMap({ String(cString: $0) }) {
            let confPath = home + "/.sashconf.ark"
            if let fullScript = try? String(contentsOfFile: confPath) {
                dispatcher.execute(script: fullScript)
            }
        }
        
        while true {
            var cwd = [CChar](repeating: 0, count: 1024)
            getcwd(&cwd, 1024)
            let cwdStr = String(cString: cwd)
            
            var ps1 = dispatcher.environment["PS1"] ?? "\\w $ "
            ps1 = ps1.replacingOccurrences(of: "\\w", with: cwdStr)
            
            let prompt = ps1
            
            let line: String
            do {
                if isatty(STDIN_FILENO) == 1 {
                    line = try ln.getLine(prompt: prompt)
                } else {
                    guard let r = readLine() else {
                        break
                    }
                    line = r
                }
            } catch {
                print("exit")
                break
            }
            
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            ln.addHistory(trimmed)
            
            if trimmed == "exit" {
                break
            }
            
            dispatcher.execute(commandLine: trimmed)
        }
    }
}
