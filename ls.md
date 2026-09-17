Assuming you mean Unix/Linux shell echo, here’s the full practical map.

echo command: basically everything you can do with it
1. Print plain text
echo Hello

Output:

Hello

Multiple arguments:

echo Hello World
Hello World

echo normally separates arguments with spaces.

2. Print an empty line
echo

Output:

This is useful for formatting shell output:

echo "Build complete!"
echo
echo "Starting kernel..."
3. Print variables
name="Aarav"
echo "$name"

Output:

Aarav

You can also concatenate text:

echo "Hello $name"
Hello Aarav
Always prefer quoting variables
echo "$name"

instead of:

echo $name

because unquoted expansion is subject to word splitting and pathname expansion.

Shells: let's turn printing a variable into a parsing adventure.

4. Print multiple variables
name="Aarav"
age=20

echo "$name" "$age"

Output:

Aarav 20

Or:

echo "Name: $name, Age: $age"
5. Print command substitution

You can execute another command and print its output:

echo "$(date)"

or:

echo "$(uname -r)"

Example:

6.12.0-...

Older syntax also exists:

echo `uname -r`

but modern shell code should use:

$(...)
6. Print arithmetic results

In Bash and compatible shells:

echo $((10 + 20))

Output:

30

Variables:

a=10
b=5

echo $((a * b))
50
7. Print escape sequences

Some implementations of echo understand backslash escapes.

For example:

echo -e "Hello\nWorld"

Output:

Hello
World

Common escapes include:

Escape	Meaning
\n	newline
\t	horizontal tab
\r	carriage return
\b	backspace
\a	bell
\v	vertical tab
\\	backslash
\c	stop output
\0NNN	octal character

Example:

echo -e "Name:\tAarav"

Output:

Name:   Aarav
Important

echo -e is not portable behavior across all Unix environments.

For predictable escape processing, use:

printf

instead.

8. Disable the trailing newline

The -n option tells many echo implementations not to print the final newline:

echo -n "Loading..."

Normally:

Loading...

with the cursor staying on the same line.

This is useful for prompts:

echo -n "Enter your name: "
read name
9. Use echo -e for colored terminal output

For example:

echo -e "\033[31mERROR\033[0m"

This can produce red ERROR text in terminals supporting ANSI escape sequences.

Other common ANSI sequences:

echo -e "\033[32mSUCCESS\033[0m"
echo -e "\033[33mWARNING\033[0m"
echo -e "\033[34mINFO\033[0m"

But again, printf is generally safer:

printf '\033[31mERROR\033[0m\n'
10. Print special characters

Quoting determines how the shell interprets characters.

echo "Hello!"

Single quotes:

echo 'Hello!'

Double quotes allow expansions:

name="Aarav"
echo "Hello $name"

Single quotes prevent expansion:

echo 'Hello $name'

Output:

Hello $name
11. Print literal $
echo '$HOME'

prints:

$HOME

Alternatively:

echo "\$HOME"
12. Print literal quotes
echo '"Hello"'

Output:

"Hello"

Or:

echo "\"Hello\""
13. Print a backslash
echo "\\"

Depending on the implementation/options involved, backslash processing can vary.

For predictable output:

printf '%s\n' '\\'
14. Print shell wildcards literally

Suppose you have:

*.c

This:

echo *.c

may expand to filenames.

To print the literal pattern:

echo '*.c'
15. Print filenames
echo *.c

If the directory contains:

main.c
kernel.c
boot.c

you may get:

boot.c kernel.c main.c

This isn't really echo doing glob expansion. The shell expands *.c before echo receives it.

That's an important distinction.

16. Print the current directory
echo "$PWD"

or:

echo "$PWD/"

You can also use:

echo "$(pwd)"
17. Print environment variables
echo "$HOME"
echo "$PATH"
echo "$USER"
echo "$SHELL"
echo "$TERM"

For example:

echo "$PATH"

might produce:

/usr/local/bin:/usr/bin:/bin
18. Print positional parameters

Inside a shell script:

echo "$1"

prints the first argument.

echo "$2"

prints the second.

All arguments:

echo "$@"

Number of arguments:

echo "$#"

Script name:

echo "$0"
19. Print all arguments
echo "$@"

Example script:

#!/bin/bash

echo "$@"

Run:

./script.sh hello linux kernel

Output:

hello linux kernel
20. Print special shell variables

Examples:

echo "$?"

Exit status of the previous command.

echo "$$"

Current shell's PID.

echo "$!"

PID of the most recently started background process.

echo "$#"

Number of positional arguments.

echo "$0"

Script/shell name.

21. Redirect echo into a file

Overwrite a file:

echo "Hello" > file.txt

Append:

echo "Another line" >> file.txt

This is extremely common.

22. Redirect standard error
echo "Error!" >&2

That sends the message to stderr, not stdout.

Useful in scripts:

echo "ERROR: build failed" >&2
exit 1
23. Redirect stdout and stderr

For example:

echo "message" > output.txt

