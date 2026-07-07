#!/usr/bin/env bash
set -uo pipefail

SRC_DIGEST_DIR="/var/lib/tickdistill/capture/digest"
REPO_DIR="/opt/tickdistill-commitment"
DEST_DIGEST_DIR="$REPO_DIR/digest"

mkdir -p "$DEST_DIGEST_DIR"

# Mirror every digest_chain.jsonl file (venue/instrument structure) into the repo.
find "$SRC_DIGEST_DIR" -type f -name "digest_chain.jsonl" 2>/dev/null | while read -r src_file; do
  rel_path="${src_file#$SRC_DIGEST_DIR/}"
  dest_file="$DEST_DIGEST_DIR/$rel_path"
  mkdir -p "$(dirname "$dest_file")"
  cp "$src_file" "$dest_file"
done

cd "$REPO_DIR" || exit 1

# Timestamp every mirrored chain file with OpenTimestamps. Re-stamping
# overwrites the .ots proof for the CURRENT content; git history keeps the
# prior versions of both the .jsonl and the .ots, so earlier proofs remain
# retrievable via `git log`/`git show` even after this file grows tomorrow.
export PATH="$HOME/.local/bin:$PATH"
find "$DEST_DIGEST_DIR" -type f -name "digest_chain.jsonl" | while read -r f; do
  rm -f "$f.ots"
  ots stamp "$f" || echo "WARNING: ots stamp failed for $f" >&2
done

git add -A

if git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

git commit -m "sync: digest chain update $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git push origin main
