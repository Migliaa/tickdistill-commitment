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

# --- Provenance hook 1 (ops #O6): config-hash of the serving calibration surface ---
# Proves *which* rank/Schmitt/knob-default calibration code was checked out on this
# day, without executing product code or touching capture/'s own digest schema.
# This is a git tree-hash PROXY (hashes the directory contents at whatever commit
# /opt/tickdistill is checked out to) — NOT the engine's own rank_config_hash()
# semantic value (that would require running engine code; escalated separately,
# see ops/INTERFACE.md #P-config-hash-hook).
PRIVATE_REPO="/opt/tickdistill"
CONFIG_HASH_LOG="$REPO_DIR/config_hash_log.jsonl"
if [ -d "$PRIVATE_REPO/.git" ]; then
  CONFIG_TREE_HASH=$(git -C "$PRIVATE_REPO" rev-parse HEAD:engine/app/signals 2>/dev/null)
  SOURCE_COMMIT=$(git -C "$PRIVATE_REPO" rev-parse HEAD 2>/dev/null)
  TODAY_UTC=$(date -u +%Y-%m-%d)
  if [ -n "$CONFIG_TREE_HASH" ] && [ -n "$SOURCE_COMMIT" ]; then
    LAST_DAY=$(tail -n1 "$CONFIG_HASH_LOG" 2>/dev/null | python3 -c "import json,sys
d=sys.stdin.read().strip()
print(json.loads(d)['day']) if d else print('')" 2>/dev/null)
    if [ "$LAST_DAY" != "$TODAY_UTC" ]; then
      printf '{"day": "%s", "config_hash": "%s", "source_commit": "%s", "source_path": "engine/app/signals", "note": "git tree-hash proxy, not the engine rank_config_hash() semantic value"}\n' \
        "$TODAY_UTC" "$CONFIG_TREE_HASH" "$SOURCE_COMMIT" >> "$CONFIG_HASH_LOG"
    fi
  else
    echo "WARNING: could not compute config-hash from $PRIVATE_REPO (skipping, provenance hook is best-effort)" >&2
  fi
else
  echo "WARNING: $PRIVATE_REPO is not a git checkout, skipping config-hash provenance hook" >&2
fi

# Timestamp every mirrored chain file with OpenTimestamps. Re-stamping
# overwrites the .ots proof for the CURRENT content; git history keeps the
# prior versions of both the .jsonl and the .ots, so earlier proofs remain
# retrievable via `git log`/`git show` even after this file grows tomorrow.
export PATH="$HOME/.local/bin:$PATH"
find "$DEST_DIGEST_DIR" -type f -name "digest_chain.jsonl" | while read -r f; do
  rm -f "$f.ots"
  ots stamp "$f" || echo "WARNING: ots stamp failed for $f" >&2
done

if [ -f "$CONFIG_HASH_LOG" ]; then
  rm -f "$CONFIG_HASH_LOG.ots"
  ots stamp "$CONFIG_HASH_LOG" || echo "WARNING: ots stamp failed for $CONFIG_HASH_LOG" >&2
fi

git add -A

if git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

git commit -m "sync: digest chain update $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git push origin main
