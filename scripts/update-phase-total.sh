#!/bin/bash
set -u
# Update the Phase: total in STATE.md after phase add/insert/remove.
# Usage: update-phase-total.sh <planning_root> [--inserted N | --removed N]
#   --inserted N: a phase was inserted at position N (adjust current if >= N)
#   --removed N:  a phase was removed at position N (adjust current if > N)
# Always recalculates total from filesystem.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/summary-utils.sh" ]; then
  # shellcheck source=summary-utils.sh
  source "$SCRIPT_DIR/summary-utils.sh"
else
  # F-06: inline minimal terminal summary parser instead of always returning 0
  count_terminal_summaries() {
    local dir="$1" count=0
    for f in "$dir"/*-SUMMARY.md; do
      [ -f "$f" ] || continue
      local status
      status=$(tr -d '\r' < "$f" 2>/dev/null | sed -n '/^---$/,/^---$/{ /^status:/{ s/^status:[[:space:]]*//; s/["'"'"']//g; p; }; }' | head -1 | tr -d '[:space:]')
      case "$status" in
        complete|completed|partial|failed) count=$((count + 1)) ;;
      esac
    done
    echo "$count"
  }
fi

planning_root="${1:-.vbw-planning}"
state_md="${planning_root}/STATE.md"
phases_dir="${planning_root}/phases"

[ -f "$state_md" ] || exit 0
[ -d "$phases_dir" ] || exit 0

# Parse optional flags
shift || true
action=""
position=0
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --inserted)
      action="inserted"
      position="${2:-0}"
      shift 2 || break
      ;;
    --removed)
      action="removed"
      position="${2:-0}"
      shift 2 || break
      ;;
    *)
      shift
      ;;
  esac
done

# Validate position is a positive integer when provided
if [ -n "$action" ] && ! echo "$position" | grep -qE '^[1-9][0-9]*$'; then
  exit 0
fi

# F-04: List only canonical phase dirs (basenames matching ^[0-9]+-), sorted
sorted_dirs_file="${state_md}.dirs.$$"
find "$phases_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
  while IFS= read -r d; do
    base=$(basename "$d")
    case "$base" in [0-9]*-*) echo "$d" ;; esac
  done |
  (sort -V 2>/dev/null || awk -F/ '{n=$NF; gsub(/[^0-9].*/,"",n); if (n == "") n=0; print (n+0)"\t"$0}' | sort -n -k1,1 -k2,2 | cut -f2-) \
  > "$sorted_dirs_file"

total=$(wc -l < "$sorted_dirs_file" | tr -d ' ')

# F-02: handle zero-phase state — clear stale Phase Status bullets
if [ "$total" -eq 0 ]; then
  if grep -q '^## Phase Status' "$state_md" 2>/dev/null; then
    tmp_zero="${state_md}.tmp.$$"
    awk '
      /^## Phase Status$/ { print; skip = 1; next }
      skip && /^- \*\*Phase [0-9]/ { next }
      skip && /^$/ { skip = 0; print; next }
      skip && /^##/ { skip = 0; print; next }
      skip { next }
      { print }
    ' "$state_md" > "$tmp_zero" 2>/dev/null && \
      mv "$tmp_zero" "$state_md" 2>/dev/null || rm -f "$tmp_zero" 2>/dev/null
  fi
  rm -f "$sorted_dirs_file" 2>/dev/null
  exit 0
fi

# Extract current phase number from Phase: line
current_line=$(grep -m1 '^Phase: ' "$state_md" 2>/dev/null)
if [ -z "$current_line" ]; then
  rm -f "$sorted_dirs_file" 2>/dev/null
  exit 0
fi

current=$(echo "$current_line" | sed 's/^Phase: \([0-9]*\).*/\1/')
if [ -z "$current" ]; then
  rm -f "$sorted_dirs_file" 2>/dev/null
  exit 0
fi

# Adjust current phase number for insert/remove
case "$action" in
  inserted)
    if [ "$current" -ge "$position" ]; then
      current=$((current + 1))
    fi
    ;;
  removed)
    if [ "$current" -gt "$position" ]; then
      current=$((current - 1))
    fi
    ;;
esac

# Clamp current to valid range
[ "$current" -gt "$total" ] && current="$total"
[ "$current" -lt 1 ] && current=1

# F-11: Resolve phase name from sorted position (not filesystem prefix) so
# the Phase: line and Phase Status bullets always agree on numbering.
phase_name=""
phase_dir=$(sed -n "${current}p" "$sorted_dirs_file")
if [ -n "$phase_dir" ]; then
  phase_name=$(basename "$phase_dir" | sed 's/^[0-9]*-//' | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
fi

# Build replacement
if [ -n "$phase_name" ]; then
  replacement="Phase: ${current} of ${total} (${phase_name})"
else
  replacement="Phase: ${current} of ${total}"
fi

# Update STATE.md Phase: line
tmp="${state_md}.tmp.$$"
sed "s/^Phase: .*/${replacement}/" "$state_md" > "$tmp" 2>/dev/null && \
  mv "$tmp" "$state_md" 2>/dev/null || rm -f "$tmp" 2>/dev/null

# Rebuild ## Phase Status section to match current phase directories
new_status_file="${state_md}.newstatus.$$"
phase_idx=0
: > "$new_status_file"
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  phase_idx=$((phase_idx + 1))
  local_name=$(basename "$dir" | sed 's/^[0-9]*-//' | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
  # F-09: detect both canonical (NN-PLAN.md) and legacy (PLAN.md) plan files
  local_plans=$(find "$dir" -maxdepth 1 \( -name '[0-9]*-PLAN.md' -o -name 'PLAN.md' \) 2>/dev/null | wc -l | tr -d ' ')
  local_summaries=$(count_terminal_summaries "$dir")
  if [ "$local_plans" -gt 0 ] && [ "$local_summaries" -ge "$local_plans" ]; then
    status_text="Complete"
  elif [ "$local_summaries" -gt 0 ]; then
    status_text="In progress"
  elif [ "$local_plans" -gt 0 ]; then
    status_text="Planned"
  elif [ "$phase_idx" -eq 1 ]; then
    status_text="Pending planning"
  else
    status_text="Pending"
  fi
  echo "- **Phase ${phase_idx} (${local_name}):** ${status_text}" >> "$new_status_file"
done < "$sorted_dirs_file"

rm -f "$sorted_dirs_file" 2>/dev/null

# Replace existing ## Phase Status section if present
if [ -s "$new_status_file" ] && grep -q '^## Phase Status' "$state_md" 2>/dev/null; then
  tmp2="${state_md}.tmp2.$$"
  NSF="$new_status_file" awk '
    /^## Phase Status$/ {
      print
      while ((getline line < ENVIRON["NSF"]) > 0) print line
      skip = 1
      next
    }
    skip && /^- \*\*Phase [0-9]/ { next }
    skip && /^$/ { skip = 0; print; next }
    skip && /^##/ { skip = 0; print ""; print; next }
    skip { next }
    { print }
  ' "$state_md" > "$tmp2" 2>/dev/null && \
    mv "$tmp2" "$state_md" 2>/dev/null || rm -f "$tmp2" 2>/dev/null
fi
rm -f "$new_status_file" 2>/dev/null
