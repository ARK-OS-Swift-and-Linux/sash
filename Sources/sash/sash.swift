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

@main
struct sash {
    static func main() {
        print("sash 1.0 - The ARK-OS shell")
        let dispatcher = CommandDispatcher()
        
        while true {
            var cwd = [CChar](repeating: 0, count: 1024)
            getcwd(&cwd, 1024)
            let cwdStr = String(cString: cwd)
            
            print("\(cwdStr) $ ", terminator: "")
            fflush(stdout)
            
            guard let line = readLine() else {
                print("exit")
                break
            }
            
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed == "exit" {
                break
            }
            
            dispatcher.execute(commandLine: trimmed)
        }
    }
}
