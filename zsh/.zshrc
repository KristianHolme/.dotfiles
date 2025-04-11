echo "TEST IN ZSHRC"
export TEST_THREE="ZSHRC"
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git
    zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# >>> juliaup initialize >>>

# !! Contents within this block are managed by juliaup !!

path=('/mn/sarpanitu/ansatte-u6/kholme/.juliaup/bin' $path)
export PATH

# <<< juliaup initialize <<<
export JULIA_NUM_THREADS=auto

export EDITOR='nvim'
<<<<<<< Updated upstream
#export QT_QPA_PLATFORMTHEME=qt5ct
#export _JAVA_AWT_WM_NONREPARENTING=1 
source /usr/share/doc/fzf/examples/key-bindings.zsh
source /usr/share/doc/fzf/examples/completion.zsh


#export PATH="/usr/local/cuda-12.6/bin:$PATH"
#export LD_LIBRARY_PATH="/usr/local/cuda-12.6.0/lib64:$LD_LIBRARY_PATH"
export PATH="/usr/local/cuda-12.6/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda-12.6.0/lib64:$LD_LIBRARY_PATH"
export PATH="$PATH:/opt/nvim-linux64/bin"

eval $(keychain --eval --agents ssh id_ed25519)

export PATH=/home/kristian/programmer/ParaView-5.13.2-MPI-Linux-Python3.10-x86_64//bin:$PATH
export PV_PLUGIN_PATH=/home/kristian/programmer/ParaView-5.13.2-MPI-Linux-Python3.10-x86_64/lib/paraview-5.13/plugins
=======
export PATH="$HOME/progs/nvim:$PATH"
export PATH=$PATH:$HOME/.local/kitty.app/bin
export TERM=xterm-256color
export PATH=$HOME/.local/bin:$PATH


module load Python/3.9.6-GCCcore-11.2.0
unset MESA_LOADER_DRIVER_OVERRIDE

#export QT_QPA_PLATFORMTHEME=qt5ct
#export _JAVA_AWT_WM_NONREPARENTING=1 
#source /usr/share/doc/fzf/examples/key-bindings.zsh
#source /usr/share/doc/fzf/examples/completion.zsh

# Auto-start tmux if not already in a tmux session
#if [ -z "$TMUX" ] && [ "$TERM_PROGRAM" != "vscode" ]; then
#    tmux new-session
#fi

#export PATH="/usr/local/cuda-12.6/bin:$PATH"
#export LD_LIBRARY_PATH="/usr/local/cuda-12.6.0/lib64:$LD_LIBRARY_PATH"
export PATH="/mn/sarpanitu/ansatte-u6/kholme/progs/quarto-1.6.42/bin:$PATH"
>>>>>>> Stashed changes
