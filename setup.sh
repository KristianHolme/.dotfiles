#/usr/bin/bash
sudo snap install nvim --classic
sudo apt install xclip
sudo apt install fonts-font-awesome
sudo apt install clang
sudo apt install npm
sudo apt install python3-pip
echo "REMEMBER TO INSTALL FIRACODE NERD FONT!"

ln -s ~/.dotfiles/nvim/ ~/.config/nvim
sudo apt install curl

sudo apt install zsh tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
mkdir ~/.config/tmux
ln -s ~/.dotfiles/tmux/tmux.conf ~/.config/tmux/tmux.conf
echo "REMEMBER TO PREFIX+I FOT TPM!"

#oh my zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
ln -s ~/.dotfiles/zsh/aliases.zsh ~/.oh-my-zsh/custom/aliases.zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
mv ~/.zshrc ~/.zshrc.bak
ln -s ~/.dotfiles/zsh/.zshrc ~/.zshrc
chsh -s $(which zsh)

curl -fsSL https://install.julialang.org | sh
ln -s ~/.dotfiles/julia_config ~/.julia/config

sudo apt install guake alacritty fzf ripgrep zathura xdotool
sudo snap install code --classic
#alacritty
ln -s ~/.dotfiles/alacritty/ ~/.config/alacritty
sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/alacritty 50
echo "configuring alacritty..."
sudo update-alternatives --config x-terminal-emulator

#ghostty
ln -s ~/.dotfiles/ghostty/config ~/.config/ghostty/config

