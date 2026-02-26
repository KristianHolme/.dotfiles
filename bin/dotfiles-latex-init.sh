#!/bin/bash

# LaTeX Project Initialization Script
# Creates basic LaTeX projects with UiO template support
# Run without arguments for interactive mode

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
TEMPLATES_DIR="$SCRIPT_DIR/../templates/latex"

show_help() {
    cat <<EOF
LaTeX Project Initialization Script

Usage: $0 [OPTIONS] [PROJECT_NAME]

Arguments:
    PROJECT_NAME    Name of the project directory to create
                    (omit when using --here; optional in interactive mode)

Options:
    -t, --type TYPE     Project type: default|uio-presentation
    -d, --directory DIR Target directory (default: current directory)
    --here             Initialize in current directory instead of creating
                       a new subdirectory. Uses directory name as project title.
    --no-git           Skip Git initialization
    -h, --help         Show this help message

When called without any arguments, enters interactive mode.

Examples:
    $0                                         # Interactive mode
    $0 my-doc                                  # New project with defaults
    $0 -t uio-presentation my-uio-talk         # New UiO presentation project
    $0 --here                                  # Paste template into current dir
    $0 --here -t uio-presentation              # UiO template in current dir

Available templates:
    default           - Plain LaTeX article with minimal preamble
    uio-presentation  - University of Oslo official beamer presentation
EOF
}

# Config globals (set by parse_args or interactive_setup)
PROJECT_NAME=""
TEMPLATE_TYPE="default"
TARGET_DIRECTORY="."
INIT_GIT=true
HERE_MODE=false

interactive_setup() {
    ensure_cmd "gum"

    local mode
    mode=$(gum choose --header "Project location:" \
        "Create new project directory" \
        "Initialize in current directory") || exit 0

    case "$mode" in
    "Initialize in current directory")
        HERE_MODE=true
        PROJECT_NAME=$(gum input \
            --header "Project title (for document):" \
            --value "$(basename "$PWD")" \
            --placeholder "my-project") || exit 0
        [[ -z "$PROJECT_NAME" ]] && PROJECT_NAME="$(basename "$PWD")"
        ;;
    "Create new project directory")
        PROJECT_NAME=$(gum input \
            --header "Project name (required):" \
            --placeholder "my-project") || exit 0
        if [[ -z "$PROJECT_NAME" ]]; then
            log_error "Project name is required"
            exit 1
        fi
        ;;
    esac

    TEMPLATE_TYPE=$(gum choose --header "Template type:" \
        "default" "uio-presentation") || TEMPLATE_TYPE="default"

    if ! gum confirm "Initialize git repository?" --default=true; then
        INIT_GIT=false
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -t | --type)
            TEMPLATE_TYPE="$2"
            shift 2
            ;;
        -d | --directory)
            TARGET_DIRECTORY="$2"
            shift 2
            ;;
        --here)
            HERE_MODE=true
            shift
            ;;
        --no-git)
            INIT_GIT=false
            shift
            ;;
        -h | --help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$PROJECT_NAME" ]]; then
                PROJECT_NAME="$1"
            else
                log_error "Unknown argument: $1"
                show_help
                exit 1
            fi
            shift
            ;;
        esac
    done

    # In --here mode, derive project name from directory if not given
    if [[ "$HERE_MODE" == true && -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME="$(basename "$(realpath "$TARGET_DIRECTORY")")"
    fi

    # Without --here, project name is required
    if [[ "$HERE_MODE" != true && -z "$PROJECT_NAME" ]]; then
        log_error "Project name is required (or use --here)"
        show_help
        exit 1
    fi
}

create_project_structure() {
    local project_dir="$1"

    log_info "Creating project structure..."
    mkdir -p "$project_dir"/{src,figures,output,aux}

    if [[ -f "$project_dir/.gitignore" ]]; then
        log_info ".gitignore already exists; skipping"
    else
        cat >"$project_dir/.gitignore" <<'EOF'
# LaTeX auxiliary files
*.aux
*.fdb_latexmk
*.fls
*.log
*.out
*.toc
*.bbl
*.blg
*.bcf
*.run.xml
*.synctex.gz
*.nav
*.snm
*.vrb

# Build directories
aux/
output/

# OS generated files
.DS_Store
Thumbs.db

# Backup files
*~
*.backup
*.bak

# Editor files
.vscode/
*.swp
*.swo
EOF
    fi
}

setup_git_repo() {
    local project_dir="$1"
    local project_name="$2"

    log_info "Initializing Git repository..."

    cd "$project_dir"
    git init

    # Set up Git LFS for figures
    git lfs install
    git lfs track "figures/*"
    git lfs track "*.png"
    git lfs track "*.jpg"
    git lfs track "*.jpeg"
    git lfs track "*.pdf"
    git lfs track "*.eps"

    # Add .gitattributes
    git add .gitattributes

    # Initial commit
    git add .
    git commit -m "Initial commit: LaTeX project '$project_name'"

    log_success "Git repository initialized with LFS for figures"
}

push_to_github() {
    local project_name="$1"

    if ! command -v gum >/dev/null 2>&1 || ! command -v gh >/dev/null 2>&1; then
        log_warning "gum or gh CLI not found. Skipping GitHub push option."
        log_info "Install with: pacman -S gum github-cli"
        return 0
    fi

    local push_choice
    push_choice=$(gum choose \
        "Yes, create and push to GitHub" \
        "No, keep local only" \
        --header "Create GitHub repository and push?") || return 0

    case "$push_choice" in
    "Yes, create and push to GitHub")
        log_info "Creating GitHub repository..."

        local repo_visibility
        repo_visibility=$(gum choose \
            "private" \
            "public" \
            --header "Repository visibility:") || repo_visibility="private"

        if gh repo create "$project_name" --"$repo_visibility" --source=. --remote=origin --push; then
            log_success "Repository created and pushed to GitHub!"
            log_info "Repository URL: https://github.com/$(gh api user --jq .login)/$project_name"
        else
            log_error "Failed to create GitHub repository"
        fi
        ;;
    "No, keep local only")
        log_info "Repository kept local only"
        ;;
    esac
}

