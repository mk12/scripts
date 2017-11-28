#!/bin/bash

status() {
	echo -e "\x1b[31m[SETUP] $*...\x1b[0m"
}

br=/usr/local/bin
gh=$HOME/GitHub

status 'Installing Xcode command line tools'
xcode-select --install

status 'Installing Homebrew'
/usr/bin/ruby -e "$(curl -fsSL \
	https://raw.githubusercontent.com/Homebrew/install/master/install)"

status 'Installing Homebrew formulas'
$br/brew install fish
$br/brew install git
$br/brew install go
$br/brew install aspell
$br/brew install keychain
$br/brew install ledger
$br/brew install neovim/neovim/neovim
$br/brew install python
$br/brew install python3
$br/brew install reattach-to-user-namespace
$br/brew install ruby
$br/brew install sshfs
$br/brew install terminal-notifier
$br/brew install the_silver_searcher
$br/brew install tldr
$br/brew install tmux
$br/brew install universal-ctags
$br/brew install vim

status 'Installing Homebrew cask formulas'
$br/brew cask install authy-desktop
$br/brew cask install emacs
$br/brew cask install google-chrome
$br/brew cask install iterm2
$br/brew cask install lastpass

status 'Installing Rust'
curl 'https://sh.rustup.rs' -sSf | sh

status 'Installing Python packages'
$br/pip install neovim
$br/pip3 install neovim pygments

status 'Installing Ruby gems'
$br/gem install neovim pro

status 'Installing Go packages'
$br/go get golang.org/x/tools/cmd/goimports

status 'Generating an SSH key'
echo -n 'Enter email address to use with Git: '
read email_address
ssh-keygen -t rsa -b 4096 -C "$email_address"

status 'Adding SSH key to ssh-agent'
eval "$(ssh-agent -s)"
ssh-add $HOME/.ssh/id_rsa

status 'Adding SSH key to GitHub'
pbcopy < $HOME/.ssh/id_rsa.pub
echo 'Copied public SSH key to the clipboard'
echo -n 'Press return to open the browser to GitHub: '
read
open 'https://github.com/settings/keys'
echo -n 'Press return when ready: '
read

status 'Creating ~/GitHub directory'
gh=$HOME/GitHub
mkdir $gh

status 'Cloning repositories'
$br/git clone git@github.com:mk12/dotfiles $gh/dotfiles
$br/git clone git@github.com:mk12/scripts $gh/scripts
$br/git clone git@github.com:mk12/finance $gh/finance

status 'Symlinking dotfiles'
$gh/dotfiles/link.sh

status 'Installing Tmux plugins'
$br/git clone git@github.com:tmux-plugins/tpm ~/.tmux/plugins/tpm

status 'Installing Vim plugins'
$br/vim +PlugInstall +qall
$br/nvim +PlugInstall +qall

status 'Symlinking ~/ia'
ln -s "$HOME/Dropbox/iA Writer" $HOME/ia
chflags -h hidden $HOME/ia

status 'Changing login shell to fish'
sudo chsh -s $br/fish $USER

status 'Finished'
echo 'Manual steps:'
echo '  1. Set up iCloud and adjust System Preferences.'
echo '  2. Install apps from the Mac App Store.'
echo '  3. Install fonts from ~/Dropbox/fonts.'
echo '  4. Configure iTerm2 profile settings.'
echo '  5. Set HOMEBREW_GITHUB_API_TOKEN in ~/.config/fish/secret.fish.'
