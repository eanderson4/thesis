#!/usr/bin/env bash
# Export the curated figure set in figures/ as trimmed PNGs.
#
# Most figures are already standalone LaTeX documents compiled by `make figures`.
# Two are not: fig-parallel is \input as a bare tikzpicture, and fig-cascade is a
# multi-panel `figure` environment, so both get a small wrapper document here.
#
# Usage: ./scripts/export-figures.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$PWD
OUT=$ROOT/figures
DPI=${DPI:-140}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT"
command -v lualatex >/dev/null || { echo "lualatex not found"; exit 1; }
command -v pdftoppm >/dev/null || { echo "pdftoppm (poppler-utils) not found"; exit 1; }

# render <source.pdf> <output-name>
render() {
  pdfcrop --margins 4 "$1" "$TMP/crop.pdf" >/dev/null
  pdftoppm -r "$DPI" -png -singlefile "$TMP/crop.pdf" "$OUT/$2"
  echo "  figures/$2.png"
}

# wrap <dir> <fig-basename> <output-name> <preamble-extras> <body-extras>
wrap() {
  local dir=$1 fig=$2 name=$3 pre=${4:-} body=${5:-}
  cat > "$ROOT/$dir/_figwrap.tex" <<EOF
\\documentclass[11pt]{article}
\\usepackage[margin=8pt,paperwidth=7.5in,paperheight=10in]{geometry}
\\usepackage{tikz,pgfplots,caption,subcaption,amsmath}
\\usetikzlibrary{shapes.geometric,arrows,shadows,backgrounds,calc}
\\pagestyle{empty}
\\captionsetup{font=footnotesize}
$pre
\\begin{document}$body
\\input{$fig}
\\end{document}
EOF
  ( cd "$ROOT/$dir" && lualatex -interaction=nonstopmode -halt-on-error _figwrap.tex >/dev/null 2>&1 )
  render "$ROOT/$dir/_figwrap.pdf" "$name"
  rm -f "$ROOT/$dir"/_figwrap.*
}

echo "Exporting figures at ${DPI} dpi..."

# Ch. 2 -- a cascade walked stage by stage on the IEEE 14-bus system.
wrap msip fig-cascade cascade-example

# Ch. 3 -- the response surface the derivative-free search has to work on.
render "$ROOT/dfo/fig-heatmap.pdf"      capacity-surface
render "$ROOT/dfo/fig-linecluster.pdf" line-breakpoints
render "$ROOT/dfo/fig-optroute.pdf"    risk-measures
render "$ROOT/dfo/fig-effectivecapacity.pdf" effective-capacity

# Ch. 3 -- how ~1000-2000 trial points per iteration actually got evaluated.
wrap dfo fig-parallel parallel-search "" "\\footnotesize"

# Ch. 4 -- what the joint chance constraint buys you over a plain OPF.
render "$ROOT/jcc/fig-costriskfront.pdf" cost-risk-frontier

echo "Done."
