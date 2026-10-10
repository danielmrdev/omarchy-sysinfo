#!/bin/bash
# Emit CPU/MEM/storage/thermal JSON for the danielmrdev.sysinfo bar widget.
# Sources: /proc/stat, /proc/meminfo, findmnt/df, and hwmon.

sample() {
  awk '/^cpu( |[0-9]+)/ {
    u=$2; n=$3; s=$4; i=$5
    printf "%s %d %d\n", $1, u+n+s+i, i
  }' /proc/stat
}

a=$(sample)
sleep 0.25
b=$(sample)

# Aggregate CPU % (first line, "cpu ...")
read -r _ t1 i1 _ t2 i2 < <(paste <(printf '%s\n' "$a") <(printf '%s\n' "$b") | head -1)
cpu=0
dt=$((t2 - t1))
di=$((i2 - i1))
((dt > 0)) && cpu=$(((dt - di) * 100 / dt))

# Per-core CPU % ("cpuN ..." lines)
cores=$(paste <(printf '%s\n' "$a") <(printf '%s\n' "$b") | tail -n +2 | awk '{
  dt=$5-$2; di=$6-$3; p=0
  if (dt > 0) p=int((dt-di)*100/dt)
  printf "%s%d", (NR > 1 ? "," : ""), p
}')

# MEM %
total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
avail_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
mem=$(((total_kb - avail_kb) * 100 / total_kb))
ram_used=$(((total_kb - avail_kb) / 1024))
ram_total=$((total_kb / 1024))
ram_used_gb=$(awk -v u="$ram_used" 'BEGIN {printf "%.1f", u/1024}')
ram_total_gb=$(awk -v t="$ram_total" 'BEGIN {printf "%.1f", t/1024}')

# Temperature availability is separate so a readable zero remains a valid reading.
# Intel CPUs expose "coretemp"; AMD CPUs expose "k10temp" (or the out-of-tree
# "zenpower"). Try the known CPU sensors in preference order.
temp=0
temp_available=false
for sensor_name in coretemp k10temp zenpower; do
  for hw in /sys/class/hwmon/hwmon*; do
    [[ -r "$hw/name" ]] || continue
    IFS= read -r name < "$hw/name" || continue
    [[ "$name" == "$sensor_name" && -r "$hw/temp1_input" ]] || continue
    IFS= read -r temp_millidegrees < "$hw/temp1_input" || continue
    if [[ "$temp_millidegrees" =~ ^[0-9]+$ ]]; then
      temp=$((temp_millidegrees / 1000))
      temp_available=true
      break 2
    fi
  done
done

# Fan availability is separate so a readable zero RPM remains a valid reading.
fan=0
fan_available=false
for hw in /sys/class/hwmon/hwmon*; do
  [[ -r "$hw/name" ]] || continue
  IFS= read -r name < "$hw/name" || continue
  [[ "$name" == "thinkpad" ]] || continue
  for fan_input in "$hw/fan1_input" "$hw/fan2_input"; do
    [[ -r "$fan_input" ]] || continue
    IFS= read -r fan_rpm < "$fan_input" || continue
    if [[ "$fan_rpm" =~ ^[0-9]+$ ]]; then
      fan=$fan_rpm
      fan_available=true
      break 2
    fi
  done
done

json_quote() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '"%s"' "$value"
}

