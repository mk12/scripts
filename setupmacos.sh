#!/bin/bash

set -ufo pipefail

# Options
mode=setup
primary=false

br=$(brew --prefix)/bin
pj=~/Projects
secrets=~/.profile.local

homebrew_formulas=(
    "bat"
    "clang-format"
    "deno"
    "dust"
    "emacs"
    "entr"
    "exa"
    "fd"
    "fish"
    "gawk"
    "git"
    "git-delta:delta"
    "hexyl"
    "htop"
    "jq"
    "ledger"
    "neovim:nvim"
    "oath-toolkit:oathtool"
    "python@3.9:python3"
    "reattach-to-user-namespace"
    "ripgrep:rg"
    "sd"
    "shellcheck"
    "tldr"
    "tmux"
    "topgrade"
    "trash"
    "vim"
)

homebrew_casks=(
    "ballast"
    "dropbox:Dropbox"
    "hammerspoon:Hammerspoon"
    "kitty"
    "visual-studio-code:Visual Studio Code"
)

usage() {
    cat <<EOS
Usage: $(basename "$0") [options]

This script configures a new Mac with all the settings and software I want. It
can be run multiple times safely.

Options:

    -h  Print this help message
    -b  Print comparision of currently installed homebrew formulas to the ones
        that this script would install.
    -p  Setup as the primary Mac. This includes some additional configuration
        that should only be present on one machine at a time.
EOS
}

step() {
    echo -e "\x1b[31m[SETUP] $*\x1b[0m"
}

clone_git_repo() {
    [[ -d "$2" ]] || "$br/git" clone "git@github.com:$1" "$2"
}

setup_xcode_cli() {
    step "Installing Xcode command line tools"
    xcode-select --print-path > /dev/null || xcode-select --install
}

setup_ssh_github() {
    step "Setting up SSH"
    if ! [[ -f ~/.ssh/id_rsa ]]; then
        step "Generating an SSH key"
        echo -n "Enter email address to use with Git: "
        read -r email_address
        ssh-keygen -t rsa -b 4096 -C "$email_address"

        step "Adding SSH key to keychain"
        eval "$(ssh-agent -s)"
        ssh-add -K ~/.ssh/id_rsa

        step "Adding SSH key to GitHub"
        pbcopy < ~/.ssh/id_rsa.pub
        echo "Copied public SSH key to the clipboard"
        echo -n "Press return to open the browser to GitHub: "
        read -r
        open "https://github.com/settings/keys"
        echo -n "Press return when ready: "
        read -r
    fi
}

setup_my_repos() {
    step "Creating $pj directory"
    mkdir -p "$pj"

    step "Cloning repositories"
    clone_git_repo mk12/dotfiles "$pj/dotfiles"
    clone_git_repo mk12/scripts "$pj/scripts"

    step "Building scripts"
    make -C "$pj/scripts"

    step "Symlinking dotfiles"
    "$pj/dotfiles/link.sh"
}

setup_homebrew_github_api_token() {
    step "Setting Homebrew GitHub API Token"
    if ! grep -q HOMEBREW_GITHUB_API_TOKEN "$secrets"; then
        echo "Create an access token called HOMEBREW_GITHUB_API_TOKEN for X"
        echo -n "Press return to open the browser to GitHub: "
        read -r
        open "https://github.com/settings/tokens/new"
        echo -n "Press return once you have copied the token: "
        read -r
        { echo -n 'export HOMEBREW_GITHUB_API_TOKEN="'; pbpaste; echo '"'; } \
            >> "$secrets"
    fi
}

setup_simplenote_backup() {
    clone_git_repo Simperium/simperium-python "$pj/simperium-python"
    clone_git_repo hiroshi/simplenote-backup "$pj/simplenote-backup"

    step "Setting Simplenote API Token"
    if ! grep -q SIMPLENOTE_API_TOKEN "$secrets"; then
        property="simperium_opts.token"
        echo -n "$property" | pbcopy
        echo "The string '$property' has been copied to the clipboard"
        echo "Paste it into the web console in Simplenote and copy the result"
        echo -n "Press return to open the browser to Simplenote: "
        read -r
        open "https://app.simplenote.com/"
        echo -n "Press return once you have copied the token: "
        read -r
        { echo -n 'export SIMPLENOTE_API_TOKEN="'; pbpaste; echo '"'; } \
            >> "$secrets"
    fi

    "$pj/scripts/backup.sh" -i
}

