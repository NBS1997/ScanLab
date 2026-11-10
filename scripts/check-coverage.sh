#!/usr/bin/env bash
# Fails when line coverage of the ScanLabCore sources is below the threshold
# (team practice: at least 80% on sensor-independent logic).
# Run after: swift test --package-path Packages/ScanLabCore --enable-code-coverage
set -euo pipefail

THRESHOLD="${1:-80}"
PACKAGE="Packages/ScanLabCore"
JSON="$(swift test --package-path "$PACKAGE" --show-codecov-path)"

python3 - "$JSON" "$THRESHOLD" <<'PY'
import json, sys

path, threshold = sys.argv[1], float(sys.argv[2])
data = json.load(open(path))
covered = total = 0
rows = []
for f in data["data"][0]["files"]:
    name = f["filename"]
    # Only the package's own sources: not tests, not build products.
    if "/Sources/ScanLabCore/" not in name:
        continue
    lines = f["summary"]["lines"]
    covered += lines["covered"]
    total += lines["count"]
    rows.append((name.split("/Sources/ScanLabCore/")[1], lines["percent"]))

for name, pct in sorted(rows):
    print(f"{pct:6.1f}%  {name}")
if total == 0:
    print("::error::No ScanLabCore source files found in the coverage report")
    sys.exit(1)
percent = 100.0 * covered / total
print(f"Core line coverage: {percent:.1f}% ({covered}/{total}); required {threshold:.0f}%")
if percent < threshold:
    print(f"::error::Core line coverage {percent:.1f}% is below {threshold:.0f}%")
    sys.exit(1)
PY
