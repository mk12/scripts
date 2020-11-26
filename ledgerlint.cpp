#include <cctype>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <istream>
#include <string>
#include <string_view>
#include <utility>

namespace {

// =============================================================================
//       Command-line interface
// =============================================================================

const char* const USAGE = R"EOS(
Usage: ledgerlint [-h] [-f FILE]

This script lints my ledger file.

If no file is given, it tries to read $LEDGER_FILE.

Flags:
    -h  display this help messge
)EOS";

struct Options {
    std::string file;
};

const char* PROGRAM = nullptr;

// =============================================================================
//       I/O helpers
// =============================================================================

class Input {
public:
    Input(const std::string& filename)
        : filename_(filename), file_(filename), lineno_(0) {}

    explicit operator bool() const { return bool(file_); }
    std::string_view view() const { return std::string_view(line_); }
    bool success() const { return success_; }

    bool getline() {
        ++lineno_;
        const auto result = bool(std::getline(file_, line_));
        if (!line_.empty() && std::isspace(line_[line_.size() - 1])) {
            error("trailing whitespace");
        }
        return result;
    }

    bool getline_until(const char* const stop) {
        return getline() && !(stop != nullptr && line_ == stop);
    }

    void error(const char* const format, ...)
        __attribute__((__format__ (__printf__, 2, 3)))
    {
        std::printf("%.*s:%u: ",
            static_cast<int>(filename_.size()),
            filename_.data(),
            lineno_);
        std::va_list args;
        va_start(args, format);
        std::vprintf(format, args);
        va_end(args);
        std::putchar('\n');
        success_ = false;
    }

private:
    std::string filename_;
    std::ifstream file_;
    std::string line_;
    unsigned lineno_;
    bool success_;
};

bool starts_with(std::string_view s, std::string_view prefix) {
    return s.substr(0, prefix.size()) == prefix;
}

struct Split {
    std::string_view left;
    std::string_view right;
    bool ok;
};

Split split(std::string_view s, std::string_view delim) {
    const auto i = s.find(delim);
    if (i == std::string::npos) {
        return Split{{}, {}, false};
    }
    return Split{s.substr(0, i), s.substr(i + delim.size()), true};
}

struct Comment {
    std::size_t spaces;
    std::string_view incl_semi;
    std::string_view excl_semi;
    bool ok;
};

Comment parse_comment(std::string_view s) {
    const auto i = s.find_first_not_of(' ');
    if (i == std::string::npos) {
        return Comment{0, {}, {}, false};
    }
    if (s[i] != ';') {
        return Comment{0, {}, {}, false};
    }
    const auto incl_semi = s.substr(i);
    const auto j = incl_semi.substr(1).find_first_not_of(' ');
    const auto excl_semi = incl_semi.substr(1 + j);
    return Comment{i, incl_semi, excl_semi, true};
}

// =============================================================================
//       Journal structure
// =============================================================================

#define NUM_PARTS 5
enum Part {
    Commodities,
    Tags,
    Accounts,
    People,
    Transactions,
};

#define NUM_COMMODITY_PARTS 4
enum CommodityPart {
    Currencies,
    MutualFunds,
    Stocks,
    Other,
};

#define NUM_ACCOUNT_PARTS 6
enum AccountPart {
    Equity,
    Assets,
    Liabilities,
    Income,
    Expenses,
    Virtual,
};

#define NUM_PEOPLE_PARTS 2
enum PeoplePart {
    Debtors,
    Creditors,
};

const char* const PART_COMMENTS[NUM_PARTS] = {
    [Commodities]  = ";;; Commodities",
    [Tags]         = ";;; Tags",
    [Accounts]     = ";;; Accounts",
    [People]       = ";;; People",
    [Transactions] = ";;; Transactions",
};

