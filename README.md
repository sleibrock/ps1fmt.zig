# ps1fmt.zig

A buddy program to help you design PS1 shell prompts.

## Goals

`ps1fmt`'s goal is to interpret your local `$PS1` variable set by a Bash shell program or others like ZSH or normal shell. When designing prompts, you must take care to close out all your opening sequences, or else your shell will start going haywire.

`ps1fmt` will read your `$PS1` variable and use a state machine to determine all your ANSI escape codes you have used in your prompt.

Example output is as follows from a default Bash instance:

```bash
[steve@host]$ ./ps1fmt
PS1 is: \[\033[01;32m\][\u@\h\[\033[01;37m\] \W\[\033[01;32m\]]\$\[\033[00m\] 

Your signals are:
ANSI.before_seq
ANSI.open
ANSI.after_seq
ANSI.username
ANSI.short_hostname
ANSI.before_seq
ANSI.open
ANSI.after_seq
ANSI.path_full
ANSI.before_seq
ANSI.open
ANSI.after_seq
ANSI.is_root
ANSI.before_seq
ANSI.close
ANSI.after_seq

Goodbye
```

`ps1fmt` was able to pick up all the code signals used in `$PS1` formatting, so you can see where you start sequences, and where they end.

Future releases aim to show which sequences are unclosed or left dangling. Some time in the future, it would be nice to show the exact text output of each code signal as well (the current code is primitive right now).

## Build and Install

`ps1fmt` is written in Zig currently targeting `0.9` or above. Older versions are not supported as of right now (and probably won't be).

