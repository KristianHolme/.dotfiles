#!/usr/bin/env bash
#
# Configure global Git SSH commit signing and optional GitHub signing key upload.
# - gpg.format ssh, user.signingkey (public key path), commit.gpgsign, gpg.ssh.allowedSignersFile
# - ~/.ssh/allowed_signers for local: git log --show-signature

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-dotfiles.sh
source "$SCRIPT_DIR/lib-dotfiles.sh"

ALLOWED_SIGNERS_FILE="${ALLOWED_SIGNERS_FILE:-$HOME/.ssh/allowed_signers}"
KEY_BASE_DEFAULT="$HOME/.ssh/id_ed25519"

LOCAL_ONLY=0
GITHUB_ONLY=0
KEY_BASE="$KEY_BASE_DEFAULT"
EMAIL_OVERRIDE=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Configure SSH commit signing (global git config + ~/.ssh/allowed_signers) and
optionally upload the public key to GitHub as a signing key.

Prerequisites:
  - git, gh (for GitHub upload)
  - ~/.ssh/id_ed25519 and id_ed25519.pub (or override with --key)
  - git config --global user.email set, or pass --email

Options:
  -h, --help       Show this help
  --local-only     Skip gh ssh-key add (GitHub already has the key, or offline)
  --github-only    Only upload key to GitHub; skip allowed_signers and git config
  --key PATH       SSH key base path (default: ~/.ssh/id_ed25519; public: PATH.pub)
  --email ADDR     Principal email for allowed_signers (default: git config user.email)

GitHub key title: <hostname> signing <YYYY-MM-DD>

Idempotent: steps that are already satisfied log [INFO] and are skipped.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --local-only)
            LOCAL_ONLY=1
            shift
            ;;
        --github-only)
            GITHUB_ONLY=1
            shift
            ;;
        --key)
            KEY_BASE="${2:-}"
            shift 2
            ;;
        --email)
            EMAIL_OVERRIDE="${2:-}"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "$LOCAL_ONLY" -eq 1 && "$GITHUB_ONLY" -eq 1 ]]; then
    log_error "Use only one of --local-only and --github-only"
    exit 1
fi

PUB_KEY_FILE="${KEY_BASE}.pub"

if [[ ! -f "$KEY_BASE" ]]; then
    log_error "Private key not found: $KEY_BASE"
    log_error "Generate with: ssh-keygen -t ed25519 -f \"$KEY_BASE\""
    exit 1
fi

if [[ ! -f "$PUB_KEY_FILE" ]]; then
    log_error "Public key not found: $PUB_KEY_FILE"
    exit 1
fi

# Resolve email for allowed_signers (not needed for GitHub-only upload)
EMAIL=""
if [[ "$GITHUB_ONLY" -eq 0 ]]; then
    if [[ -n "$EMAIL_OVERRIDE" ]]; then
        EMAIL="$EMAIL_OVERRIDE"
    else
        EMAIL="$(git config --global user.email 2>/dev/null || true)"
    fi
    if [[ -z "${EMAIL// }" ]]; then
        log_error "No git user.email set. Run: git config --global user.email 'you@example.com'"
        log_error "Or pass: --email 'you@example.com'"
        exit 1
    fi
fi

if [[ "$LOCAL_ONLY" -eq 0 ]]; then
    ensure_cmd git gh
    if ! gh_is_authed; then
        log_error "gh is not logged in to github.com. Run: gh auth login"
        exit 1
    fi
else
    ensure_cmd git
fi

# Returns 0 if gh ssh-key list shows this public key as a signing key (tab-separated columns).
gh_signing_key_already_on_github() {
    local pub_kt pub_kb
    read -r pub_kt pub_kb _ < <(awk '{print $1, $2; exit}' "$PUB_KEY_FILE")
    gh ssh-key list 2>/dev/null | grep -v '^warning:' |
        awk -F'\t' -v kt="$pub_kt" -v kb="$pub_kb" '$2 == kt && $3 == kb && $6 == "signing" { found = 1 } END { exit !found }'
}

