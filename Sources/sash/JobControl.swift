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

/// Represents a running or stopped background job in sash.
public struct ShellJob: Sendable {
    public let id: Int
    public let pid: pid_t
    public let command: String
    public var isRunning: Bool
    public var exitCode: Int32?
}

/// Job control manager for sash, handling process groups, foreground handoff,
/// and background job reaping.
public final class JobManager {
    public static let shared = JobManager()

    private var nextJobId: Int = 1
    public private(set) var jobs: [ShellJob] = []
    public private(set) var shellPGID: pid_t = 0
    public private(set) var terminalFd: Int32 = STDIN_FILENO
    public private(set) var isInteractive: Bool = false

    private init() {}

    /// Initialize interactive job control on the current terminal.
    public func initialize(terminalFd: Int32 = STDIN_FILENO) {
        self.terminalFd = terminalFd
        self.isInteractive = (isatty(terminalFd) == 1)

        if isInteractive {
            // Put the shell into its own process group
            shellPGID = getpid()
            setpgid(shellPGID, shellPGID)

            // Take control of the terminal
            tcsetpgrp(terminalFd, shellPGID)

            // Ignore interactive and job-control signals in the shell process itself
            signal(SIGINT, SIG_IGN)
            signal(SIGQUIT, SIG_IGN)
            signal(SIGTSTP, SIG_IGN)
            signal(SIGTTIN, SIG_IGN)
            signal(SIGTTOU, SIG_IGN)
        } else {
            shellPGID = getpgrp()
        }
    }

    /// Register a new background job.
    @discardableResult
    public func addJob(pid: pid_t, command: String) -> ShellJob {
        let job = ShellJob(id: nextJobId, pid: pid, command: command, isRunning: true, exitCode: nil)
        nextJobId += 1
        jobs.append(job)
        return job
    }

    /// Reap completed background jobs non-blockingly.
    public func pollCompletedJobs() {
        var updated: [ShellJob] = []
        for var job in jobs {
            if job.isRunning {
                var status: Int32 = 0
                let res = waitpid(job.pid, &status, WNOHANG)
                if res == job.pid {
                    job.isRunning = false
                    if (status & 0x7f) == 0 {
                        job.exitCode = (status >> 8) & 0xff
                    } else {
                        job.exitCode = 128 + (status & 0x7f)
                    }
                    if isInteractive {
                        print("[\(job.id)] Done (\(job.exitCode ?? 0))  \(job.command)")
                    }
                } else if res == -1 {
                    job.isRunning = false
                    job.exitCode = -1
                }
            }
            if job.isRunning {
                updated.append(job)
            }
        }
        jobs = updated
    }

    /// Give terminal control to a foreground process group and wait for completion.
    public func putJobInForeground(pgid: pid_t) -> Int32 {
        if isInteractive {
            // Hand over terminal focus to child process group
            tcsetpgrp(terminalFd, pgid)
        }

        var status: Int32 = 0
        var result: pid_t
        repeat {
            result = waitpid(pgid, &status, WUNTRACED)
        } while result == -1 && errno == EINTR

        if isInteractive {
            // Reclaim terminal control for the shell
            tcsetpgrp(terminalFd, shellPGID)
        }

        if (status & 0x7f) == 0 {
            // Exited normally
            return (status >> 8) & 0xff
        } else if ((status & 0x7f) + 1) >> 1 > 0 {
            // Terminated by signal
            let sig = status & 0x7f
            if sig == SIGINT {
                print("")
            }
            return 128 + sig
        }
        return 0
    }
}