stdout goes to the file.

For both:

command > output.txt 2>&1

With echo itself, stderr isn't normally interesting unless you're deliberately redirecting descriptors or testing shell behavior.

24. Pipe echo into another command
echo "hello world" | wc -w

Output:

2

Another:

echo "hello" | grep hello
25. Feed another program input
echo "Aarav" | read name

Careful: in many shells, read running in a pipeline may execute in a subshell, so the variable may not survive afterward.

For simple input generation:

echo "yes" | some-program

is common.

26. Generate configuration fragments

For example:

echo "CONFIG_DEBUG=y" > config

Or:

echo "CONFIG_X86_64=y" >> config

Useful for build systems, kernel configurations, scripts, etc.

27. Generate source code

You can do:

echo 'print("Hello")' > hello.py

or:

echo '#include <stdio.h>' > main.c

But for anything multiline, cat <<EOF or a proper editor is usually cleaner.

28. Generate multiple lines

You could:

echo -e "line1\nline2\nline3"

But:

printf '%s\n' "line1" "line2" "line3"

is more portable.

Or:

cat <<EOF
line1
line2
line3
EOF
29. Use echo in shell scripts for status messages

Extremely common:

echo "[INFO] Building kernel..."
echo "[INFO] Compiling..."
echo "[INFO] Linking..."
echo "[OK] Build complete."
30. Print debugging information
echo "DEBUG: value=$value"

Or:

echo "DEBUG: argc=$#"

This is one of the simplest debugging techniques in shell scripting.

31. Print commands dynamically
cmd="gcc main.c -o main"

echo "Running: $cmd"
$cmd

Although storing commands as strings and executing them this way can become problematic when arguments contain spaces or special characters. Arrays are better in Bash.

32. Test whether a variable is empty
if [ -z "$name" ]; then
    echo "Name is empty"
fi
33. Conditional output
if [ "$?" -eq 0 ]; then
    echo "Success"
else
    echo "Failed"
fi

More commonly:

if command; then
    echo "Success"
else
    echo "Failed"
fi
34. Use echo with logical operators
command && echo "Success"

or:

command || echo "Failed"

Example:

mkdir test && echo "Directory created"
35. Use command substitution around echo

You can capture its output:

message=$(echo "Hello")

Then:

echo "$message"

Though doing this purely with echo is obviously somewhat circular. Humanity has built entire operating systems and still occasionally asks a command to print something so another command can capture it.

36. Use echo to inspect shell expansion

This is useful for learning:

echo $HOME
echo "$HOME"
echo '$HOME'

You'll see the difference between:

/home/user
/home/user
$HOME
37. Brace expansion

In Bash:

echo file{1,2,3}

Output:

file1 file2 file3

Range:

echo {1..10}

Output:

1 2 3 4 5 6 7 8 9 10

Again, the shell performs the expansion.

echo merely receives the resulting arguments.

38. Tilde expansion
echo ~

may output:

/home/aarav

And:

echo ~/projects

may become:

/home/aarav/projects

Again, shell expansion.

39. Print command output with formatting
echo "Kernel: $(uname -r)"

or:

echo "Architecture: $(uname -m)"

Example:

Architecture: x86_64
40. Print multiple lines with a single argument
echo "line one
line two
line three"

Output:

line one
line two
line three

The newline is actually inside the argument.

41. echo built-in vs external command

This is a BIG one.

On most Linux shells:

echo

is a shell builtin.

You can investigate:

type echo

Bash might report:

echo is a shell builtin

You can also find implementations:

command -V echo

And on systems that provide an external version:

/usr/bin/echo

may exist.

42. Bash's echo

Bash has its own builtin:

help echo

This tells you the behavior of Bash's implementation.

Options can include:

-n
-e
-E

-E disables interpretation of backslash escapes in implementations that support that behavior.

43. POSIX echo

POSIX echo has historically been troublesome because implementations differ around options and backslash processing.

For portable shell scripting, especially when arbitrary user input is involved:

printf '%s\n' "$variable"

is usually the correct tool.

44. Why echo "$variable" isn't always ideal

Consider:

variable="-n"
echo "$variable"

Different echo implementations can interpret -n as an option.

That's one reason:

printf '%s\n' "$variable"

is safer.

printf doesn't have the same ambiguity.

45. Print arbitrary user input safely

Instead of:

echo "$input"

prefer:

printf '%s\n' "$input"

especially if you're writing serious shell tooling.

46. Print without interpreting backslashes

Depending on your echo implementation:

echo -E '\n\t\\'

can suppress escape interpretation.

But portable scripts should again use:

printf '%s\n' '\n\t\\'
47. Print data containing spaces

Correct:

echo "$file"

If:

file="my kernel source.c"

you preserve it as one argument.

Without quotes:

echo $file

the shell can split it into multiple words.

48. Print data containing wildcard characters
file="*.c"

echo "$file"

prints:

*.c

while:

echo $file

can cause pathname expansion.

49. Print Unicode

Modern Linux terminals handle UTF-8:

