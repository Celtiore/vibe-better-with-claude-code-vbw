#!/usr/bin/env bash
set -euo pipefail

# rtk-setup.sh — Install RTK (Rust Token Killer) and activate Claude Code hook.
#
# Usage:
#   bash scripts/rtk-setup.sh           # Interactive install + hook setup
#   bash scripts/rtk-setup.sh --check   # Check RTK status only (no install)
#   bash scripts/rtk-setup.sh --hook    # Skip install, just run rtk init -g
#
# This script:
#   1. Detects platform (macOS/Linux) and available package managers
#   2. Proposes the best install method (brew > curl > cargo)
#   3. Installs the RTK binary with user confirmation
#   4. Runs `rtk init -g` to wire the Claude Code hook
#   5. Verifies the full setup
#
# VBW principle: this script ASKS before doing anything. No silent installs.

# --- Colors (if terminal supports them) ---
if [ -t 1 ]; then
  BOLD='\033[1m' DIM='\033[2m' GREEN='\033[32m' YELLOW='\033[33m' RED='\033[31m' RESET='\033[0m'
else
  BOLD='' DIM='' GREEN='' YELLOW='' RED='' RESET=''
fi

info()  { printf "${BOLD}%s${RESET}\n" "$*"; }
ok()    { printf "${GREEN}  ✓ %s${RESET}\n" "$*"; }
warn()  { printf "${YELLOW}  ⚠ %s${RESET}\n" "$*"; }
fail()  { printf "${RED}  ✗ %s${RESET}\n" "$*"; }
dim()   { printf "${DIM}  %s${RESET}\n" "$*"; }

# --- Status check ---
check_status() {
  local binary=false hook=false version=""

  if command -v rtk &>/dev/null; then
    binary=true
    version=$(rtk --version 2>/dev/null | head -1 | sed 's/^rtk //' || true)
  fi

  # Check for Claude Code hook
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  if [ -f "$claude_dir/hooks/rtk-rewrite.sh" ] || [ -f "$HOME/.claude/hooks/rtk-rewrite.sh" ]; then
    hook=true
  fi

  info "RTK Status"
  echo ""
  if [ "$binary" = true ]; then
    ok "Binary: installed (v${version})"
  else
    fail "Binary: not found"
  fi

  if [ "$hook" = true ]; then
    ok "Claude Code hook: active"
  else
    fail "Claude Code hook: not installed"
  fi

  if [ "$binary" = true ] && [ "$hook" = true ]; then
    echo ""
    ok "RTK is fully active"
    # Show gains if available
    if command -v jq &>/dev/null; then
      local gains
      gains=$(rtk gain --all --format json 2>/dev/null || echo "{}")
      local pct
      pct=$(printf '%s' "$gains" | jq -r '.avg_savings_pct // 0' 2>/dev/null || echo "0")
      if [ "$pct" != "0" ] && [ "$pct" != "null" ]; then
        dim "Average token savings: ${pct}%"
      else
        dim "No compression data yet — run some commands first"
      fi
    fi
    return 0
  fi
  return 1
}

