#include <cstdio>
#include <cstring>
#include <iostream>

extern "C" {
#include <unistd.h>
}

namespace {

constexpr const char* USAGE =
    R"EOS(usage: unbrighten [-h] COMMAND ...

Runs command, converting any bright ANSI colors to non-bright versions.
Specifically, it converts:

              foreground    background
              ----------    ----------
    black     90  ->  30    100  -> 40  
    red       91  ->  31    101  -> 41  
    green     92  ->  32    102  -> 42  
    yellow    93  ->  33    103  -> 43  
    blue      94  ->  34    104  -> 44  
    magenta   95  ->  35    105  -> 45  
    cyan      96  ->  36    106  -> 46  
    white     97  ->  37    107  -> 47  

This is useful when using base16 themes because the output can be unreadable for
programs that assume all bright colors are readable.

It only recognizes sequences like \x1b [ 91 m so it (1) might fail for more
complicated sequences, and (2) might incorrectly change values that were
actually escaped by some mechanism in the grammar that this program is unaware
of (because it does not properly parse it).
)EOS";

} // namespace

int main(int argc, char** argv) {
    (void)argv;
    std::ios::sync_with_stdio(false);
    if (argc == 1) {
        std::fputs(USAGE, stderr);
        return 1;
    }
    if (argc == 2 && std::strcmp(argv[1], "-h") == 0) {
        std::fputs(USAGE, stdout);
        return 0;
    }

    // Create a pipe.
    int pipefd[3];
    if (pipe(pipefd) == -1) {
        std::perror("pipe");
        return 1;
    }
    // Fork the process.
    const auto cpid = fork();
    if (cpid == -1) {
        std::perror("fork");
        return 1;
    }

    if (cpid == 0) {
        // Child process. Close the read end of the pipe.
        if (close(pipefd[0]) == -1) {
            std::perror("close");
            return 1;
        }
        // Make stdout go to the write end of the pipe.
        if (dup2(pipefd[1], 1) == -1) {
            std::perror("dup2");
            return 1;
        }
        // Replace this process image by executing the program.
        execvp(argv[1], argv + 1);
        // We shouldn't be here anymore!
        std::perror(argv[1]);
        return 1;
    }

    // Parent process. Close the write end of the pipe.
    if (close(pipefd[1]) == -1) {
        std::perror("close");
        return 1;
    }
    // Make the read end of the pipe go to stdin.
    if (dup2(pipefd[0], 0) == -1) {
        std::perror("dup2");
        return 1;
    }

    char c;
    char buf[5];
    int i = 0;
    bool fg = false;
    char digit = 0;
    while (std::cin.get(c)) {
        switch (i) {
        case 0:
            if (c == '\x1b') {
                buf[i++] = c;
                continue;
            }
            break;
        case 1:
            if (c == '[') {
                buf[i++] = c;
                continue;
            }
            break;
        case 2:
            if (c == '9' || c == '1') {
                fg = c == '9';
                buf[i++] = c;
                continue;
            }
            break;
        case 3:
            if (fg && c >= '0' && c <= '7') {
                buf[i++] = c;
                digit = c;
                continue;
            }
            if (!fg && c == '0') {
                buf[i++] = c;
                continue;
            }
            break;
        case 4:
            if (fg && c == 'm') {
                std::cout << "\x1b[3" << digit << 'm';
                i = 0;
                continue;
            }
            if (!fg && c >= '0' && c <= '7') {
                buf[i++] = c;
                digit = c;
                continue;
            }
            break;
        case 5:
            if (!fg && c == 'm') {
                std::cout << "\x1b[4" << digit << 'm';
                i = 0;
                continue;
            }
            break;
        }
        for (int j = 0; j < i; ++j) {
            std::cout << buf[j];
        }
        i = 0;
        std::cout << c;
    }
    return 0;
}