setup_homebrew() {
    step "Installing Homebrew"
    [[ -x "$br/brew" ]] || /usr/bin/ruby -e "$(curl -fsSL \
        https://raw.githubusercontent.com/Homebrew/install/master/install)"

    step "Installing Homebrew formulas"
    for entry in "${homebrew_formulas[@]}"; do
        formula=${entry%:*}
        binary=${entry#*:}
        [[ -x "$br/$binary" ]] || "$br/brew" install "$formula"
    done

    step "Installing Homebrew casks"
    for entry in "${homebrew_casks[@]}"; do
        cask=${entry%:*}
        app=${entry#*:}
        [[ -d "/Applications/$app.app" ]] || "$br/brew" install --cask "$cask"
    done
}

setup_rust() {
    step "Installing Rust"
    [[ -x ~/.cargo/bin/rustup ]] || curl "https://sh.rustup.rs" -sSf | sh
}

setup_python() {
    step "Installing Python packages"
    "$br/pip3" install pynvim
}

setup_terminfo() {
    file=$(mktemp)
    step "Installing xterm-kitty.terminfo"
    if ! TERMINFO= infocmp xterm-kitty &> /dev/null; then
        if [[ "${TERMINFO:-}" == '/Applications/kitty.app'* ]]; then
            infocmp xterm-kitty > "$file"
            tic -x -o ~/.terminfo "$file"
        else
            echo "WARNING: Did not install xterm-kitty.terminfo"
            echo "WARNING: Re-run $0 in kitty to install it"
        fi
    fi
    step "Installing tmux-256color.terminfo"
    if ! infocmp tmux-256color &> /dev/null; then
        prefix=/usr/local/opt/ncurses
        [[ -d "$prefix" ]] || "$br/brew" install ncurses
        "$prefix/bin/infocmp" -A "$prefix/share/terminfo" tmux-256color \
            > "$file"
        tic -o ~/.terminfo "$file"
    fi
    rm -f "$file"
}

setup_tmux() {
    step "Installing Tmux plugins"
    clone_git_repo tmux-plugins/tpm ~/.tmux/plugins/tpm
}

setup_vim() {
    step "Installing Vim plugins"
    "$br/vim" +PlugInstall +qall
    "$br/nvim" +PlugInstall +qall
}

setup_kitty() {
    step "Setting up kitty"
    clone_git_repo mk12/base16-kitty "$pj/base16-kitty"
    clone_git_repo mk12/base16-solarized-scheme "$pj/base16-solarized-scheme"
    if ! [[ -d "$pj/base16-kitty/colors" ]]; then
        "$pj/base16-kitty/register.sh" "$pj/base16-solarized-theme"
        "$pj/base16-kitty/update.sh"
        "$pj/base16-kitty/build.sh"
    fi
    if ! [[ -f ~/.config/kitty/colors.conf ]]; then
        echo "include $HOME/Projects/base16-kitty/colors/base16-onedark.conf" \
            > ~/.config/kitty/colors.conf
    fi
}

setup_hammerspoon() {
    step "Installing SpoonInstall"
    url="https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip"
    if ! [[ -d ~/.hammerspoon/Spoons/SpoonInstall.spoon ]]; then
        dest=$(mktemp)
        curl -fsSL "$url" > "$dest"
        unzip "$dest" -d ~/.hammerspoon/Spoons
        rm -f "$dest"
    fi
}

setup_ia_symlink() {
    step "Symlinking ~/ia"
    if ! [[ -L ~/ia ]]; then
        ln -s "$HOME/Dropbox/iA Writer" ~/ia
        chflags -h hidden ~/ia
    fi
}

setup_fish() {
    step "Changing login shell to fish"
    dscl . -read ~ UserShell | grep -q "$br/fish" \
        || sudo chsh -s "$br/fish" "$USER"

    step "Setting fish features"
    fish -c "set -U fish_features stderr-nocaret qmark-noglob regex-easyesc"
}

setup_everything() {
    setup_xcode_cli
    setup_ssh_github
    setup_my_repos
    setup_homebrew_github_api_token
    setup_homebrew

    setup_python
    setup_rust
    setup_terminfo
    setup_tmux
    setup_vim
    setup_kitty
    setup_hammerspoon

    setup_ia_symlink
    setup_fish

    if [[ "$primary" == true ]]; then
        setup_simplenote_backup
    fi

    step "Finished"
    echo "Manual steps:"
    echo "  1. Install apps from the App Store."
    echo "  2. Configure System Preferences."
    echo "  3. Set up Time Machine backups."
}

print_homebrew_info() {
    dir=$(mktemp -d)
    printf "%s\n" "${homebrew_formulas[@]%:*}" | sort > "$dir/golden"
    printf "%s\n" "${homebrew_casks[@]%:*}" | sort > "$dir/golden_cask"
    "$br/brew" list --formula | sort > "$dir/list"
    "$br/brew" list --cask | sort > "$dir/list_cask"
    "$br/brew" leaves | sort > "$dir/leaves"

    echo "Uninstalled"
    echo "==========="
    comm -23 "$dir/golden" "$dir/list"
    comm -23 "$dir/golden_cask" "$dir/list_cask" | sed 's/^/cask: /'
    echo

    echo "Extraneous"
    echo "=========="
    comm -13 "$dir/golden" "$dir/leaves"
    comm -13 "$dir/golden_cask" "$dir/list_cask" | sed 's/^/cask: /'

    rm -f "$dir"/{golden{,_cask},list{,_cask},leaves}
    rmdir "$dir"
}

main() {
    case $mode in
        setup) setup_everything ;;
        brew) print_homebrew_info ;;
    esac
}

while getopts "hbp" opt; do
    case $opt in
        h) usage; exit 0 ;;
        b) mode=brew ;;
        p) primary=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || die "too many arguments"

main
