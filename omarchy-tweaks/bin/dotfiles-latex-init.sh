#!/bin/bash

# Simple LaTeX Project Initialization Script
# Creates basic LaTeX projects with UiO template support

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates/latex"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
LaTeX Project Initialization Script

Usage: $0 [OPTIONS] PROJECT_NAME

Arguments:
    PROJECT_NAME    Name of the project directory to create

Options:
    -t, --type TYPE     Project type: uio-presentation
    -d, --directory DIR Target directory (default: current directory)
    -h, --help         Show this help message

Examples:
    $0 -t uio-presentation my-uio-talk     # Creates UiO presentation project

Available templates:
    uio-presentation  - University of Oslo official beamer presentation
EOF
}

create_project_structure() {
    local project_dir="$1"
    
    log_info "Creating project structure..."
    
    # Basic directories
    mkdir -p "$project_dir"/{src,figures,output}
    mkdir -p "$project_dir/.latexmk"/{aux,out}
    
    # Create .gitignore
    cat > "$project_dir/.gitignore" << 'EOF'
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
.latexmk/
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
}

setup_uio_template() {
    local project_dir="$1"
    local project_name="$2"
    
    log_info "Setting up UiO presentation template..."
    
    if [[ -f "$TEMPLATES_DIR/uio-presentation.tex" && -f "$TEMPLATES_DIR/uio-preamble.tex" ]]; then
        cp "$TEMPLATES_DIR/uio-presentation.tex" "$project_dir/src/main.tex"
        cp "$TEMPLATES_DIR/uio-preamble.tex" "$project_dir/src/uio-preamble.tex"
        
        # Replace PROJECT_NAME placeholder
        sed -i "s/PROJECT_NAME/$project_name/g" "$project_dir/src/main.tex"
    else
        log_error "UiO template files not found in $TEMPLATES_DIR"
        exit 1
    fi
    
    # Create basic .latexmkrc
    cat > "$project_dir/.latexmkrc" << 'EOF'
# LaTeX build configuration
$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';

# Output directories (matches VimTeX config)
$aux_dir = '.latexmk/aux';
$out_dir = 'output';

# Clean up patterns
$clean_ext = 'synctex.gz nav snm vrb figlist makelist fdblatexmk listing bbl bcf run.xml';

# Continuous mode settings
$preview_continuous_mode = 1;
$pdf_previewer = 'zathura %O %S';
EOF
}



main() {
    local project_name=""
    local template_type="uio-presentation"
    local target_directory="."
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                template_type="$2"
                shift 2
                ;;
            -d|--directory)
                target_directory="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                else
                    log_error "Unknown argument: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$project_name" ]]; then
        log_error "Project name is required"
        show_help
        exit 1
    fi
    
    if [[ "$template_type" != "uio-presentation" ]]; then
        log_error "Invalid template type: $template_type"
        log_info "Currently available: uio-presentation"
        exit 1
    fi
    
    # Create project
    local project_dir="$target_directory/$project_name"
    
    if [[ -d "$project_dir" ]]; then
        log_error "Directory $project_dir already exists"
        exit 1
    fi
    
    log_info "Creating UiO presentation project: $project_name"
    log_info "Target directory: $project_dir"
    
    create_project_structure "$project_dir"
    setup_uio_template "$project_dir" "$project_name"
    
    log_success "UiO presentation project '$project_name' created successfully!"
    log_info "Next steps:"
    log_info "  1. cd $project_dir"
    log_info "  2. nvim src/main.tex"
    log_info "  3. Use ,ll to compile and ,lv to view"
}

main "$@"