echo "Hello 世界"

or:

echo "🐧 Linux"

Output:

🐧 Linux

assuming your locale/terminal supports UTF-8.

50. Print null bytes?

This is where echo gets weird.

You should not use echo for arbitrary binary data.

Use:

printf

or tools designed for binary data.

For example:

printf '\0'

can produce a NUL byte, whereas echo is not a reliable binary-output interface.

51. Use echo with sudo

For example:

sudo echo "hello" > /root/test

This doesn't do what many beginners expect.

The shell performs:

> /root/test

before sudo echo runs.

So the shell itself needs permission.

Instead:

echo "hello" | sudo tee /root/test

This is a classic Linux trap.

52. Use echo to modify privileged files

For example:

echo "setting=value" | sudo tee /etc/example.conf

Append:

echo "another=value" | sudo tee -a /etc/example.conf
53. Use echo for /sys

Linux exposes lots of kernel interfaces through pseudo-filesystems.

For example:

echo 1 | sudo tee /sys/...

The exact path depends on the subsystem.

Here echo is generating textual input for a kernel interface.

54. Use echo with /proc

Similarly:

echo something | sudo tee /proc/...

when a particular proc interface accepts textual input.

Again, exact interfaces depend on the kernel and configuration.

55. Use echo for terminal control

ANSI escape sequences can manipulate terminal behavior:

echo -ne "\033[2J\033[H"

This can clear the screen and move the cursor, depending on terminal support.

But:

printf '\033[2J\033[H'

is more predictable.

56. echo can expose shell bugs

For example:

echo $variable

can behave differently from:

echo "$variable"

because of:

parameter expansion
word splitting
pathname expansion
option parsing by echo

So echo is actually a nice little laboratory for learning shell parsing.

57. Use echo in loops
for file in *.c; do
    echo "$file"
done
58. Use it with while
while read -r line; do
    echo "$line"
done < file.txt

Although:

cat file.txt

would obviously be simpler if you're merely displaying the file.

59. Use it in functions
info() {
    echo "[INFO] $1"
}

info "Compiling kernel"
60. Create simple logging functions
log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

Then:

log "Starting build"

Produces something like:

[21:36:42] Starting build

For serious logging, printf is preferable.

61. Use echo to demonstrate exit status
echo "hello"
echo $?

Since echo succeeded, typically:

hello
0
62. Echo itself returns an exit status

Normally:

echo hello
echo $?

gives:

hello
0

If writing shell scripts, don't assume every implementation behaves identically under bizarre edge cases, but successful normal output is generally status 0.

63. echo can be used as a command argument generator

For example:

echo *.o

Then perhaps:

echo *.o | xargs rm

But don't casually do this for arbitrary filenames because whitespace, quotes, newlines, and special characters can break the parsing.

For robust file processing, use null-delimited mechanisms such as:

find ... -print0

and tools that understand -0.

64. echo and shell injection

This:

echo "$user_input"

does not execute the contents of $user_input.

But this:

eval "echo $user_input"

is a completely different and potentially dangerous beast.

Never use eval casually with untrusted input.

65. Echoing commands in scripts

A script can print what it is about to execute:

echo "+ gcc main.c -o main"
gcc main.c -o main

Bash also has:

set -x

which automatically traces commands.

That is generally better for serious debugging.

66. echo vs printf

This is the important final boss.

echo
echo "Hello"

Simple.

printf
printf '%s\n' "Hello"

Predictable.

printf gives you:

formatting
precise newline handling
predictable escape handling
portable behavior
integer/string formatting
controlled output

For example:

printf 'Name: %s\nAge: %d\n' "$name" "$age"

Output:

Name: Aarav
Age: 20
The mental model you should remember

The most important thing about echo isn't actually echo.

It's the shell.

When you type:

echo "$HOME" *.c $(uname -r)

the shell roughly performs:

1. Parse command
       ↓
2. Expand $HOME
       ↓
3. Expand *.c
       ↓
4. Execute $(uname -r)
       ↓
5. Build argv[]
       ↓
6. Invoke echo
       ↓
7. echo writes output

So echo itself isn't responsible for:

$HOME expansion
*.c globbing
$(...)
{1..10} brace expansion
~ expansion
variable expansion
quote removal

The shell does those things first.

That's why understanding echo is secretly a gateway drug to understanding the entire Unix shell.

The practical cheat sheet
echo "Hello"                  # text
echo                          # blank line
echo "$var"                   # variable
echo "$@"                     # script arguments
echo "$?"                     # previous exit status
echo "$(command)"             # command substitution
echo $((1 + 2))               # arithmetic
echo -n "text"                # no newline
echo -e "a\nb"                # escapes, non-portable
echo "text" > file            # overwrite
echo "text" >> file           # append
echo "error" >&2              # stderr
echo "text" | command         # pipe
echo "text" | sudo tee file   # privileged write
type echo                     # identify implementation
help echo                     # Bash builtin help
printf '%s\n' "$var"          # usually the better choice