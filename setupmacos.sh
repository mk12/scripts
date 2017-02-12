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
$br/brew install neovim/neovim/neovim
$br/brew install fzf
$br/brew install the_silver_searcher
$br/brew install ctags
$br/brew install tmux
$br/brew install terminal-notifier
$br/brew install ledger
$br/brew install python3
$br/brew install ruby
$br/brew install go
$br/brew install node
$br/brew cask install osxfuse
$br/brew install homebrew/fuse/tup
$br/brew install httpie
$br/brew install reattach-to-user-namespace

status 'Installing Python packages'
$br/pip3 install pygments

status 'Installing Ruby gems'
$br/gem install pro

status 'Installing Go packages'
$br/go get golang.org/x/tools/cmd/goimports

status 'Installing Hack font'
$br/brew cask install caskroom/fonts/font-hack

status 'Installing terminal profiles'
curl 'https://raw.githubusercontent.com/tomislav/'\
'osx-terminal.app-colors-solarized/master/Solarized%20Dark.terminal' \
	> '/tmp/Solarized Dark.terminal'
curl 'https://raw.githubusercontent.com/tomislav/'\
'osx-terminal.app-colors-solarized/master/Solarized%20Light.terminal' \
	> '/tmp/Solarized Light.terminal'
open '/tmp/Solarized Dark.terminal'
open '/tmp/Solarized Light.terminal'

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

status 'Create PATH directories'
mkdir -p $gh/go/bin
mkdir -p $HOME/.cabal/bin

status 'Symlinking dotfiles'
$gh/dotfiles/link.sh

status 'Installing Tmux plugins'
$br/git clone git@github.com:tmux-plugins/tpm ~/.tmux/plugins/tpm

status 'Installing Vim plugins'
$br/nvim +PlugInstall +qall

status 'Symlinking ~/icloud and ~/ia'
ln -s "$HOME/Library/Mobile Documents/com~apple~CloudDocs" $HOME/icloud
ln -s "$HOME/Library/Mobile Documents/27N4MQEA55~pro~writer/Documents" $HOME/ia

status 'Changing login shell to fish'
sudo chsh -s $br/fish $USER

status 'Finished'
echo 'Manual steps:'
echo '  1. Set up iCloud and adjust System Preferences.'
echo '  2. Install apps from the Mac App Store.'
echo '  3. Install fonts from ~/icloud/fonts.'
echo '  4. Make Solarized Dark the default profile.'
echo '  5. Set HOMEBREW_GITHUB_API_TOKEN in ~/.config/fish/secret.fish.'