setup_uio_template() {
    local project_dir="$1"
    local project_name="$2"

    log_info "Setting up UiO presentation template..."

    if [[ -f "$TEMPLATES_DIR/uio-presentation.tex" && -f "$TEMPLATES_DIR/uio-preamble.tex" ]]; then
        cp "$TEMPLATES_DIR/uio-presentation.tex" "$project_dir/src/main.tex"
        cp "$TEMPLATES_DIR/uio-preamble.tex" "$project_dir/src/uio-preamble.tex"

        sed -i "s/PROJECT_NAME/$project_name/g" "$project_dir/src/main.tex"
    else
        log_error "UiO template files not found in $TEMPLATES_DIR"
        exit 1
    fi
}

setup_default_template() {
    local project_dir="$1"
    local project_name="$2"

    log_info "Setting up default plain document template..."

    if [[ -f "$TEMPLATES_DIR/default-main.tex" && -f "$TEMPLATES_DIR/default-preamble.tex" ]]; then
        cp "$TEMPLATES_DIR/default-main.tex" "$project_dir/src/main.tex"
        cp "$TEMPLATES_DIR/default-preamble.tex" "$project_dir/src/preamble.tex"
        sed -i "s/PROJECT_NAME/$project_name/g" "$project_dir/src/main.tex"
    else
        log_error "Default template files not found in $TEMPLATES_DIR"
        exit 1
    fi
}

execute_setup() {
    # Validate template type
    if [[ "$TEMPLATE_TYPE" != "uio-presentation" && "$TEMPLATE_TYPE" != "default" ]]; then
        log_error "Invalid template type: $TEMPLATE_TYPE"
        log_info "Available: default, uio-presentation"
        exit 1
    fi

    # Determine project directory
    local project_dir
    if [[ "$HERE_MODE" == true ]]; then
        project_dir="$TARGET_DIRECTORY"
    else
        project_dir="$TARGET_DIRECTORY/$PROJECT_NAME"
        if [[ -d "$project_dir" ]]; then
            log_error "Directory $project_dir already exists"
            exit 1
        fi
    fi

    # Guard against overwriting existing template files
    if [[ -f "$project_dir/src/main.tex" ]]; then
        log_error "src/main.tex already exists in $project_dir"
        exit 1
    fi

    log_info "Creating LaTeX project ($TEMPLATE_TYPE): $PROJECT_NAME"
    if [[ "$HERE_MODE" == true ]]; then
        log_info "Initializing in: $(realpath "$project_dir")"
    else
        log_info "Target directory: $project_dir"
    fi

    create_project_structure "$project_dir"

    case "$TEMPLATE_TYPE" in
    "uio-presentation")
        setup_uio_template "$project_dir" "$PROJECT_NAME"
        ;;
    "default")
        setup_default_template "$project_dir" "$PROJECT_NAME"
        ;;
    esac

    if [[ "$INIT_GIT" == true ]]; then
        setup_git_repo "$project_dir" "$PROJECT_NAME"
        push_to_github "$PROJECT_NAME"
    fi

    log_success "LaTeX project '$PROJECT_NAME' created successfully!"
    log_info "Next steps:"
    if [[ "$HERE_MODE" != true ]]; then
        log_info "  1. cd $project_dir"
        log_info "  2. nvim src/main.tex"
    else
        log_info "  1. nvim src/main.tex"
    fi
    log_info "  Use ,ll to compile and ,lv to view"

    if [[ "$INIT_GIT" == true ]]; then
        log_info "  Large figures will be tracked with Git LFS automatically"
    fi
}

main() {
    if [[ $# -eq 0 ]]; then
        interactive_setup
    else
        parse_args "$@"
    fi
    execute_setup
}

main "$@"
