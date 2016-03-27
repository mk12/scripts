#!/bin/bash

status() {
	echo "\x1b[31m[SETUP] $*...\x1b[0m"
}

br=/usr/local/bin
gh=$HOME/GitHub

status 'Installing Xcode command line tools'
xcode-select --install

status 'Installing Homebrew'
/usr/bin/ruby -e "$(curl -fsSL \
	https://raw.githubusercontent.com/Homebrew/install/master/install)"

status 'Installing Homebrew formulas'
$br/brew install \
	fish git vim tup fzf the_silver_searcher universal-ctags tmux \
	reattach-to-user-namespace terminal-notifier ledger python3 ruby go

status 'Installing pip3 packages'
$br/pip3 install pygments

status 'Installing Ruby gems'
$br/gem install pro

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

status 'Installing Vim plugins'
$br/vim +PlugInstall +qall

status 'Symlinking ~/icloud and ~/ia'
ln -s $HOME/Library/Mobile Documents/com~apple~CloudDocs $HOME/icloud
ln -s $HOME/Library/Mobile Documents/27N4MQEA55~pro~writer/Documents $HOME/ia

status 'Changing login shell to fish'
chsh -s $br/fish

status 'Finished'
echo 'Manual steps:'
echo '  1. Install apps from Mac App Store'
echo '  2. Adjust System Preferences'
echo '  3. Install fonts from ~/icloud/fonts'
