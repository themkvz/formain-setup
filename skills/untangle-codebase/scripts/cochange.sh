#!/usr/bin/env bash
# Churn per file and pairs of files that change in the same commit.
# Usage: cochange.sh [since] [top]    e.g. cochange.sh "2 years ago" 50
set -euo pipefail

since="${1:-1 year ago}"
top="${2:-30}"
# Commits touching more files than this are bulk edits (formatting, renames)
# and pair everything with everything, which hides the real signal.
max_files=25

git rev-parse --is-inside-work-tree >/dev/null
log="$(git log --since="$since" --no-merges --name-only --format='tformat:@')"

echo "# Churn: commits per file (since $since)"
grep -v '^@' <<<"$log" | grep . | sort | uniq -c | sort -rn | head -n "$top" || true

echo
echo "# Change together: shared commits, % of the less-changed file's commits"
awk -v max="$max_files" '
  function flush(  i, j, a, b, t) {
    if (n > 1 && n <= max)
      for (i = 0; i < n; i++)
        for (j = i + 1; j < n; j++) {
          a = files[i]; b = files[j]
          if (a > b) { t = a; a = b; b = t }
          pair[a "\t" b]++
        }
    n = 0
  }
  /^@$/ { flush(); next }
  NF    { files[n++] = $0; churn[$0]++ }
  END {
    flush()
    for (p in pair) {
      if (pair[p] < 2) continue
      split(p, f, "\t")
      low = churn[f[1]] < churn[f[2]] ? churn[f[1]] : churn[f[2]]
      printf "%d\t%d%%\t%s\t%s\n", pair[p], 100 * pair[p] / low, f[1], f[2]
    }
  }
' <<<"$log" | sort -t$'\t' -k1,1nr -k2,2nr | head -n "$top" || true
