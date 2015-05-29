# Use fish, not bash
sudo apt-get install fish
echo "\nfish" >> ~/.bashrc

# Other packages
sudo apt-get install silversearcher-ag

# Add dotfiles
mkdir $HOME/src/Development
git clone git@github.com:mk12/dotfiles.git $HOME/src/Development/dotfiles
rm $HOME/.gitconfig
$HOME/src/Development/dotfiles/link.sh

# Set up Vundle
git clone https://github.com/gmarik/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim
vim +PluginInstall +qall now

# Compile the CtrlP C matching extension
cd ~/.vim/bundle/ctrlp-cmatcher
./install.sh