const char* const COMMODITY_PART_COMMENTS[NUM_COMMODITY_PARTS] = {
    [Currencies]  = "; Currencies",
    [MutualFunds] = "; Mutual funds",
    [Stocks]      = "; Stocks",
    [Other]       = "; Other",
};

const char* const ACCOUNT_PART_COMMENTS[NUM_ACCOUNT_PARTS] = {
    [Equity]      = "; Equity",
    [Assets]      = "; Assets",
    [Liabilities] = "; Liabilities",
    [Income]      = "; Income",
    [Expenses]    = "; Expenses",
    [Virtual]     = "; Virtual",
};

const char* const PEOPLE_PART_COMMENTS[NUM_PEOPLE_PARTS] = {
    [Debtors]   = "; Debtors",
    [Creditors] = "; Creditors",
};

typedef void (*LintFn)(Input&, const char*);

void skip(Input& input, const char* const stop) {
    while (input.getline_until(stop));
}

void lint_commodities(Input&, const char*);
void lint_tags(Input&, const char*);
void lint_accounts(Input&, const char*);
void lint_people(Input&, const char*);
void lint_transactions(Input&, const char*);

void lint_account_equity(Input&, const char*);
void lint_account_assets(Input&, const char*);
void lint_account_liabilities(Input&, const char*);
void lint_account_income(Input&, const char*);
void lint_account_expenses(Input&, const char*);
void lint_account_virtual(Input&, const char*);

void lint_people_debtors(Input&, const char*);
void lint_people_creditors(Input&, const char*);

const LintFn PART_FUNCTIONS[NUM_PARTS] = {
    [Commodities]  = lint_commodities,
    [Tags]         = lint_tags,
    [Accounts]     = lint_accounts,
    [People]       = lint_people,
    [Transactions] = lint_transactions,
};

const LintFn COMMODITY_PART_FUNCTIONS[NUM_COMMODITY_PARTS] = {
    [Currencies]  = skip,
    [MutualFunds] = skip,
    [Stocks]      = skip,
    [Other]       = skip,
};

const LintFn ACCOUNT_PART_FUNCTIONS[NUM_ACCOUNT_PARTS] = {
    [Equity]      = lint_account_equity,
    [Assets]      = lint_account_assets,
    [Liabilities] = lint_account_liabilities,
    [Income]      = lint_account_income,
    [Expenses]    = lint_account_expenses,
    [Virtual]     = lint_account_virtual,
};

const LintFn  PEOPLE_PART_FUNCTIONS[NUM_PEOPLE_PARTS] = {
    [Debtors]   = lint_people_debtors,
    [Creditors] = lint_people_creditors,
};

// =============================================================================
//       Linter helpers
// =============================================================================

void check_sections(
    Input& input,
    const char* const stop,
    const char* const comments[],
    const LintFn functions[],
    const unsigned num_sections
) {
    while (input.getline()) {
        if (input.view() == comments[0]) {
            break;
        }
    }
    for (unsigned i = 0; i < num_sections; ++i) {
        if (!input) {
            input.error("reached EOF before %s", comments[i]);
            break;
        }
        const char* const substop = i + 1 == num_sections ? stop : comments[i+1];
        functions[i](input, substop);
    }
}

void check_accounts(
    Input& input, const char* stop, const char* part, const char* prefix
) {
    while (input.getline_until(stop)) {
        if (starts_with(input.view(), "account ")) {
            const auto account = input.view().substr(std::strlen("account "));
            if (!starts_with(account, prefix)) {
                input.error("non-%s account in %s section: %.*s",
                    part, part,
                    static_cast<int>(account.size()), account.data());
            }
        }
    }
}

void check_accounts_sorted(
    Input& input, const char* stop, const char* part, const char* prefix
) {
    std::string last;
    while (input.getline_until(stop)) {
        if (starts_with(input.view(), "account ")) {
            const auto account = input.view().substr(std::strlen("account "));
            if (!starts_with(account, prefix)) {
                input.error("non-%s account in %s section: %.*s",
                    part, part, static_cast<int>(account.size()), account.data());
            } else if (!last.empty() && !(last < account)) {
                input.error("%s account out of order: %.*s",
                    part, static_cast<int>(account.size()), account.data());
            }
            last = account;
        }
    }
}