storage_json='[]'
disk=0
diskUsed=0.0
diskTotal=0.0
diskAvailable=false
collect_storage() {
  local source target fstype mountpoint mount_label source_key prior_source stats
  local total_bytes used_bytes percent used_gib total_gib available first=1
  local clock_now clock_seconds clock_fraction storage_started_ms storage_now_ms
  local -a seen_sources=()

  clock_now=$EPOCHREALTIME
  clock_seconds=${clock_now%.*}
  clock_fraction=${clock_now#*.}
  storage_started_ms=$((10#$clock_seconds * 1000 + 10#$clock_fraction / 1000))

  storage_json='['
  while IFS=' ' read -r source target fstype; do
    [[ -n "$source" && -n "$target" && -n "$fstype" ]] || continue

    # Ignore kernel/pseudo filesystems and automount stubs. Keep real block
    # devices and mounted network/FUSE filesystems, including rclone.
    case "$fstype" in
      autofs|binfmt_misc|bpf|cgroup|cgroup2|configfs|debugfs|devpts|devtmpfs|efivarfs|fuse.portal|fusectl|hugetlbfs|mqueue|nsfs|overlay|proc|pstore|ramfs|securityfs|sysfs|tmpfs|tracefs)
        continue
        ;;
    esac
    case "$source" in
      /dev/loop*|loop*) continue ;;
    esac
    if [[ "$source" != /dev/* && "$fstype" != fuse.* && "$fstype" != nfs* && "$fstype" != cifs && "$fstype" != smb3 && "$fstype" != 9p && "$fstype" != ceph && "$fstype" != davfs ]]; then
      continue
    fi

    # Btrfs subvolumes use the same backing device. Show that storage once.
    source_key=${source%%\[*}
    for prior_source in "${seen_sources[@]}"; do
      [[ "$prior_source" == "$source_key" ]] && continue 2
    done
    seen_sources+=("$source_key")

    printf -v mountpoint '%b' "$target"
    [[ "$mountpoint" == *$'\n'* || "$mountpoint" == *$'\t'* ]] && continue
    mount_label=$mountpoint

    # One slow remote mount must not stall all later system metrics.
    clock_now=$EPOCHREALTIME
    clock_seconds=${clock_now%.*}
    clock_fraction=${clock_now#*.}
    storage_now_ms=$((10#$clock_seconds * 1000 + 10#$clock_fraction / 1000))
    stats=''
    if (( storage_now_ms - storage_started_ms < 1000 )); then
      stats=$(timeout 1s df -B1 --output=size,used,pcent -- "$mountpoint" 2>/dev/null | awk 'NR == 2 {gsub(/%/, "", $3); print $1, $2, $3}')
    fi
    available=false
    used_gib=null
    total_gib=null
    percent=0
    if [[ "$stats" =~ ^([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
      total_bytes=${BASH_REMATCH[1]}
      used_bytes=${BASH_REMATCH[2]}
      percent=${BASH_REMATCH[3]}
      used_gib=$(awk -v b="$used_bytes" 'BEGIN {printf "%.1f", b/1073741824}')
      total_gib=$(awk -v b="$total_bytes" 'BEGIN {printf "%.1f", b/1073741824}')
      available=true
    fi

    if [[ "$mountpoint" == "/" ]]; then
      diskAvailable=$available
      if [[ "$available" == true ]]; then
        disk=$percent
        diskUsed=$used_gib
        diskTotal=$total_gib
      fi
    fi

    ((first)) || storage_json+=','
    first=0
    printf -v mount_json '%s' "$(json_quote "$mount_label")"
    if [[ "$available" == true ]]; then
      storage_json+="{\"mount\":$mount_json,\"available\":true,\"usedGiB\":$used_gib,\"totalGiB\":$total_gib,\"percent\":$percent}"
    else
      storage_json+="{\"mount\":$mount_json,\"available\":false,\"usedGiB\":null,\"totalGiB\":null,\"percent\":null}"
    fi
  done < <(findmnt -rn -o SOURCE,TARGET,FSTYPE 2>/dev/null)
  storage_json+=']'
}
collect_storage

printf '{"cpu":%d,"cores":[%s],"mem":%d,"disk":%d,"diskAvailable":%s,"temp":%d,"tempAvailable":%s,"fan":%d,"fanAvailable":%s,"ramUsedGb":%s,"ramTotalGb":%s,"diskUsed":%s,"diskTotal":%s,"storage":%s}\n' \
  "$cpu" "$cores" "$mem" "$disk" "$diskAvailable" "$temp" "$temp_available" "$fan" "$fan_available" \
  "$ram_used_gb" "$ram_total_gb" "$diskUsed" "$diskTotal" "$storage_json"
