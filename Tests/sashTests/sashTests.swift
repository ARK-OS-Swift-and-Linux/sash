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

import XCTest
@testable import sash

final class sashTests: XCTestCase {
    
    func testCommandDispatcherParsesEmpty() throws {
        let dispatcher = CommandDispatcher()
        // Ensure no crash on empty or whitespace
        dispatcher.execute(commandLine: "")
        dispatcher.execute(commandLine: "   ")
    }
    
    func testEchoCommand() throws {
        let dispatcher = CommandDispatcher()
        // we can't easily capture stdout without redirecting in XCTest,
        // but we can ensure it doesn't crash or throw exceptions.
        dispatcher.execute(commandLine: "echo hello world")
        dispatcher.execute(commandLine: "echo -n no newline")
        dispatcher.execute(commandLine: "echo --version")
    }
    
    func testTouchAndRmCommands() throws {
        let fileName = "sash_test_file.txt"
        let dispatcher = CommandDispatcher()
        
        // Touch should create the file
        dispatcher.execute(commandLine: "touch \(fileName)")
        
        // Ensure it exists by doing an ls or cat (not crashing)
        dispatcher.execute(commandLine: "cat \(fileName)")
        
        // Remove it
        dispatcher.execute(commandLine: "rm \(fileName)")
    }
    
    func testMkdirAndRmdirCommands() throws {
        let dirName = "sash_test_dir"
        let dispatcher = CommandDispatcher()
        
        dispatcher.execute(commandLine: "mkdir \(dirName)")
        dispatcher.execute(commandLine: "ls -a")
        dispatcher.execute(commandLine: "rmdir \(dirName)")
    }
}
