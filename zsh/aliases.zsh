alias chrome='google-chrome'
alias vim='nvim'
alias vi='nvim'

#basic config
function my_zsh_setup() {
    autoload -U zsh-newuser-install
    zsh-newuser-install -f
}
alias zshsetup='my_zsh_setup'


#moving to dirs
alias nvimcfg='cd ~/.config/nvim/'
alias zshcfg='cd ~/.oh-my-zsh/custom/'
alias i3cfg='cd ~/.config/i3'
alias proj='cd ~/Code/prosjekt-master/src'
alias rapp='cd ~/Code/prosjekt-master/rapport'
alias matdir='cd ~/matlab'
alias dot='cd ~/.dotfiles'

#SSH
alias markov='ssh kholme@markov.math.ntnu.no'
alias work='cd work/kholme'

#Running programs
alias projmatlab='matlab -nodesktop -nosplash -r "cd ~/Code/prosjekt-master/src/; mrstModule add prosjektOppgave"'