# --- Detect best install method ---
detect_install_method() {
  local methods=()

  if command -v brew &>/dev/null; then
    methods+=("brew")
  fi

  # curl is almost always available
  if command -v curl &>/dev/null; then
    methods+=("curl")
  fi

  if command -v cargo &>/dev/null; then
    methods+=("cargo")
  fi

  if [ ${#methods[@]} -eq 0 ]; then
    echo "none"
    return
  fi

  # Return best option (brew preferred for clean upgrades)
  echo "${methods[0]}"
}

# --- Install RTK binary ---
install_binary() {
  local method="$1"

  case "$method" in
    brew)
      info "Installing RTK via Homebrew..."
      dim "brew install rtk"
      echo ""
      brew install rtk
      ;;
    curl)
      info "Installing RTK via install script..."
      dim "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
      echo ""
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

      # Ensure ~/.local/bin is in PATH for this session
      if ! command -v rtk &>/dev/null && [ -f "$HOME/.local/bin/rtk" ]; then
        export PATH="$HOME/.local/bin:$PATH"
        warn "Added ~/.local/bin to PATH for this session"
        dim "Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
      fi
      ;;
    cargo)
      info "Installing RTK from source via Cargo..."
      dim "cargo install --git https://github.com/rtk-ai/rtk"
      echo ""
      cargo install --git https://github.com/rtk-ai/rtk
      ;;
    *)
      fail "No supported package manager found (need brew, curl, or cargo)"
      return 1
      ;;
  esac

  # Verify
  if command -v rtk &>/dev/null; then
    local ver
    ver=$(rtk --version 2>/dev/null | head -1 | sed 's/^rtk //' || true)
    ok "RTK v${ver} installed"
    return 0
  else
    fail "RTK binary not found after install"
    dim "Check your PATH or try a different install method"
    return 1
  fi
}

# --- Setup Claude Code hook ---
setup_hook() {
  info "Setting up Claude Code hook..."
  dim "rtk init -g"
  echo ""

  if rtk init -g; then
    ok "Claude Code hook activated"
    return 0
  else
    fail "rtk init -g failed"
    dim "Try running manually: rtk init -g"
    return 1
  fi
}

# --- Prompt user for confirmation ---
confirm() {
  local prompt="$1"
  local default="${2:-y}"

  if [ "$default" = "y" ]; then
    printf "%s [Y/n] " "$prompt"
  else
    printf "%s [y/N] " "$prompt"
  fi

  read -r answer </dev/tty 2>/dev/null || answer="$default"
  answer="${answer:-$default}"

  case "$answer" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

# ============================================================
# Main
# ============================================================

MODE="${1:-install}"

echo ""
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "RTK Setup — Token compression for Claude Code"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

case "$MODE" in
  --check)
    check_status
    exit $?
    ;;

  --hook)
    if ! command -v rtk &>/dev/null; then
      fail "RTK binary not found. Run without --hook to install first."
      exit 1
    fi
    setup_hook
    echo ""
    check_status
    exit 0
    ;;

  install|*)
    # Step 1: Check current status
    if check_status 2>/dev/null; then
      echo ""
      ok "Nothing to do — RTK is already fully configured"
      exit 0
    fi

    echo ""

    # Step 2: Install binary if needed
    if ! command -v rtk &>/dev/null; then
      method=$(detect_install_method)
      if [ "$method" = "none" ]; then
        fail "No package manager found (need brew, curl, or cargo)"
        dim "Install manually: https://github.com/rtk-ai/rtk"
        exit 1
      fi

      # Show what we'll do
      case "$method" in
        brew)  dim "Will run: brew install rtk" ;;
        curl)  dim "Will run: curl install script → ~/.local/bin/rtk" ;;
        cargo) dim "Will run: cargo install from source (may take a few minutes)" ;;
      esac
      echo ""

      if confirm "Install RTK via ${method}?"; then
        echo ""
        if ! install_binary "$method"; then
          exit 1
        fi
      else
        dim "Skipped binary install"
        exit 0
      fi
      echo ""
    else
      ok "RTK binary already installed"
    fi

    # Step 3: Setup Claude Code hook if needed
    local_claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    if [ ! -f "$local_claude_dir/hooks/rtk-rewrite.sh" ] && [ ! -f "$HOME/.claude/hooks/rtk-rewrite.sh" ]; then
      echo ""
      if confirm "Activate Claude Code hook (rtk init -g)?"; then
        echo ""
        setup_hook
      else
        dim "Skipped hook setup"
        dim "Run 'rtk init -g' later to activate"
      fi
    else
      ok "Claude Code hook already active"
    fi

    # Step 4: Final status
    echo ""
    info "━━━ Final Status ━━━"
    echo ""
    check_status
    ;;
esac