// =============================================================================
//       Linter functions
// =============================================================================

void lint(Input& input) {
    check_sections(input, nullptr,
        PART_COMMENTS, PART_FUNCTIONS, NUM_PARTS);
}

void lint_commodities(Input& input, const char* const stop) {
    check_sections(input, stop,
        COMMODITY_PART_COMMENTS, COMMODITY_PART_FUNCTIONS, NUM_COMMODITY_PARTS);
}

void lint_tags(Input& input, const char* const stop) {
    std::string last;
    while (input.getline_until(stop)) {
        if (starts_with(input.view(), "tag ")) {
            const auto tag = input.view().substr(std::strlen("tag "));
            if (!last.empty() && !(last < tag)) {
                input.error("tag out of order: %.*s",
                    static_cast<int>(tag.size()), tag.data());
            }
            last = tag;
        }
    }
}

void lint_accounts(Input& input, const char* const stop) {
    check_sections(input, stop,
        ACCOUNT_PART_COMMENTS, ACCOUNT_PART_FUNCTIONS, NUM_ACCOUNT_PARTS);
}

void lint_people(Input& input, const char* const stop) {
    check_sections(input, stop,
        PEOPLE_PART_COMMENTS, PEOPLE_PART_FUNCTIONS, NUM_PEOPLE_PARTS);
}

void lint_account_equity(Input& input, const char* const stop) {
    check_accounts(input, stop, "Equity", "Equity:");
}

void lint_account_assets(Input& input, const char* const stop) {
    check_accounts(input, stop, "Asset", "Assets:");
}

void lint_account_liabilities(Input& input, const char* const stop) {
    check_accounts(input, stop, "Liability", "Liabilities:");
}

void lint_account_income(Input& input, const char* const stop) {
    check_accounts_sorted(input, stop, "Income", "Income:");
}

void lint_account_expenses(Input& input, const char* const stop) {
    check_accounts_sorted(input, stop, "Expense", "Expenses:");
}

void lint_account_virtual(Input& input, const char* const stop) {
    check_accounts(input, stop, "Virtual", "Virtual:");
}

void lint_people_debtors(Input& input, const char* const stop) {
    check_accounts_sorted(input, stop, "Debtor", "Assets:Due From:");
}

void lint_people_creditors(Input& input, const char* const stop) {
    check_accounts_sorted(input, stop, "Creditor", "Liabilities:Due To:");
}

#define NUM_DIVISIONS 5
enum Division {
    // Regular amount on every posting.
    AMOUNT,
    // Lot price of the commodity, i.e. cost basis.
    PRICE,
    // Lot date of the commodity.
    DATE,
    // What AMOUNT was valued at for the posting.
    COST,
    // Balance assertion.
    ASSERT,
};

struct State {
    bool pending = false;
    bool last_dates = false;
    std::string payee, note, last_pri, last_aux;
    unsigned num_postings = 0;
    unsigned num_amountless_postings = 0;
    unsigned div_columns[NUM_DIVISIONS] = {};

    void new_transaction() {
        num_postings = 0;
        num_amountless_postings = 0;
        for (unsigned i = 0; i < NUM_DIVISIONS; ++i) {
            div_columns[i] = 0;
        }
    }
};

void check_transaction_entry(Input&, State&);
void check_transaction_posting(Input&, State&);
void check_date(Input&, std::string_view);
void check_note(Input&, Comment, std::size_t);
void check_amount(Input&, std::string_view, Division);

