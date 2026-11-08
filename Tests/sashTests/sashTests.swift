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
        dispatcher.execute(commandLine: "")
        dispatcher.execute(commandLine: "   ")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)
    }

    func testEchoCommand() throws {
        let dispatcher = CommandDispatcher()
        dispatcher.execute(commandLine: "echo hello world")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)
        dispatcher.execute(commandLine: "echo -n no newline")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)
    }

    func testFileRedirection() throws {
        let fileName = "/tmp/sash_unit_test_\(UUID().uuidString).txt"
        let dispatcher = CommandDispatcher()

        dispatcher.execute(commandLine: "echo test_payload > \(fileName)")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)

        dispatcher.execute(commandLine: "echo second_line >> \(fileName)")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)

        let content = try? String(contentsOfFile: fileName)
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.contains("test_payload") == true)
        XCTAssertTrue(content?.contains("second_line") == true)

        dispatcher.execute(commandLine: "rm \(fileName)")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)
    }

    func testVariableAssignmentAndExpansion() throws {
        let dispatcher = CommandDispatcher()
        dispatcher.execute(commandLine: "FOO=bar")
        XCTAssertEqual(dispatcher.environment["FOO"], "bar")

        dispatcher.execute(commandLine: "export BAZ=qux")
        XCTAssertEqual(dispatcher.environment["BAZ"], "qux")
    }

    func testTestCommandOperators() throws {
        let dispatcher = CommandDispatcher()
        dispatcher.execute(commandLine: "test 1 -eq 1")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)

        dispatcher.execute(commandLine: "test 1 -eq 2")
        XCTAssertEqual(dispatcher.lastExitStatus, 1)

        dispatcher.execute(commandLine: "[ hello = hello ]")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)

        dispatcher.execute(commandLine: "[ hello != world ]")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)
    }

    func testLogicalOperators() throws {
        let dispatcher = CommandDispatcher()
        dispatcher.execute(commandLine: "test 1 -eq 1 && echo success")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)

        dispatcher.execute(commandLine: "test 1 -eq 2 || echo fallback")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)
    }

    func testDirectoryOperations() throws {
        let dirName = "/tmp/sash_dir_\(UUID().uuidString)"
        let dispatcher = CommandDispatcher()

        dispatcher.execute(commandLine: "mkdir -p \(dirName)")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)

        dispatcher.execute(commandLine: "test -d \(dirName)")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)

        dispatcher.execute(commandLine: "rmdir \(dirName)")
        XCTAssertEqual(dispatcher.lastExitStatus, 0)
    }

    func testJobControlManager() throws {
        JobManager.shared.initialize(terminalFd: STDIN_FILENO)
        let job = JobManager.shared.addJob(pid: 99999, command: "sleep 10")
        XCTAssertEqual(job.command, "sleep 10")
        XCTAssertTrue(job.isRunning)
    }
}