gh_add_signing_key() {
    local title out ec
    if gh_signing_key_already_on_github; then
        log_info "GitHub: SSH signing key for this public key is already registered; skipping gh ssh-key add"
        return 0
    fi
    title="$(hostname) signing $(date +%Y-%m-%d)"
    log_info "Adding SSH signing key to GitHub (title: $title)..."
    set +e
    out="$(gh ssh-key add "$PUB_KEY_FILE" --title "$title" --type signing 2>&1)"
    ec=$?
    set -e
    if [[ "$ec" -eq 0 ]]; then
        log_success "GitHub: SSH signing key added"
        [[ -n "$out" ]] && log_info "$out"
        return 0
    fi
    if echo "$out" | grep -qiE 'already|exists|duplicate|key is already'; then
        log_info "GitHub: SSH signing key already present ($out)"
        return 0
    fi
    log_warning "gh ssh-key add failed (exit $ec): $out"
    log_warning "If this key is already a signing key on GitHub, you can ignore this."
    return 0
}

update_allowed_signers() {
    local pub_line new_line tmp
    pub_line="$(head -1 "$PUB_KEY_FILE" | tr -d '\r')"
    if [[ -z "$pub_line" ]]; then
        log_error "Empty or unreadable public key: $PUB_KEY_FILE"
        exit 1
    fi
    # namespaces="git" matches Git SSH signature verification; see git gpg.ssh.allowedSignersFile
    new_line="${EMAIL} namespaces=\"git\" ${pub_line}"

    if [[ -f "$ALLOWED_SIGNERS_FILE" ]] && grep -Fxq "$new_line" "$ALLOWED_SIGNERS_FILE"; then
        log_info "allowed_signers already contains this entry; skipping $ALLOWED_SIGNERS_FILE"
        return 0
    fi

    tmp="$(mktemp)"
    if [[ -f "$ALLOWED_SIGNERS_FILE" ]]; then
        grep -vF "${EMAIL} " "$ALLOWED_SIGNERS_FILE" >"$tmp" 2>/dev/null || true
    else
        : >"$tmp"
    fi
    printf '%s\n' "$new_line" >>"$tmp"
    mkdir -p "$(dirname "$ALLOWED_SIGNERS_FILE")"
    mv "$tmp" "$ALLOWED_SIGNERS_FILE"
    chmod 644 "$ALLOWED_SIGNERS_FILE"
    log_success "Wrote $ALLOWED_SIGNERS_FILE"
}

set_git_global_signing() {
    local pub_abs allowed_abs cur_fmt cur_key cur_sign cur_allowed
    pub_abs="$(realpath "$PUB_KEY_FILE")"
    allowed_abs="$(realpath -m "$ALLOWED_SIGNERS_FILE")"

    cur_fmt="$(git config --global --get gpg.format 2>/dev/null || true)"
    cur_sign="$(git config --global --get commit.gpgsign 2>/dev/null || true)"
    cur_allowed="$(git config --global --get gpg.ssh.allowedSignersFile 2>/dev/null || true)"
    if [[ -n "$cur_allowed" ]]; then
        cur_allowed="$(realpath -m "$cur_allowed" 2>/dev/null || echo "$cur_allowed")"
    fi
    cur_key=""
    if git config --global --get user.signingkey &>/dev/null; then
        cur_key="$(git config --path --global user.signingkey 2>/dev/null || git config --global --get user.signingkey)"
        cur_key="$(realpath "$cur_key" 2>/dev/null || echo "$cur_key")"
    fi

    if [[ "$cur_fmt" == "ssh" ]]; then
        log_info "gpg.format is already ssh; skipping"
    else
        git config --global gpg.format ssh
        log_success "Set gpg.format=ssh"
    fi

    if [[ "$cur_key" == "$pub_abs" ]]; then
        log_info "user.signingkey already points to $pub_abs; skipping"
    else
        git config --global user.signingkey "$pub_abs"
        log_success "Set user.signingkey=$pub_abs"
    fi

    if [[ "$cur_sign" == "true" ]]; then
        log_info "commit.gpgsign is already true; skipping"
    else
        git config --global commit.gpgsign true
        log_success "Set commit.gpgsign=true"
    fi

    if [[ "$cur_allowed" == "$allowed_abs" ]]; then
        log_info "gpg.ssh.allowedSignersFile already set to $allowed_abs; skipping"
    else
        git config --global gpg.ssh.allowedSignersFile "$allowed_abs"
        log_success "Set gpg.ssh.allowedSignersFile=$allowed_abs"
    fi
}

if [[ "$LOCAL_ONLY" -eq 0 ]]; then
    gh_add_signing_key
fi

if [[ "$GITHUB_ONLY" -eq 1 ]]; then
    log_success "GitHub-only run complete."
    exit 0
fi

update_allowed_signers
set_git_global_signing

log_info "Next: make a new commit; then verify with: git log --show-signature -1"
log_info "Existing commits remain unsigned; only new commits are signed."