void lint_transactions(Input& input, const char* const stop) {
    if (!(input.getline_until(stop) && input.view().empty())) {
        input.error("expected a blank line");
    }
    State state;
    Comment comment;
    enum { ENTRY, NOTE, POSTINGS } expect = ENTRY;
    while (input.getline_until(stop)) {
        if (expect != POSTINGS && input.view().empty()) {
            input.error("unexpected blank line");
            continue;
        }
        switch (expect) {
        case ENTRY:
            expect = NOTE;
            state.new_transaction();
            check_transaction_entry(input, state);
            break;
        case NOTE:
            expect = POSTINGS;
            comment = parse_comment(input.view());
            if (comment.ok) {
                check_note(input, comment, 4);
                state.note = comment.excl_semi;
                break;
            }
            input.error("expected a transaction note");
            [[fallthrough]];
        case POSTINGS:
            comment = parse_comment(input.view());
            if (comment.ok) {
                check_note(input, comment, state.num_postings == 0 ? 4 : 8);
                break;
            }
            if (starts_with(input.view(), "    ")) {
                check_transaction_posting(input, state);
                break;
            }
            expect = ENTRY;
            if (!input.view().empty()) {
                input.error("expected a blank line seperating transactions");
                expect = NOTE;
            }
            break;
        }
    }
}

void check_transaction_entry(Input& input, State& state) {
    auto s = split(input.view(), " * ");
    state.payee = s.right;
    if (!s.ok) {
        s = split(input.view(), " ! ");
        if (!s.ok) {
            input.error("transaction has neither '*' nor '!'");
            return;
        }
        state.pending = true;
    } else if (state.pending) {
        input.error("posted transaction appears after pending ones");
    }
    if (s.left.size() >= 1 && s.left[s.left.size()-1] == ' ') {
        input.error("excess whitespace after date");
    }
    if (s.right.size() >= 1 && s.right[0] == ' ') {
        input.error("excess whitespace before payee");
    }
    auto pri = s.left;
    auto aux = s.left;
    s = split(pri, "=");
    if (s.ok) {
        pri = s.left;
        aux = s.right;
        check_date(input, aux);
        if (pri == aux) {
            input.error("aux date %.*s is redundant",
                static_cast<int>(aux.size()), aux.data());
        } else if (pri < aux) {
            input.error("aux date %.*s is later than primary date %.*s",
                static_cast<int>(aux.size()), aux.data(),
                static_cast<int>(pri.size()), pri.data());
        }
    }
    check_date(input, pri);
    if (state.last_dates && (pri < state.last_pri
            || (pri == state.last_pri && aux < state.last_aux))) {
        input.error("date out of order: %.*s=%.*s",
            static_cast<int>(pri.size()), pri.data(),
            static_cast<int>(aux.size()), aux.data());
    }
    state.last_dates = true;
    state.last_pri = pri;
    state.last_aux = aux;
}

