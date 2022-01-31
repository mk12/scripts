#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <functional>
#include <set>
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
Usage: duplines [-h] [-m MIN] [-M MAX] FILE ...

This script finds duplicate regions in text files.

Flags:
    -h  display this help messge
    -m  minimum number of lines in region
    -M  maximum number of lines in region
)EOS";

struct Options {
    int min = 0;
    int max = 0;
};

const char* PROGRAM = nullptr;

// =============================================================================
//       I/O helpers
// =============================================================================

class Input;

// Zero-based line number.
using LineNo = std::size_t;

struct LineRange {
    const Input* input;
    LineNo start;  // inclusive
    LineNo end;    // exclusive
};

class Input {
   public:
    explicit Input(const char* const filename)
        : filename_(filename), file_(filename) {}

    const char* name() const { return filename_; }

    bool exists() const { return std::filesystem::is_regular_file(filename_); }

    bool getline() { return bool(std::getline(file_, lines_.emplace_back())); }

    std::string_view get(const LineNo lineno) const { return lines_[lineno]; }

    LineNo end() const { return lines_.size(); }

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
//       Find duplicates
// =============================================================================

void find_dups(std::vector<Input>& inputs, const Options& options) {
    const auto min = static_cast<std::size_t>(options.min);
    const auto max = static_cast<std::size_t>(options.max);
    const auto num_lens = max - min + 1;
    std::vector<std::unordered_map<Hash, std::vector<LineRange>>> map(num_lens);
    std::set<std::pair<std::size_t, Hash>> hits;
    for (auto& input : inputs) {
        while (input.getline()) {
            Hasher hasher;
            const auto end = input.end();
            LineNo len = 1;
            for (; len < std::min(min, end); ++len) {
                const auto start = end - len;
                hasher.combine(input.get(start));
            }
            for (; len >= min && len <= std::min(max, end); ++len) {
                const auto start = end - len;
                hasher.combine(input.get(start));
                const auto encoded_len = len - min;
                assert(encoded_len < num_lens);
                const auto hash = hasher.get();
                auto& slot = map[encoded_len][hash];
                slot.push_back(LineRange{&input, start, end});
                if (slot.size() > 1) {
                    hits.emplace(encoded_len, hash);
                }
            }
        }
    }
    std::unordered_map<const Input*, std::vector<bool>> taken;
    for (const auto& input : inputs) {
        const auto num_lines = input.end();
        taken.emplace(&input, num_lines);
    }
    // Iterate in reverse order to get the largest duplicates first, and skip
    // over any smaller duplicates contained within them.
    for (auto it = hits.crbegin(); it != hits.crend(); ++it) {
        const auto encoded_len = it->first;
        const auto hash = it->second;
        const auto& slot = map[encoded_len][hash];
        const auto first_range = slot.front();
        for (const auto range : slot) {
            auto& bitmap = taken[range.input];
            for (auto i = range.start; i < range.end; ++i) {
                if (bitmap[i]) {
                    // Very conservative: never report another duplicate in
                    // which even one line of one copy has already been reported
                    // as part of another set of duplicates.
                    goto skip;
                }
                bitmap[i] = true;
            }
        }
        for (const auto range : slot) {
            std::printf("%s:%zu\n", range.input->name(), range.start + 1);
        }
        std::printf("\n");
        for (auto i = first_range.start; i < first_range.end; ++i) {
            const auto line = first_range.input->get(i);
            std::printf("> %.*s\n", static_cast<int>(line.size()), line.data());
        }
        std::printf("\n\n");
    skip:;
    }
}

}  // namespace

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
        const bool a = std::strcmp(argv[i], "-m") == 0;
        const bool b = std::strcmp(argv[i], "-M") == 0;
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
                std::fprintf(stderr, "%s: %s: invalid number\n", PROGRAM,
                             argv[i]);
                return 1;
            }
            if (*value <= 1) {
                std::fprintf(stderr, "%s: %s: must be > 1\n", PROGRAM, argv[i]);
                return 1;
            }
        } else {
            inputs.emplace_back(argv[i]);
        }
    }
    if (options.min == 0) {
        std::fprintf(stderr, "%s: missing required flag -m", PROGRAM);
        return 1;
    }
    if (options.max == 0) {
        std::fprintf(stderr, "%s: missing required flag -M", PROGRAM);
        return 1;
    }
    if (options.min > options.max) {
        std::fprintf(stderr, "%s: min must be less than max", PROGRAM);
        return 1;
    }
    for (const auto& input : inputs) {
        if (!input.exists()) {
            std::fprintf(stderr, "%s: %s: file not found\n", PROGRAM,
                         input.name());
            return 1;
        }
    }
    find_dups(inputs, options);
    return 0;
}
