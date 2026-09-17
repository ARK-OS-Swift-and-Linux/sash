# Contributing to Sash

We welcome contributions to `sash`! Whether it's adding new shell builtins, improving POSIX compliance, or optimizing performance.

## How to Contribute
1. **Open an Issue**: Discuss major architectural changes or new builtins before submitting a PR.
2. **Fork and Clone**:
   ```bash
   git clone https://github.com/ARK-OS-Swift-and-Linux/sash.git
   ```
3. **Write Tests**: `sash` relies heavily on `XCTest`. Ensure new builtins have corresponding test cases.
4. **Follow Guidelines**: Use clean, idiomatic Swift. Ensure any filesystem access routes through `libark`.

## Local Development
Run the test suite before submitting PRs:
```bash
swift test
```
