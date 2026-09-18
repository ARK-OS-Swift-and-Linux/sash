# Sash (Swift-Bash)

`sash` is a modern, memory-safe replacement for the traditional POSIX shell (`bash`). It is built entirely in Swift and powered by the robust, object-oriented foundational layer of [`libark`](../libark).

While designed to be the default terminal environment for ArkOS, `sash` is portable and can run on any Linux distribution.

## Features
- **Memory Safety**: Eliminates entire classes of vulnerabilities (buffer overflows, UAF) inherent in traditional C-based shells.
- **Powered by libark**: Deep integration with `libark` for native OS interaction, bypassing legacy C boundaries.
- **Modern Syntax**: Combines POSIX shell familiarity with modern scriptability paradigms.

## Getting Started

To clone and build `sash`:

```bash
git clone https://github.com/ARK-OS-Swift-and-Linux/sash.git
cd sash
swift build
```

## Documentation

- [Architecture](docs/Architecture.md) (Coming soon)
- [Command Reference](docs/Commands.md) (Coming soon)

## License

`sash` is released under the Apache License 2.0. See [LICENSE](LICENSE) for details.
