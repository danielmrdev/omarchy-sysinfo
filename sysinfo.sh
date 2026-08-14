#!/bin/bash
# Emit CPU/MEM/DISK/TEMP JSON for the daniel.sysinfo bar widget.
# Sources: /proc/stat (aggregate + per-core), /proc/meminfo, df, hwmon (coretemp).

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

# DISK % (root fs), used/total in GiB
read -r disk disk_used disk_total < <(df -P / | awk 'NR==2 {gsub(/%/,"",$5); printf "%d %.1f %.1f", $5, $3/1048576, $2/1048576}')

# TEMP — coretemp package temp
temp=0
for hw in /sys/class/hwmon/hwmon*; do
  if [ "$(cat "$hw/name" 2>/dev/null)" = "coretemp" ]; then
    t=$(cat "$hw/temp1_input" 2>/dev/null || echo 0)
    temp=$((t / 1000))
    break
  fi
done

# FAN — thinkpad hwmon
fan=0
for hw in /sys/class/hwmon/hwmon*; do
  if [ "$(cat "$hw/name" 2>/dev/null)" = "thinkpad" ]; then
    fan=$(cat "$hw/fan1_input" 2>/dev/null || cat "$hw/fan2_input" 2>/dev/null || echo 0)
    break
  fi
done

printf '{"cpu":%d,"cores":[%s],"mem":%d,"disk":%d,"temp":%d,"fan":%d,"ramUsedGb":%s,"ramTotalGb":%s,"diskUsed":%.1f,"diskTotal":%.1f}\n' \
  "$cpu" "$cores" "$mem" "$disk" "$temp" "$fan" "$ram_used_gb" "$ram_total_gb" "$disk_used" "$disk_total"
