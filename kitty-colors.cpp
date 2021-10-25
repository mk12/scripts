#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

extern "C" {
#include <sys/wait.h>
}

namespace {

const char* const USAGE = R"EOS(
Usage: kitty-colors [-h] [-c FILE] [-a | -p] [-f FRAMES] [-d DELAY]

This script changes the terminal colors in kitty.

Flags:
    -h  display this help messge
    -p  print OSC codes only (no kitty remote-control or changing colors.conf)
    -a  animate the transition to the new colors

Options:
    -c FILE    specify colors conf file (if omitted, you pick using fzf)
    -f FRAMES  number of animation frames (default: 50)
    -d DELAY   delay in seconds between frames (default: 0 ms)
)EOS";

struct Options {
    bool animate = false;

    int frames = 100;
    int delay = 30;

    std::string target;
};

const char* PROGRAM = nullptr;

bool inside_tmux() {
    static bool tmux = std::getenv("TMUX") != nullptr;
    return tmux;
}

std::string base16_colors_dir() {
    return std::string(std::getenv("PROJECTS")) + "/base16-kitty/colors";
}

std::string kitty_colors_conf_file() {
    return std::string(std::getenv("HOME")) + "/.config/kitty/colors.conf";
}

std::string kitty_sockets_dir() {
    return std::string(std::getenv("HOME")) + "/.local/share/kitty";
}

std::string exec(const char* cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    result.erase(result.find_last_not_of("\r\n") + 1);
    return result;
}

using Key = int;
using Color = unsigned;
using ColorSet = std::map<Key, Color>;

const Key FOREGROUND = -1;
const Key BACKGROUND = -2;

ColorSet parse_color_file(const char* filename) {
    ColorSet colors;
    std::ifstream infile(filename);
    std::string line;
    while (std::getline(infile, line)) {
        if (line.empty() || line[0] == '#') {
            continue;
        }
        Key key;
        std::istringstream iss(line);
        std::string key_str;
        iss >> key_str;
        if (key_str == "foreground") {
            key = FOREGROUND;
        } else if (key_str == "background") {
            key = BACKGROUND;
        } else if (key_str.substr(0, 5) == "color") {
            key = std::stoi(key_str.substr(5));
        } else {
            continue;
        }

        std::string color_str;
        iss >> color_str;
        if (color_str.empty() || color_str[0] != '#') {
            continue;
        }
        Color color =
            static_cast<unsigned>(std::stoi(color_str.substr(1), nullptr, 16));
        colors.emplace(key, color);
    }
    return colors;
}

void set_colors_osc(const ColorSet& colors) {
    const char* pre = inside_tmux() ? "\x1bPtmux;\x1b\x1b]" : "\x1b]";
    const char* post = inside_tmux() ? "\a\x1b\\\x1b\\" : "\a";
    std::ostringstream ss;
    char buffer[7];
    for (const auto& entry : colors) {
        ss << pre;
        switch (entry.first) {
        case FOREGROUND:
            ss << "10";
            break;
        case BACKGROUND:
            ss << "11";
            break;
        default:
            ss << "4;" << entry.first;
            break;
        }
        std::snprintf(buffer, sizeof buffer, "%06x", entry.second);
        ss << ";#" << buffer << post;
    }
    std::cout << ss.str();
    std::cout.flush();
}

double bit_to_linear(unsigned bit) {
    double x = static_cast<double>(bit) / 255;
    if (x < 0.04045) {
        return x / 12.92;
    }
    return std::pow((x + 0.055) / 1.055, 2.4);
}

unsigned linear_to_bit(double linear) {
    double x = linear <= 0.0031308 ? linear * 12.92
                                   : 1.055 * std::pow(linear, 1 / 2.4) - 0.055;
    return static_cast<unsigned>(
        std::max(0, std::min(255, static_cast<int>(std::lround(x * 255)))));
}

