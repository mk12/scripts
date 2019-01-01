#!/bin/bash

set -ufo pipefail

br=/usr/local/bin
gh=~/GitHub

step() {
    echo -e "\x1b[31m[SETUP] $*\x1b[0m"
}

brew_install() {
    test -x $br/${2:-$1} || brew install $1
}

brew_cask_install() {
    test -x "/Applications/$2.app" || brew cask install $1
}

clone_git_repo() {
    test -d $2 || $br/git clone git@github.com:$1 $2
}

step 'Installing Xcode command line tools'
xcode-select --print-path > /dev/null || xcode-select --install

step 'Installing Homebrew'
test -x $br/brew || /usr/bin/ruby -e "$(curl -fsSL \
    https://raw.githubusercontent.com/Homebrew/install/master/install)"

step 'Installing Homebrew formulas'
brew_install bash
brew_install exa
brew_install fish
brew_install git
brew_install ledger
brew_install neovim nvim
brew_install python python3
brew_install python@2 python2
brew_install ripgrep rg
brew_install tldr
brew_install tmux
brew_install trash
brew_install vim

step 'Installing Homebrew cask formulas'
brew_cask_install dropbox 'Dropbox'
brew_cask_install google-chrome 'Google Chrome'
brew_cask_install iterm2 'iTerm'
brew_cask_install lastpass 'LastPass'

step 'Installing Rust'
test -x ~/.cargo/bin/rustup || curl 'https://sh.rustup.rs' -sSf | sh

step 'Installing Python packages'
$br/pip install neovim
$br/pip3 install neovim pygments

step 'Setting up SSH'
if ! [[ -f ~/.ssh/id_rsa ]]; then
    step 'Generating an SSH key'
    echo -n 'Enter email address to use with Git: '
    read email_address
    ssh-keygen -t rsa -b 4096 -C "$email_address"

    step 'Adding SSH key to keychain'
    eval "$(ssh-agent -s)"
    ssh-add -K ~/.ssh/id_rsa

    step 'Adding SSH key to GitHub'
    pbcopy < ~/.ssh/id_rsa.pub
    echo 'Copied public SSH key to the clipboard'
    echo -n 'Press return to open the browser to GitHub: '
    read
    open 'https://github.com/settings/keys'
    echo -n 'Press return when ready: '
    read
fi

step 'Adding Homebrew GitHub API Token'
secret=~/.config/fish/secret.fish
if ! grep -q HOMEBREW_GITHUB_API_TOKEN $secret; then
    echo 'Create an access token called HOMEBREW_GITHUB_API_TOKEN for [mac]'
    echo -n 'Press return to open the browser to GitHub: '
    read
    open 'https://github.com/settings/tokens/new'
    echo -n 'Press return once you have copied the token: '
    read
    echo -n 'set -x HOMEBREW_GITHUB_API_TOKEN "' >> $secret
    pbpaste >> $secret
    echo '"' >> $secret
fi

step 'Creating GitHub directory'
mkdir -p $gh

step 'Cloning repositories'
clone_git_repo mk12/dotfiles $gh/dotfiles
clone_git_repo mk12/finance $gh/finance
clone_git_repo mk12/scripts $gh/scripts

step 'Symlinking dotfiles'
$gh/dotfiles/link.sh

step 'Linking iTerm2 preferences'
defaults write com.googlecode.iterm2.plist PrefsCustomFolder \
    -string $gh/dotfiles/iterm2
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

step 'Installing Tmux plugins'
clone_git_repo tmux-plugins/tpm ~/.tmux/plugins/tpm

step 'Installing Vim plugins'
$br/vim +PlugInstall +qall
$br/nvim +PlugInstall +qall

step 'Symlinking ~/ia'
if ! [[ -L ~/ia ]]; then
    ln -s "$HOME/Dropbox/iA Writer" ~/ia
    chflags -h hidden ~/ia
fi

step 'Changing login shell to fish'
dscl . -read ~ UserShell | grep -q $br/fish || sudo chsh -s $br/fish $USER

step 'Finished'
echo 'Manual steps:'
echo '  1. Configure System Preferences.'
echo '  2. Install apps from the App Store.'
echo '  3. Set up Time Machine backups.'
