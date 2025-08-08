# Aliases
alias j='julia'
alias jp='julia --project=.'
alias lg='lazygit'

#variables
export JULIA_NUM_THREADS=auto

#Operations
alias glall='find . -type d -name ".git" -execdir git pull \;'

# starship prompt
eval "$(starship init bash)"

# zoxide - must be initialized last
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"
fi
