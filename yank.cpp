#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <memory>

extern "C" {
#include <unistd.h>
}

namespace {

constexpr const char* USAGE =
    R"EOS(usage: yank [-ht]

Copies standard input to the clipboard using the OSC 52 escape sequence. Assumes
the terminal supports an unbounded payload like kitty does, so does not attempt
to truncate it. Pass the -t flag to truncate to 8192 bytes.

If $TMUX is set, yank also copies the input to the current tmux buffer. For best
results, the tmux clipboard feature should be turned OFF:

    # .tmux.conf
    set -g set-clipboard off

If it is set to "external", tmux will intercept the OSC 52 sequence and attempt
to set the clipboard itself. If set to "on", it will additionally set the tmux
buffer. Both of these are made redundant by yank.
)EOS";

constexpr char base64_table[65] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

constexpr std::size_t base64_enc_size(const std::size_t len) {
    return 4 * ((len + 2) / 3);
}

constexpr std::size_t base64_dec_size(const std::size_t len) {
    return 3 * len / 4;
}

void base64_encode(char* const dest, const char* const source,
                   const std::size_t len) {
    auto dst = dest;
    auto src = reinterpret_cast<const unsigned char*>(source);
    const auto end = src + len;
    while (end - src >= 3) {
        *dst++ = base64_table[src[0] >> 2];
        *dst++ = base64_table[((src[0] & 0x03) << 4) | (src[1] >> 4)];
        *dst++ = base64_table[((src[1] & 0x0f) << 2) | (src[2] >> 6)];
        *dst++ = base64_table[src[2] & 0x3f];
        src += 3;
    }
    if (src != end) {
        *dst++ = base64_table[src[0] >> 2];
        if (end - src == 1) {
            *dst++ = base64_table[(src[0] & 0x03) << 4];
            *dst++ = '=';
        } else {
            *dst++ = base64_table[((src[0] & 0x03) << 4) | (src[1] >> 4)];
            *dst++ = base64_table[(src[1] & 0x0f) << 2];
        }
        *dst++ = '=';
    }
}

constexpr std::size_t NON_TMUX_ESCAPE_SIZE =
    std::char_traits<char>::length("\x1b]52;c;\a");

const char* prefix = "";
const char* suffix = "";

void print_osc_52(const char* const base64, const std::size_t len) {
    std::printf("%s\x1b]52;c;%.*s\a%s", prefix, static_cast<int>(len), base64,
                suffix);
}

}  // namespace

int main(int argc, char** argv) {
    (void)argv;
    std::ios::sync_with_stdio(false);
    bool truncate = false;
    if (argc > 1) {
        if (argc == 2 && std::strcmp(argv[1], "-h") == 0) {
            std::fputs(USAGE, stdout);
            return 0;
        }
        if (argc == 2 && std::strcmp(argv[1], "-t") == 0) {
            truncate = true;
        } else {
            std::fputs(USAGE, stderr);
            return 1;
        }
    }
    const bool tmux = std::getenv("TMUX") != nullptr;
    std::unique_ptr<FILE, decltype(&pclose)> tmux_pipe(nullptr, pclose);
    if (tmux) {
        // Wrap the OSC 52 sequence in a tmux passthrough envelope.
        prefix = "\x1bPtmux;\x1b";
        suffix = "\x1b\\";
        // Run `tmux load-buffer -` in writable mode.
        tmux_pipe.reset(popen("tmux load-buffer -", "w"));
    }
    char* buf = nullptr;
    std::size_t len = 0;
    std::size_t cap;
    if (truncate) {
        cap = base64_dec_size(8192 - (tmux ? 0 : NON_TMUX_ESCAPE_SIZE));
        buf = static_cast<char*>(std::malloc(cap));
        std::cin.read(buf, cap);
        len = static_cast<std::size_t>(std::cin.gcount());
    } else {
        const auto chunk_size = 16384;
        cap = chunk_size;
        buf = static_cast<char*>(std::malloc(cap));
        while (std::cin.good()) {
            if (len + chunk_size > cap) {
                while (len + chunk_size > cap) {
                    cap *= 2;
                }
                buf = static_cast<char*>(std::realloc(buf, cap));
            }
            std::cin.read(buf + len, chunk_size);
            const auto additional = static_cast<std::size_t>(std::cin.gcount());
            if (additional == 0) {
                break;
            }
            len += additional;
        }
    }
    const auto b64_len = base64_enc_size(len);
    char *b64_buf = static_cast<char*>(std::malloc(b64_len));
    base64_encode(b64_buf, buf, len);
    if (tmux) {
        const auto n = std::fwrite(buf, 1, len, tmux_pipe.get());
        if (n != len) {
            std::fprintf(stderr, "ERROR: %zu, want %zu\n", n, len);
        }
    }
    print_osc_52(b64_buf, b64_len);
    std::free(buf);
    std::free(b64_buf);
    return 0;
}
