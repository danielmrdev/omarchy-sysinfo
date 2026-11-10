#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/empty-hwmon"

cat > "$tmp_dir/bin/findmnt" <<'STUB'
#!/usr/bin/env bash
if [[ "${BLOCK_FINDMNT:-0}" == 1 ]]; then
  (trap '' TERM; while :; do /usr/bin/sleep 0.1; done) &
  child=$!
  printf '%s\n' "$child" > "$BLOCKED_CHILD_PID"
  wait "$child"
fi
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
if [[ "${IGNORE_TERM_FIRST_DF:-0}" == 1 ]] && [[ $(wc -l < "$DF_CALL_LOG") -eq 1 ]]; then
  trap '' TERM
  while :; do /usr/bin/sleep 0.1; done
fi
printf 'Size Used Use%%\n10737418240 5368709120 50%%\n'
STUB
chmod +x "$tmp_dir/bin/findmnt" "$tmp_dir/bin/df"

run_collector() {
  local fixture=$1
  local slow=${2:-0}
  local hwmon_root=${3:-"$tmp_dir/empty-hwmon"}
  local ignore_term=${4:-0}
  local guard=${5:-0}
  local -a collector_command=(
    env
    "PATH=$tmp_dir/bin:$PATH"
    "FINDMNT_FIXTURE=$fixture"
    "DF_CALL_LOG=$tmp_dir/df.log"
    "SLOW_FIRST_DF=$slow"
    "IGNORE_TERM_FIRST_DF=$ignore_term"
    "HWMON_ROOT=$hwmon_root"
    bash "$repo_dir/sysinfo.sh"
  )
  : > "$tmp_dir/df.log"
  if [[ "$guard" == 1 ]]; then
    timeout --kill-after=1s 4s "${collector_command[@]}"
  else
    "${collector_command[@]}"
  fi
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
assert info["temperatureSensors"] == []
assert info["temperatureSensorsTruncated"] is False
assert isinstance(info["fanAvailable"], bool)
mounts = [volume["mount"] for volume in info["storage"]]
assert mounts == ["/", "/mnt/data", "/mnt/net", "/mnt/space disk", "/mnt/cloud"], mounts
assert all(volume["available"] for volume in info["storage"])
assert info["diskAvailable"] is True
print("PASS: mount filtering, deduplication, escaped paths, JSON metrics")
PY

mkdir -p "$tmp_dir/hwmon-main"/{hwmon0,hwmon1,hwmon2,hwmon3,hwmon4,hwmon5,hwmon6,hwmon7}
printf 'coretemp\n' > "$tmp_dir/hwmon-main/hwmon0/name"
printf 'invalid\n' > "$tmp_dir/hwmon-main/hwmon0/temp1_input"
printf '90000\n' > "$tmp_dir/hwmon-main/hwmon0/temp2_input"
printf 'coretemp\n' > "$tmp_dir/hwmon-main/hwmon1/name"
printf '00092555\n' > "$tmp_dir/hwmon-main/hwmon1/temp1_input"
printf 'Package \"id\" \\\\ die\n' > "$tmp_dir/hwmon-main/hwmon1/temp1_label"
printf '87000\n' > "$tmp_dir/hwmon-main/hwmon1/temp2_input"
printf 'coretemp\n' > "$tmp_dir/hwmon-main/hwmon2/name"
printf '99000\n' > "$tmp_dir/hwmon-main/hwmon2/temp1_input"
printf 'Later package\n' > "$tmp_dir/hwmon-main/hwmon2/temp1_label"
printf 'thinkpad\n' > "$tmp_dir/hwmon-main/hwmon3/name"
printf '000000\n' > "$tmp_dir/hwmon-main/hwmon3/temp1_input"
printf 'CPU Zero\n' > "$tmp_dir/hwmon-main/hwmon3/temp1_label"
printf '000000\n' > "$tmp_dir/hwmon-main/hwmon3/temp2_input"
printf '%s\n' '-00012345' > "$tmp_dir/hwmon-main/hwmon3/temp3_input"
printf '+00045678\n' > "$tmp_dir/hwmon-main/hwmon3/temp4_input"
printf 'nvme\n' > "$tmp_dir/hwmon-main/hwmon4/name"
printf '00033000\n' > "$tmp_dir/hwmon-main/hwmon4/temp1_input"
printf 'wifi\n' > "$tmp_dir/hwmon-main/hwmon5/name"
printf '00042500\n' > "$tmp_dir/hwmon-main/hwmon5/temp1_input"
printf 'Wi-Fi PHY\n' > "$tmp_dir/hwmon-main/hwmon5/temp1_label"
printf 'k10temp\n' > "$tmp_dir/hwmon-main/hwmon6/name"
printf '00051000\n' > "$tmp_dir/hwmon-main/hwmon6/temp1_input"
printf 'Tctl\n' > "$tmp_dir/hwmon-main/hwmon6/temp1_label"
printf 'zenpower\n' > "$tmp_dir/hwmon-main/hwmon7/name"
printf '00052000\n' > "$tmp_dir/hwmon-main/hwmon7/temp1_input"
printf 'Tctl\n' > "$tmp_dir/hwmon-main/hwmon7/temp1_label"

thermal_json=$(run_collector "$tmp_dir/normal.mounts" 0 "$tmp_dir/hwmon-main")
thermal_json_repeat=$(run_collector "$tmp_dir/normal.mounts" 0 "$tmp_dir/hwmon-main")
python3 - "$thermal_json" "$thermal_json_repeat" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
repeated_info = json.loads(sys.argv[2])
expected = [
    {"device": "coretemp", "channel": 1, "label": r'Package "id" \\ die', "milliC": 92555, "tooltipSource": True},
    {"device": "thinkpad", "channel": 1, "label": "CPU Zero", "milliC": 0, "tooltipSource": False},
    {"device": "thinkpad", "channel": 3, "label": "temp3", "milliC": -12345, "tooltipSource": False},
    {"device": "thinkpad", "channel": 4, "label": "temp4", "milliC": 45678, "tooltipSource": False},
    {"device": "nvme", "channel": 1, "label": "temp1", "milliC": 33000, "tooltipSource": False},
    {"device": "wifi", "channel": 1, "label": "Wi-Fi PHY", "milliC": 42500, "tooltipSource": False},
    {"device": "k10temp", "channel": 1, "label": "Tctl", "milliC": 51000, "tooltipSource": False},
    {"device": "zenpower", "channel": 1, "label": "Tctl", "milliC": 52000, "tooltipSource": False},
]
assert info["temperatureSensors"] == expected, info["temperatureSensors"]
assert repeated_info["temperatureSensors"] == expected, repeated_info["temperatureSensors"]
assert info["temperatureSensorsTruncated"] is False
print("PASS: primary selection, filtering, signed values, escaping, and deterministic order")
PY

mkdir -p "$tmp_dir/hwmon-amd"/{hwmon0,hwmon1}
printf 'k10temp\n' > "$tmp_dir/hwmon-amd/hwmon0/name"
printf '00051000\n' > "$tmp_dir/hwmon-amd/hwmon0/temp1_input"
printf 'Tctl\n' > "$tmp_dir/hwmon-amd/hwmon0/temp1_label"
printf '00048000\n' > "$tmp_dir/hwmon-amd/hwmon0/temp2_input"
printf 'Tdie\n' > "$tmp_dir/hwmon-amd/hwmon0/temp2_label"
printf 'zenpower\n' > "$tmp_dir/hwmon-amd/hwmon1/name"
printf '00052000\n' > "$tmp_dir/hwmon-amd/hwmon1/temp1_input"
printf 'Tctl\n' > "$tmp_dir/hwmon-amd/hwmon1/temp1_label"
amd_json=$(run_collector "$tmp_dir/normal.mounts" 0 "$tmp_dir/hwmon-amd")
python3 - "$amd_json" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
assert info["temperatureSensors"] == [
    {"device": "k10temp", "channel": 1, "label": "Tctl", "milliC": 51000, "tooltipSource": True},
    {"device": "k10temp", "channel": 2, "label": "Tdie", "milliC": 48000, "tooltipSource": False},
    {"device": "zenpower", "channel": 1, "label": "Tctl", "milliC": 52000, "tooltipSource": False},
], info["temperatureSensors"]
print("PASS: AMD CPU sensor priority and additional channels")
PY

mkdir -p "$tmp_dir/hwmon-zenpower/hwmon0"
printf 'zenpower\n' > "$tmp_dir/hwmon-zenpower/hwmon0/name"
printf '00049000\n' > "$tmp_dir/hwmon-zenpower/hwmon0/temp1_input"
printf 'Tctl\n' > "$tmp_dir/hwmon-zenpower/hwmon0/temp1_label"
zenpower_json=$(run_collector "$tmp_dir/normal.mounts" 0 "$tmp_dir/hwmon-zenpower")
python3 - "$zenpower_json" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
assert info["temperatureSensors"] == [
    {"device": "zenpower", "channel": 1, "label": "Tctl", "milliC": 49000, "tooltipSource": True}
], info["temperatureSensors"]
print("PASS: zenpower fallback as primary CPU sensor")
PY

mkdir -p "$tmp_dir/hwmon-zero-primary/hwmon0"
printf 'coretemp\n' > "$tmp_dir/hwmon-zero-primary/hwmon0/name"
printf '0\n' > "$tmp_dir/hwmon-zero-primary/hwmon0/temp1_input"
zero_primary_json=$(run_collector "$tmp_dir/normal.mounts" 0 "$tmp_dir/hwmon-zero-primary")
python3 - "$zero_primary_json" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
assert info["temperatureSensors"] == [
    {"device": "coretemp", "channel": 1, "label": "temp1", "milliC": 0, "tooltipSource": True}
]
print("PASS: readable zero primary remains available")
PY

mkdir -p "$tmp_dir/hwmon-no-primary/hwmon0"
printf 'nvme\n' > "$tmp_dir/hwmon-no-primary/hwmon0/name"
printf '00055000\n' > "$tmp_dir/hwmon-no-primary/hwmon0/temp1_input"
printf 'Composite\n' > "$tmp_dir/hwmon-no-primary/hwmon0/temp1_label"
no_primary_json=$(run_collector "$tmp_dir/normal.mounts" 0 "$tmp_dir/hwmon-no-primary")
python3 - "$no_primary_json" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
assert info["temperatureSensors"] == [
    {"device": "nvme", "channel": 1, "label": "Composite", "milliC": 55000, "tooltipSource": False}
]
print("PASS: non-core sensors remain available without coretemp")
PY

empty_thermal_json=$(run_collector "$tmp_dir/normal.mounts" 0 "$tmp_dir/empty-hwmon")
python3 - "$empty_thermal_json" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
assert info["temperatureSensors"] == []
assert info["temperatureSensorsTruncated"] is False
print("PASS: empty hwmon root")
PY

mkdir -p "$tmp_dir/hwmon-capped"
for i in $(seq 0 15); do
  printf -v index '%02d' "$i"
  dir="$tmp_dir/hwmon-capped/hwmon$index"
  mkdir -p "$dir"
  printf 'sensor%s\n' "$index" > "$dir/name"
  printf '%s000\n' "$i" > "$dir/temp1_input"
  printf 'Sensor %s\n' "$index" > "$dir/temp1_label"
done
mkdir -p "$tmp_dir/hwmon-capped/hwmon99"
printf 'coretemp\n' > "$tmp_dir/hwmon-capped/hwmon99/name"
printf '00055000\n' > "$tmp_dir/hwmon-capped/hwmon99/temp1_input"
printf 'Package\n' > "$tmp_dir/hwmon-capped/hwmon99/temp1_label"
capped_json=$(run_collector "$tmp_dir/normal.mounts" 0 "$tmp_dir/hwmon-capped")
python3 - "$capped_json" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
expected = [
    {"device": "coretemp", "channel": 1, "label": "Package", "milliC": 55000, "tooltipSource": True},
    {"device": "sensor00", "channel": 1, "label": "Sensor 00", "milliC": 0, "tooltipSource": False},
    {"device": "sensor01", "channel": 1, "label": "Sensor 01", "milliC": 1000, "tooltipSource": False},
    {"device": "sensor02", "channel": 1, "label": "Sensor 02", "milliC": 2000, "tooltipSource": False},
    {"device": "sensor03", "channel": 1, "label": "Sensor 03", "milliC": 3000, "tooltipSource": False},
    {"device": "sensor04", "channel": 1, "label": "Sensor 04", "milliC": 4000, "tooltipSource": False},
    {"device": "sensor05", "channel": 1, "label": "Sensor 05", "milliC": 5000, "tooltipSource": False},
    {"device": "sensor06", "channel": 1, "label": "Sensor 06", "milliC": 6000, "tooltipSource": False},
    {"device": "sensor07", "channel": 1, "label": "Sensor 07", "milliC": 7000, "tooltipSource": False},
    {"device": "sensor08", "channel": 1, "label": "Sensor 08", "milliC": 8000, "tooltipSource": False},
    {"device": "sensor09", "channel": 1, "label": "Sensor 09", "milliC": 9000, "tooltipSource": False},
    {"device": "sensor10", "channel": 1, "label": "Sensor 10", "milliC": 10000, "tooltipSource": False},
    {"device": "sensor11", "channel": 1, "label": "Sensor 11", "milliC": 11000, "tooltipSource": False},
    {"device": "sensor12", "channel": 1, "label": "Sensor 12", "milliC": 12000, "tooltipSource": False},
    {"device": "sensor13", "channel": 1, "label": "Sensor 13", "milliC": 13000, "tooltipSource": False},
    {"device": "sensor14", "channel": 1, "label": "Sensor 14", "milliC": 14000, "tooltipSource": False},
]
assert info["temperatureSensors"] == expected, info["temperatureSensors"]
assert info["temperatureSensorsTruncated"] is True
print("PASS: 16-record cap keeps primary and reports truncation")
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

cat > "$tmp_dir/term-ignoring.mounts" <<'FIXTURE'
/dev/root / ext4
server:/term-ignoring /mnt/term-ignoring nfs4
/dev/data /mnt/data ext4
FIXTURE
if term_ignoring_json=$(run_collector "$tmp_dir/term-ignoring.mounts" 0 "$tmp_dir/empty-hwmon" 1 1); then
  python3 - "$term_ignoring_json" "$tmp_dir/df.log" <<'PY'
import json
import sys

info = json.loads(sys.argv[1])
with open(sys.argv[2], encoding="utf-8") as log:
    calls = log.readlines()
assert len(calls) == 1, len(calls)
assert len(info["storage"]) == 3
assert all(not volume["available"] for volume in info["storage"])
assert info["diskAvailable"] is False
print("PASS: SIGTERM-resistant mount is killed and scan completes")
PY
else
  printf '%s\n' 'FAIL: SIGTERM-resistant mount stalled collector' >&2
  exit 1
fi

cat > "$tmp_dir/blocked.mounts" <<'FIXTURE'
/dev/root / ext4
FIXTURE
: > "$tmp_dir/blocked-child.pid"
python3 - "$repo_dir" "$tmp_dir" <<'PY'
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

repo_dir, tmp_dir = sys.argv[1:]
tmp = Path(tmp_dir)
env = os.environ.copy()
env.update({
    "PATH": f"{tmp / 'bin'}:{env['PATH']}",
    "FINDMNT_FIXTURE": str(tmp / "blocked.mounts"),
    "DF_CALL_LOG": str(tmp / "df.log"),
    "SLOW_FIRST_DF": "0",
    "IGNORE_TERM_FIRST_DF": "0",
    "HWMON_ROOT": str(tmp / "empty-hwmon"),
    "BLOCK_FINDMNT": "1",
    "BLOCKED_CHILD_PID": str(tmp / "blocked-child.pid"),
})
started = time.monotonic()
with (tmp / "blocked.json").open("wb") as stdout, (tmp / "blocked.stderr").open("wb") as stderr:
    process = subprocess.Popen(
        ["bash", str(Path(repo_dir) / "run-collector.sh"), str(Path(repo_dir) / "sysinfo.sh")],
        cwd=repo_dir,
        env=env,
        stdout=stdout,
        stderr=stderr,
        start_new_session=True,
    )
    try:
        runner_status = process.wait(timeout=9)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        raise AssertionError("whole-collector runner exceeded outer test guard")
elapsed = time.monotonic() - started
assert runner_status != 0, "blocked collector returned success"
assert 5 <= elapsed < 9, f"whole collector deadline took {elapsed:.2f}s (status {runner_status})"
assert (tmp / "blocked.json").stat().st_size == 0, "blocked collector emitted partial JSON"
child_pid = int((tmp / "blocked-child.pid").read_text())
for _ in range(20):
    try:
        stat = Path(f"/proc/{child_pid}/stat").read_text()
        child_state = stat.rpartition(")")[2].strip().split()[0]
    except FileNotFoundError:
        child_state = ""
    if not child_state or child_state == "Z":
        break
    time.sleep(0.1)
assert not child_state or child_state == "Z", f"collector descendant {child_pid} survived (state {child_state})"
print("PASS: whole-collector deadline bounds invocation and kills blocked descendants")
PY
