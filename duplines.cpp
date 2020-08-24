#include <algorithm>
#include <cassert>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <functional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

// =============================================================================
//       Command-line interface
// =============================================================================

const char* const USAGE = R"EOS(
Usage: duplines [-h] [-a MIN] [-b MAX] FILE ...

This script finds duplicate regions in text files.

Flags:
    -h  display this help messge
    -a  minimum number of lines in region
    -b  maximum number of lines in region
)EOS";

struct Options {
    int min;
    int max;
};

const char* PROGRAM = nullptr;

// =============================================================================
//       I/O helpers
// =============================================================================

class Input;

using LineNo = std::size_t;

struct Line {
    const Input* input;
    LineNo lineno;
};

struct LineRange {
    const Input* input;
    LineNo start; // inclusive
    LineNo end;   // exclusive
};

class Input {
public:
    explicit Input(const char* const filename)
         : filename_(filename), file_(filename) {}

    const char* name() const { return filename_; }

    bool exists() const {
        return std::filesystem::is_regular_file(filename_);
    }

    bool getline() {
        return bool(std::getline(file_, lines_.emplace_back()));
    }

    std::string_view get(const LineNo lineno) const {
        return lines_[lineno];
    }

    Line last() const {
        assert(!lines_.empty());
        return Line{this, lines_.size() - 1};
    }

private:
    const char* filename_;
    std::ifstream file_;
    std::vector<std::string> lines_;
};

using Hash = std::size_t;

class Hasher {
public:
    Hash get() const { return h_; }

    template <typename T>
    void combine(const T& value) {
        // http://stackoverflow.com/a/1646913
        h_ = h_ * 31 + std::hash<T>()(value);
    }

private:
    Hash h_ = 17;
};

// =============================================================================
//       Ring buffer
// =============================================================================

template <typename T>
class Ring {
public:
    explicit Ring(const std::size_t size) : buf_(size), i_(0), len_(0) {}

    std::size_t size() const { return len_;  }

    void push(const T&& value) {
        buf_[i_++] = std::forward<const T>(value);
        i_ %= buf_.size();
        len_ = std::min(buf_.size(), len_ + 1);
    }

    const T& at(std::size_t i) const {
        assert(i < len_);
        const auto len = buf_.size();
        return buf_[((i_ - i - 1) % len + len) % len];
    }

private:
    std::vector<T> buf_;
    std::size_t i_;
    std::size_t len_;
};

// =============================================================================
//       Find duplicates
// =============================================================================

void find_dups(std::vector<Input>& inputs, const Options& options) {
    const auto min = static_cast<std::size_t>(options.min);
    const auto max = static_cast<std::size_t>(options.max);
    const auto num_lens = max - min + 1;
    std::vector<std::unordered_map<Hash, LineRange>> map(num_lens);
    for (auto& input : inputs) {
        Ring<Line> window(max);
        while (input.getline()) {
            window.push(input.last());
            Hasher hasher;
            std::size_t i = 0;
            for (; i < min; ++i) {
                hasher.combine(input.get(window.at(i).lineno));
            }
            for (; i < window.size(); ++i) {

            }
        }
    }
}

} // namespace

// =============================================================================
//       Main
// =============================================================================

int main(int argc, char** argv) {
    PROGRAM = argv[0];

    Options options;
    std::vector<Input> inputs;
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "-h") == 0) {
            std::fputs(USAGE, stdout);
            return 0;
        }
        const bool a = std::strcmp(argv[i], "-a") == 0;
        const bool b = std::strcmp(argv[i], "-b") == 0;
        if (a || b) {
            if (i + 1 == argc) {
                std::fprintf(stderr, "%s: %s: must provide an argument\n",
                    PROGRAM, argv[i]);
                return 1;
            }
            ++i;
            int* value = a ? &options.min : &options.max;
            try {
                *value = std::stoi(argv[i]);
            } catch (const std::logic_error&) {
                std::fprintf(stderr, "%s: %s: invalid number\n",
                    PROGRAM, argv[i]);
                return 1;
            }
            if (*value <= 1) {
                std::fprintf(stderr, "%s: %s: must be > 1\n",
                    PROGRAM, argv[i]);
                return 1;
            }
        } else {
            inputs.emplace_back(argv[i]);
        }
    }
    if (options.min == 0) {
        std::fprintf(stderr, "%s: missing required flag -a", PROGRAM);
        return 1;
    }
    if (options.max == 0) {
        std::fprintf(stderr, "%s: missing required flag -b", PROGRAM);
        return 1;
    }
    if (options.min > options.max) {
        std::fprintf(stderr, "%s: min must be less than max", PROGRAM);
        return 1;
    }
    for (const auto& input : inputs) {
        if (!input.exists()) {
            std::fprintf(stderr, "%s: %s: file not found\n", PROGRAM, input.name());
            return 1;
        }
    }
    find_dups(inputs, options);
    return 0;
}
