#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin"

cat > "$tmp_dir/bin/findmnt" <<'STUB'
#!/usr/bin/env bash
cat "$FINDMNT_FIXTURE"
STUB

cat > "$tmp_dir/bin/df" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DF_CALL_LOG"
has_posix=0
has_output=0
for arg in "$@"; do
  [[ "$arg" == "-P" ]] && has_posix=1
  [[ "$arg" == --output=* ]] && has_output=1
done
if ((has_posix && has_output)); then
  printf 'df: options -P and --output are mutually exclusive\n' >&2
  exit 1
fi
if [[ "${SLOW_FIRST_DF:-0}" == 1 ]] && [[ $(wc -l < "$DF_CALL_LOG") -eq 1 ]]; then
  /usr/bin/sleep 5
fi
printf 'Size Used Use%%\n10737418240 5368709120 50%%\n'
STUB
chmod +x "$tmp_dir/bin/findmnt" "$tmp_dir/bin/df"

run_collector() {
  local fixture=$1
  local slow=${2:-0}
  : > "$tmp_dir/df.log"
  PATH="$tmp_dir/bin:$PATH" \
    FINDMNT_FIXTURE="$fixture" \
    DF_CALL_LOG="$tmp_dir/df.log" \
    SLOW_FIRST_DF="$slow" \
    bash "$repo_dir/sysinfo.sh"
}

cat > "$tmp_dir/normal.mounts" <<'FIXTURE'
/dev/root[/@] / ext4
/dev/root[/@home] /home btrfs
/dev/data /mnt/data ext4
server:/share /mnt/net nfs4
/dev/space /mnt/space\x20disk ext4
rclone:remote /mnt/cloud fuse.rclone
/dev/loop0 /mnt/loop ext4
none /proc proc
tmpfs /run tmpfs
FIXTURE

normal_json=$(run_collector "$tmp_dir/normal.mounts")
python3 - "$normal_json" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
assert 0 <= info["cpu"] <= 100
assert 0 <= info["mem"] <= 100
assert isinstance(info["tempAvailable"], bool)
assert isinstance(info["fanAvailable"], bool)
mounts = [volume["mount"] for volume in info["storage"]]
assert mounts == ["/", "/mnt/data", "/mnt/net", "/mnt/space disk", "/mnt/cloud"], mounts
assert all(volume["available"] for volume in info["storage"])
assert info["diskAvailable"] is True
print("PASS: mount filtering, deduplication, escaped paths, JSON metrics")
PY

{
  for i in $(seq 0 65); do
    mount=/mnt/volume-$i
    [[ $i -ne 0 ]] || mount=/
    printf '/dev/volume-%s %s ext4\n' "$i" "$mount"
  done
} > "$tmp_dir/many.mounts"
many_json=$(run_collector "$tmp_dir/many.mounts")
python3 - "$many_json" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
assert len(info["storage"]) == 66, len(info["storage"])
assert len({volume["mount"] for volume in info["storage"]}) == 66
print("PASS: every unique mounted volume is preserved")
PY

cat > "$tmp_dir/slow.mounts" <<'FIXTURE'
/dev/root / ext4
server:/slow /mnt/slow nfs4
/dev/data /mnt/data ext4
FIXTURE
slow_json=$(run_collector "$tmp_dir/slow.mounts" 1)
python3 - "$slow_json" "$tmp_dir/df.log" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
with open(sys.argv[2], encoding="utf-8") as log:
    calls = log.readlines()
assert len(calls) == 1, len(calls)
assert len(info["storage"]) == 3
assert all(not volume["available"] for volume in info["storage"])
assert info["diskAvailable"] is False
print("PASS: one hung mount bounds scan and leaves remaining mounts visible")
PY
