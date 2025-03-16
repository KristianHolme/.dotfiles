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
alias proj='cd ~/Code/SPE11/project_root'
alias rapp='cd ~/Code/SPE11/rapport'
alias matdir='cd ~/matlab'
alias dot='cd ~/.dotfiles'
alias projout='cd /media/kristian/HDD/matlab/output/'
alias sosi='cd ~/Code/Sommer2024-SINTEF'
alias dev='cd ~/.julia/dev'
alias drl='cd ~/Code/DRL_RDE/'
alias julia='julia --project=.'

#Operations
alias glall='find . -type d -name ".git" -execdir git pull \;'
=======


#Running programs
alias projmatlab='matlab -nodesktop -nosplash -r "cd ~/Code/SPE11/project_root/;setup"'
# Jutul Daemon
alias jutulDaemon='julia --project="~/Code/prosjekt-master/jutul" --startup-file=no --color=no -e "using Revise; using DaemonMode; using HYPRE; serve(async=true)"'

alias mp4towmv='convert_mp4_to_wmv'
convert_mp4_to_wmv() {
    if [[ -z "$1" ]]; then
        echo "Usage: mp4towmv <filename.mp4>"
        return 1
    fi
    local input_file="$1"
    local output_file="${input_file%.mp4}.wmv"
    ffmpeg -i "$input_file" -c:v wmv2 -b:v 2M -c:a wmav2 -b:a 192k "$output_file"
    echo "Conversion completed: $output_file"
}

#Scripts
alias monsw='~/Code/scripts/workspace/secondary_screen_switch.sh'
