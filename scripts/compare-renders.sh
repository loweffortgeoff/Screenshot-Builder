#!/bin/zsh
# Renders the chapter 2 slot projects at two revisions and compares every export pixel by pixel.
# Usage: scripts/compare-renders.sh <revA> <revB>. A revision is a commit, or "." for this checkout as it is.
# SB_SLOTS: the folder of slot projects (<slot>/Sample.shotset). SB_COMPARE_WORK: where builds and renders go.
# Exit code 0 when every export matches.
set -euo pipefail
cd "${0:A:h}/.."
repo=$PWD
slots="${SB_SLOTS:-$HOME/Documents/Dev Workstation/Visual Verification/screenshot builder/ch3-check/assets/c2r3src}"
work="${SB_COMPARE_WORK:-${TMPDIR:-/tmp}/sb-compare}"
mkdir -p "$work"

tree_for() { # prints a source tree for a revision
  local rev=$1
  if [[ $rev == "." ]]; then print "$repo"; return; fi
  local sha=$(git -C "$repo" rev-parse --short "$rev")
  local dir="$work/src-$sha"
  if [[ ! -d $dir ]]; then mkdir -p "$dir"; git -C "$repo" archive "$sha" | tar -x -C "$dir"; fi
  print "$dir"
}

render_all() { # tree, output folder
  local tree=$1 out=$2
  rm -rf "$out"; mkdir -p "$out"
  for project in "$slots"/*/Sample.shotset; do
    local slot=${project:h:t}
    (cd "$tree" && SB_PROJECT="$project" SB_OUT="$out/$slot" swift test --filter SampleRenderTests >"$out/$slot.log" 2>&1) \
      || { print "render failed: $slot at $tree"; tail -5 "$out/$slot.log"; exit 2; }
  done
}

a=$(tree_for "$1"); b=$(tree_for "$2")
render_all "$a" "$work/out-a"
render_all "$b" "$work/out-b"
rc=0
for file in "$work/out-a"/*/*.png; do
  rel=${file#$work/out-a/}
  result=$(swift "$repo/scripts/compare-pngs.swift" "$file" "$work/out-b/$rel") || rc=1
  print "$rel: $result"
done
(( rc == 0 )) && print "All exports match." || print "Some exports differ."
exit $rc
