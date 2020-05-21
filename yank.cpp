#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <thread>

extern "C" {
#include <unistd.h>
}

namespace {

constexpr const char* USAGE =
    R"EOS(usage: yank [-h]

Copies standard input to the clipboard using OSC 52 escape sequences. Assumes
the terminal implements the modified protocol whereby an invalid sequence clears
the clipboard and a valid one appends to it (i.e. what kitty does). This allows
the program to function properly for any amount of input.

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

void base64_encode(
        char* const dest,
        const char* const source,
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

void reset_osc_52() {
    std::printf("%s\x1b]52;c;!\a%s", prefix, suffix);
}

void print_osc_52(const char* const base64, const std::size_t len) {
    std::printf("%s\x1b]52;c;%.*s\a%s",
        prefix, static_cast<int>(len), base64, suffix);
}

} // namespace

int main(int argc, char** argv) {
    (void)argv;
    std::ios::sync_with_stdio(false);
    if (argc > 1) {
        std::fputs(USAGE, stdout);
        return 0;
    }
    const bool tmux = std::getenv("TMUX") != nullptr;
    std::unique_ptr<FILE, decltype(&pclose)> tmux_pipe(nullptr, pclose);
    if (tmux) {
        // Wrap each OSC 52 sequence in a tmux passthrough envelope.
        prefix = "\x1bPtmux;\x1b";
        suffix = "\x1b\\";
        // Run `tmux load-buffer -` in writable mode.
        tmux_pipe.reset(popen("tmux load-buffer -", "w"));
    }
    // There is clearly a limit of 8192 somewhere, because this program breaks
    // if I make it any larger (it starts printing stuff to the screen).
    constexpr auto B64_BUF_SIZE = 8192 - NON_TMUX_ESCAPE_SIZE;
    constexpr auto BUF_SIZE = base64_dec_size(B64_BUF_SIZE);
    auto b64_buf = std::make_unique<char[]>(base64_enc_size(BUF_SIZE));
    auto buf = std::make_unique<char[]>(BUF_SIZE);
    reset_osc_52();
    while (std::cin.good()) {
        std::cin.read(buf.get(), BUF_SIZE);
        const auto len = static_cast<std::size_t>(std::cin.gcount());
        if (len == 0) {
            break;
        }
        const auto b64_len = base64_enc_size(len);
        base64_encode(b64_buf.get(), buf.get(), len);
        if (tmux) {
            // Sleep 1ms between OSC 52 writes for tmux. Otherwise it has flaky
            // behavior, randomly dropping passthrough envelopes.
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            const auto n = std::fwrite(buf.get(), 1, len, tmux_pipe.get());
            if (n != len) {
                std::fprintf(stderr, "ERROR: %zu, want %zu\n", n, len);
            }
        }
        print_osc_52(b64_buf.get(), b64_len);
    }
    return 0;
}
