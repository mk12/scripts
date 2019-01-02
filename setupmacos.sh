#!/bin/bash

set -ufo pipefail

# Constants
br=/usr/local/bin
gh=~/GitHub
fish_secret=~/.config/fish/secret.fish

# Options
primary=false

usage() {
    cat <<EOS
Usage: $(basename "$0") [options]

This script configures a new Mac with all the settings and software I want. It
can be run multiple times safely.

Options:

    -h  Print this help message
    -p  Setup as the primary Mac. This includes some additional configuration
        that should only be present on one machine at a time.
EOS
}

step() {
    echo -e "\x1b[31m[SETUP] $*\x1b[0m"
}

clone_git_repo() {
    test -d "$2"|| "$br/git" clone "git@github.com:$1" "$2"
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
    step "Creating GitHub directory"
    mkdir -p "$gh"

    step "Cloning repositories"
    clone_git_repo mk12/dotfiles "$gh/dotfiles"
    clone_git_repo mk12/finance "$gh/finance"
    clone_git_repo mk12/scripts "$gh/scripts"

    step "Symlinking dotfiles"
    "$gh/dotfiles/link.sh"
}

setup_homebrew_github_api_token() {
    step "Setting Homebrew GitHub API Token"
    if ! grep -q HOMEBREW_GITHUB_API_TOKEN "$fish_secret"; then
        echo "Create an access token called HOMEBREW_GITHUB_API_TOKEN for X"
        echo -n "Press return to open the browser to GitHub: "
        read -r
        open "https://github.com/settings/tokens/new"
        echo -n "Press return once you have copied the token: "
        read -r
        { echo -n 'set -x HOMEBREW_GITHUB_API_TOKEN "'; pbpaste; echo '"'; } \
            >> "$fish_secret"
    fi
}

setup_simplenote_backup() {
    clone_git_repo Simperium/simperium-python "$gh/simperium-python"
    clone_git_repo hiroshi/simplenote-backup "$gh/simplenote-backup"

    step "Setting Simplenote API Token"
    if ! grep -q SIMPLENOTE_API_TOKEN "$fish_secret"; then
        property="simperium_opts.token"
        echo -n $property | pbcopy
        echo "The string '$property' has been copied to the clipboard"
        echo "Paste it into the web console in Simplenote and copy the result"
        echo -n "Press return to open the browser to Simplenote: "
        read -r
        open "https://app.simplenote.com/"
        echo -n "Press return once you have copied the token: "
        read -r
        { echo -n "set -x SIMPLENOTE_API_TOKEN ""; pbpaste; echo """; } \
            >> "$fish_secret"
    fi

    "$gh/scripts/backup.sh" install
}

setup_homebrew() {
    step "Installing Homebrew"
    test -x "$br/brew" || /usr/bin/ruby -e "$(curl -fsSL \
        https://raw.githubusercontent.com/Homebrew/install/master/install)"

    step "Installing Homebrew formulas"
    "$br/brew" bundle install --global --no-upgrade --verbose
}

setup_rust() {
    step "Installing Rust"
    test -x ~/.cargo/bin/rustup || curl "https://sh.rustup.rs" -sSf | sh
}

setup_python() {
    step "Installing Python packages"
    "$br/pip" install neovim
    "$br/pip3" install neovim pygments
}

setup_iterm2() {
    step "Linking iTerm2 preferences"
    defaults write com.googlecode.iterm2.plist PrefsCustomFolder \
        -string "$gh/dotfiles/iterm2"
    defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder \
        -bool true
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

setup_ia_symlink() {
    step "Symlinking ~/ia"
    if ! [[ -L ~/ia ]]; then
        ln -s "$HOME/Dropbox/iA Writer" ~/ia
        chflags -h hidden ~/ia
    fi
}

setup_fish_login() {
    step "Changing login shell to fish"
    dscl . -read ~ UserShell | grep -q "$br/fish" \
        || sudo chsh -s "$br/fish" "$USER"
}

main() {
    setup_xcode_cli
    setup_ssh_github
    setup_my_repos
    setup_homebrew_github_api_token
    setup_homebrew

    setup_ia_symlink
    setup_iterm2
    setup_python
    setup_rust
    setup_tmux
    setup_vim

    setup_fish_login

    if [[ "$primary" == true ]]; then
        setup_simplenote_backup
    fi

    step "Finished"
    echo "Manual steps:"
    echo "  1. Install apps from the App Store."
    echo "  2. Configure System Preferences."
    echo "  3. Set up Time Machine backups."
}

while getopts "hp" opt; do
    case $opt in
        h) usage; exit 0 ;;
        p) primary=true ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] ||

main