void check_transaction_posting(Input& input, State& state) {
    const auto view = input.view();
    const auto size = view.size();
    const auto s = split(view.substr(4), "  ");
    ++state.num_postings;
    if (!s.ok) {
        ++state.num_amountless_postings;
    }
    if (state.num_postings > 2 && state.num_amountless_postings > 0) {
        input.error("transactions with 3+ postings must not omit amounts");
    }
    if (!s.ok) {
        return;
    }
    const auto account = s.left;
    unsigned start = 4 + static_cast<unsigned>(account.size()) + 2;
    unsigned end = 60;
    if (start >= end) {
        input.error("amount goes past column 60");
        return;
    }
    Division div = AMOUNT;
    unsigned present = 0;
    while (size > start) {
        if (size < end) {
            input.error("posting not aligned to 60+20n");
            break;
        }
        if (div != AMOUNT && view[start] != ' ') {
            input.error("column %u: expected space", start + 1);
        }
        const auto clipped = view.substr(0, end);
        const auto section = clipped.substr(start);
        const bool empty = section.find_first_not_of(' ') == std::string::npos;
        if (div == AMOUNT) {
            if (!empty) {
                present |= 1 << AMOUNT;
                check_amount(input, section, AMOUNT);
            }
        } else if (view[end-1] == '}') {
            if (div > PRICE) {
                input.error("column %u: lot price out of order", start + 1);
            }
            div = PRICE;
            present |= 1 << PRICE;
            const auto open = section.find('{');
            if (open == std::string::npos) {
                input.error("column %u: ill-formed lot price", start + 1);
                break;
            }
            if (section[open + 1] == ' ') {
                input.error("column %u: unexpected space in lot price",
                    start + static_cast<unsigned>(open) + 2);
            }
            check_amount(input,
                section.substr(open + 1, section.size() - open - 2),
                PRICE);
        } else if (view[end-1] == ']') {
            if (div > DATE) {
                input.error("column %u: lot date out of order", start + 1);
            }
            div = DATE;
            present |= 1 << DATE;
            const auto open = section.find('[');
            if (open == std::string::npos) {
                input.error("column %u: ill-formed lot date", start + 1);
                break;
            }
            check_date(input,
                section.substr(open + 1, section.size() - open - 2));
        } else if (view[start+1] == '@') {
            if (div > COST) {
                input.error("column %u: posting cost out of order", start + 1);
            }
            div = COST;
            present |= 1 << COST;
            const auto next = view[start+2];
            if (next != ' ' && next != '@') {
                input.error("column %u: %c: unexpected character",
                    start + 3, next);
                break;
            }
            check_amount(input, section.substr(3), COST);
        } else if (view[start+1] == '=') {
            div = ASSERT;
            present |= 1 << ASSERT;
            if (view[start+2] != ' ') {
                input.error("column %u: missing space after '='", start + 3);
            }
            const auto rest = section.substr(3);
            if (!(
                view[end-1] == '0'
                && rest.find_first_not_of(' ') == rest.size() - 1
            )) {
                check_amount(input, rest, ASSERT);
            }
        } else if (!empty) {
            input.error("column %u: unrecognized posting section", start + 1);
            break;
        }
        if (!empty) {
            if (state.div_columns[div] == 0) {
                state.div_columns[div] = end;
            } else if (state.div_columns[div] != end) {
                input.error("column %u: misaligned posting section", end + 1);
            }
        }
        start = end;
        end = start + 20;
        div = static_cast<Division>(div + 1);
    }
    if (!(present & (1 << AMOUNT)) && present != 1 << ASSERT) {
        input.error("postings that omit $amount can only have =assert");
    }
    if (present & (1 << PRICE) && !(present & (1 << COST))) {
        input.error("posting has {}price but no @cost");
    }
    if (div < ASSERT
        && starts_with(account, "Assets:")
        && starts_with(account, "Liabilities:")
        && (
            state.payee.find("ATM") != std::string::npos
            || state.payee.find("Transfer") != std::string::npos
            || state.note == "Pay debt"
            || state.note == "Collect debt"
            || state.note == "Visa statement"
            || state.note.find("domain") != std::string::npos
            || state.note.find("payroll") != std::string::npos
        )
    ) {
        input.error("expected balance assertion");
    }
}

void check_note(Input& input, Comment comment, std::size_t expected_indent) {
    if (comment.spaces != expected_indent) {
        input.error("expected note to be indented %zu spaces, not %zu",
            expected_indent, comment.spaces);
    }
    if (comment.incl_semi.size() < 2 || comment.excl_semi.size() < 1) {
        input.error("ill-formed note (too short)");
        return;
    }
    if (comment.incl_semi[1] != ' ') {
        input.error("missing space after ';'");
    }
    if (comment.incl_semi.size() - comment.excl_semi.size() > 2) {
        input.error("too many spaces after ';'");
    }
}

