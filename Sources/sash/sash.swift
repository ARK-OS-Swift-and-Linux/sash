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

@main
struct sash {
    static func main() {
        // Ensure immediate interactive console output
        setbuf(stdout, nil)
        setbuf(stderr, nil)

        let dispatcher = CommandDispatcher()
        let args = CommandLine.arguments

        // If command-line string execution requested (-c "...")
        if args.count > 2 && args[1] == "-c" {
            dispatcher.execute(commandLine: args[2])
            exit(dispatcher.exitCode)
        }

        // If executing a script file
        if args.count > 1 && !args[1].hasPrefix("-") {
            let scriptPath = args[1]
            if let content = try? String(contentsOfFile: scriptPath) {
                dispatcher.execute(script: content)
                exit(dispatcher.exitCode)
            } else {
                print("sash: cannot open script: \(scriptPath)")
                exit(1)
            }
        }

        // Interactive shell mode
        JobManager.shared.initialize(terminalFd: STDIN_FILENO)

        let isInteractive = JobManager.shared.isInteractive

        if isInteractive {
            print("==================================================")
            print("sash 1.0 - ARK-OS Interactive Shell")
            print("Type 'help' for builtins, 'exit' to terminate.")
            print("==================================================")
        }

        // Try reading ~/.sashrc or /etc/ark/sashrc if present
        if let rc = try? String(contentsOfFile: "/etc/ark/sashrc") {
            dispatcher.execute(script: rc)
        }

        while !dispatcher.shouldExit {
            // Reap any finished background jobs before displaying prompt
            JobManager.shared.pollCompletedJobs()

            let isRoot = (geteuid() == 0)
            let promptSymbol = isRoot ? "#" : "$"

            var cwdBuf = [CChar](repeating: 0, count: 1024)
            let cwd = (getcwd(&cwdBuf, 1024) != nil) ? String(cString: cwdBuf) : ""

            let prompt = isInteractive ? "arkos:\(cwd) \(promptSymbol) " : ""
            if isInteractive {
                print(prompt, terminator: "")
                fflush(stdout)
            }

            guard let line = readCommandLine() else {
                // EOF reached (Ctrl+D)
                if isInteractive {
                    print("\nexit")
                }
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            dispatcher.execute(commandLine: trimmed)
        }

        exit(dispatcher.exitCode)
    }

    /// Read a line of input from stdin with basic backspace and newline support.
    private static func readCommandLine() -> String? {
        var input = ""
        var buf: [UInt8] = [0]

        while true {
            let bytesRead = read(STDIN_FILENO, &buf, 1)
            if bytesRead <= 0 {
                return input.isEmpty ? nil : input
            }

            let byte = buf[0]

            if byte == 0x0A { // Newline (\n)
                break
            } else if byte == 0x0D { // Carriage return (\r)
                // Check if followed by \n
                break
            } else if byte == 0x04 { // EOT (Ctrl+D)
                if input.isEmpty {
                    return nil
                }
                break
            } else if byte == 0x08 || byte == 0x7F { // Backspace or DEL
                if !input.isEmpty {
                    input.removeLast()
                    if isatty(STDIN_FILENO) == 1 {
                        // Erase character from display
                        print("\u{0008} \u{0008}", terminator: "")
                        fflush(stdout)
                    }
                }
            } else if byte >= 0x20 { // Printable ASCII
                input.append(Character(UnicodeScalar(byte)))
            }
        }

        return input
    }
}