Color interpolate_color(Color c1, Color c2, double t) {
    double r1 = bit_to_linear((c1 >> 16) & 0xff);
    double g1 = bit_to_linear((c1 >> 8) & 0xff);
    double b1 = bit_to_linear(c1 & 0xff);

    double r2 = bit_to_linear((c2 >> 16) & 0xff);
    double g2 = bit_to_linear((c2 >> 8) & 0xff);
    double b2 = bit_to_linear(c2 & 0xff);

    unsigned r = linear_to_bit(r1 + (r2 - r1) * t);
    unsigned g = linear_to_bit(g1 + (g2 - g1) * t);
    unsigned b = linear_to_bit(b1 + (b2 - b1) * t);

    return (r << 16) + (g << 8) + b;
}

void animate_colors(const ColorSet& src, const ColorSet& dst, int frames,
                    int delay_ms) {
    const std::chrono::milliseconds delay(delay_ms);
    for (int i = 0; i < frames; ++i) {
        ColorSet colors;
        for (const auto& entry : src) {
            const double t = static_cast<double>(i + 1) / frames;
            Color interp =
                interpolate_color(entry.second, dst.at(entry.first), t);
            colors.emplace(entry.first, interp);
        }
        set_colors_osc(colors);
        std::this_thread::sleep_for(delay);
    }
}

void update_running_kitties(const std::string& colors_file) {
    for (const auto& entry :
         std::filesystem::directory_iterator(kitty_sockets_dir())) {
        if (entry.path().extension() != ".sock") {
            continue;
        }
        std::ostringstream ss;
        ss << "kitty @ --to 'unix:" << entry.path().string()
           << "' set-colors -a -c '" << colors_file << "' &";
        system(ss.str().c_str());
    }
    wait(nullptr);
}

void update_kitty_conf(const std::string& colors_file) {
    std::ofstream file(kitty_colors_conf_file());
    file << "include " << colors_file << "\n";
}

}  // namespace

int main(int argc, char** argv) {
    PROGRAM = argv[0];

    if (std::system("command -v kitty > /dev/null 2>&1") != 0) {
        std::cerr << PROGRAM << ": kitty: command not found\n";
        return 1;
    }

    Options options;
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "-h") == 0) {
            std::cout << USAGE;
            return 0;
        }
        if (std::strcmp(argv[i], "-a") == 0) {
            options.animate = true;
        } else if (std::strcmp(argv[i], "-c") == 0) {
            options.target = argv[++i];
        } else if (std::strcmp(argv[i], "-d") == 0) {
            options.delay = std::stoi(argv[++i]);
        } else if (std::strcmp(argv[i], "-f") == 0) {
            options.frames = std::stoi(argv[++i]);
        }
    }

    const auto colors_dir = base16_colors_dir();
    if (options.target.empty()) {
        if (!std::filesystem::is_directory(colors_dir)) {
            std::cerr << PROGRAM << ": " << colors_dir
                      << ": directory not found\n";
            return 1;
        }
        std::ostringstream ss;
        ss << "find " << colors_dir
           << " -name '*[^2][^5][^6].conf'"
              " | sed 's|^.*/base16-||;s/.conf$//' | sort | fzf";
        options.target = exec(ss.str().c_str());
        if (options.target.empty()) {
            return 0;
        }
    }
    if (!std::filesystem::is_regular_file(options.target)) {
        std::string original = options.target;
        options.target = colors_dir + "/base16-" + options.target + ".conf";
        if (!std::filesystem::is_regular_file(options.target)) {
            std::cerr << PROGRAM << ": " << original
                      << ": file or color scheme name not found\n";
            return 1;
        }
    }

    if (options.animate) {
        std::ifstream config_file(kitty_colors_conf_file());
        std::string token;
        config_file >> token;
        if (token != "include") {
            std::cerr << PROGRAM << ": " << kitty_colors_conf_file()
                      << ": malformed config file\n";
            return 1;
        }
        config_file >> token;
        const auto& path = token;
        if (!std::filesystem::is_regular_file(path)) {
            std::cerr << PROGRAM << ": " << kitty_colors_conf_file() << ": "
                      << path << ": file not found\n";
            return 1;
        }
        auto src_colors = parse_color_file(path.c_str());
        auto dst_colors = parse_color_file(options.target.c_str());
        animate_colors(src_colors, dst_colors, options.frames, options.delay);
    }

    update_running_kitties(options.target);
    update_kitty_conf(options.target);
}