void check_date(Input& input, std::string_view date) {
    if (!(
        date.size() == 10
        & date[0] >= '0' & date[0] <= '9'
        & date[1] >= '0' & date[1] <= '9'
        & date[2] >= '0' & date[2] <= '9'
        & date[3] >= '0' & date[3] <= '9'
        & date[4] == '/'
        & date[5] >= '0' & date[5] <= '1'
        & date[6] >= '0' & date[6] <= '9'
        & date[7] == '/'
        & date[8] >= '0' & date[8] <= '3'
        & date[9] >= '0' & date[9] <= '9'
    )) {
        input.error("ill-formed date: %.*s",
            static_cast<int>(date.size()), date.data());
    }
}

void check_amount(Input& input, std::string_view amount, const Division div) {
    amount.remove_prefix(
        std::min(amount.find_first_not_of(' '), amount.size()));
    if (amount.empty()) {
        input.error("no amount found");
        return;
    }
    const char* message = "could not parse amount";
    std::size_t p;
    int places;
    std::string_view commodity, value;
    if (amount[0] == '$') {
        commodity = amount.substr(0, 1);
        value = amount.substr(1);
    } else {
        const auto s = split(amount, " ");
        if (!s.ok) {
            goto error;
        }
        commodity = s.left;
        value = s.right;
    }
    if (value.empty()) {
        goto error;
    }
    if (value[0] == '-') {
        value.remove_prefix(1);
    }
    p = value.find('.');
    if (p == std::string::npos) {
        p = value.size();
    }
    for (unsigned i = 0; i < value.size(); ++i) {
        if (i < p && (p - i) % 4 == 0) {
            if (value[i] != ',') {
                message = "amount missing comma (thousands separator)";
                goto error;
            }
        } else if (i != p && !(value[i] >= '0' && value[i] <= '9')) {
            message = "amount has non-numeric character";
            goto error;
        }
    }
    places = static_cast<int>(value.size() - p) - 1;
    if (
        commodity == "$" || commodity == "USD" || commodity == "EUR"
        || commodity == "VMFXX"
    ) {
        if (div == AMOUNT && places != 2) {
            message = "expected 2 decimal places";
            goto error;
        }
        if (places < 2) {
            message = "expected at least 2 decimal places";
            goto error;
        }
    } else if (div == PRICE || div == COST) {
        message = "price must be currency";
        goto error;
    } else if (
        commodity == "VTSAX" || commodity  == "VTIAX"
        || commodity == "VBTLX" || commodity == "VTRTS"
        || commodity == "GOOG"
    ) {
        if (places != 4) {
            message = "expected 4 decimal places";
            goto error;
        }
    } else if (commodity == "Audible") {
        if (places != -1) {
            message = "expected a whole number";
            goto error;
        }
    } else {
        message = "invalid commodity";
        goto error;
    }
    return;

error:
    input.error("%.*s: %s",
        static_cast<int>(amount.size()), amount.data(), message);
    return;
}

} // namespace

// =============================================================================
//       Main
// =============================================================================

int main(int argc, char** argv) {
    PROGRAM = argv[0];

    Options options;
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "-h") == 0) {
            std::fputs(USAGE, stdout);
            return 0;
        }
        if (std::strcmp(argv[i], "-f") == 0) {
            if (i + 1 == argc) {
                std::fprintf(stderr, "%s: -f: must provide an argument\n",
                    PROGRAM);
                return 1;
            }
            options.file = argv[++i];
        }
    }
    if (options.file.empty()) {
        const char* var = std::getenv("LEDGER_FILE");
        if (var != nullptr) {
            options.file = var;
        }
    }
    if (options.file.empty()) {
        std::fprintf(stderr, "%s: must provide a file\n", PROGRAM);
        return 1;
    }
    if (!std::filesystem::is_regular_file(options.file)) {
        std::fprintf(stderr, "%s: %s: file not found\n",
            PROGRAM, options.file.c_str());
        return 1;
    }
    Input input(options.file);
    lint(input);
    return input.success() ? 0 : 1;
}
