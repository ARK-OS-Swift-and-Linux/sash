# Sash Builtins Documentation

`sash` implements a core set of Unix standard utilities directly as shell builtins, entirely removing the need for an external `coreutils` package. 

All builtins are backed by `libark` to ensure high performance and tight OS integration.

## Supported Commands

### `echo`
Prints text to standard output.
**Flags:**
- `-n`: Do not output the trailing newline.
- `-e`: Enable interpretation of backslash escapes (stub).
- `-E`: Disable interpretation of backslash escapes (stub).
- `--help`: Display usage.
- `--version`: Display version information.

### `pwd`
Prints the absolute path of the current working directory.
**Flags:**
- `-L`: Use PWD from environment (logical).
- `-P`: Avoid all symlinks (physical).
- `--help`: Display usage.
- `--version`: Display version information.

### `cd`
Changes the current working directory.
**Flags:**
- `-L`: Force logical traversal.
- `-P`: Force physical traversal.
- `-e`: Exit with error if dir doesn't exist.
- `--help`: Display usage.

### `ls`
Lists directory contents.
**Flags:**
- `-l`: Use a long listing format.
- `-a`: Do not ignore entries starting with `.`.
- `-h`: Human readable sizes.
- `-r`: Reverse order while sorting.
- `-t`: Sort by modification time.

### `cat`
Concatenate files and print on the standard output.
**Flags:**
- `-n`: Number all output lines.
- `-b`: Number nonempty output lines, overrides -n.
- `-E`: Display $ at end of each line.
- `-T`: Display TAB characters as ^I.
- `-s`: Suppress repeated empty output lines.

### `mkdir`
Creates directories.
**Flags:**
- `-p` / `--parents`: No error if existing, make parent directories as needed.
- `-v` / `--verbose`: Print a message for each created directory.
- `-m`: Set file mode (as in chmod).
- `--help`: Display usage.

### `rmdir`
Removes empty directories.
**Flags:**
- `-p`: Remove directory and its ancestors.
- `-v`: Output a diagnostic for every directory processed.
- `--ignore-fail-on-non-empty`: Ignore each failure that is solely because a directory is non-empty.
- `--help`: Display usage.

### `touch`
Change file timestamps. Creates the file if it does not exist.
**Flags:**
- `-a`: Change only the access time.
- `-m`: Change only the modification time.
- `-c`: Do not create any files.
- `-r`: Use this file's times instead of current time.
- `-d`: Parse string and use it instead of current time.

### `rm`
Removes files or directories.
**Flags:**
- `-r` / `-R` / `--recursive`: Remove directories and their contents recursively.
- `-f` / `--force`: Ignore nonexistent files and arguments, never prompt.
- `-i`: Prompt before every removal.
- `-v` / `--verbose`: Explain what is being done.
- `-d` / `--dir`: Remove empty directories.

### `mv`
Move (rename) files.
**Flags:**
- `-i`: Prompt before overwrite.
- `-f`: Do not prompt before overwriting.
- `-n`: Do not overwrite an existing file.
- `-u`: Move only when the source file is newer than the destination.
- `-v` / `--verbose`: Explain what is being done.

### `cp`
Copy files and directories.
**Flags:**
- `-r`: Copy directories recursively.
- `-i`: Prompt before overwrite.
- `-f`: Force overwrite.
- `-n`: Do not overwrite an existing file.
- `-v` / `--verbose`: Explain what is being done.
