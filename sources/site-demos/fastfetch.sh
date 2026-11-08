#!/bin/bash
# Prints the summary of pve-fastfetch-motd.sh for the site demo: the real
# Fastfetch with the configuration the script writes, run in new network,
# hostname and mount namespaces filled with demo values, so nothing of the
# machine that records it shows up (address, hardware, public IP).
#
# Usage, as root: unshare --net --uts --mount --fork bash fastfetch.sh <fastfetch> <config.jsonc>
set -euo pipefail

FASTFETCH="$1"
CONFIG="$2"
DEMO="$(mktemp -d)"

mount --make-rprivate /
mount -t sysfs sysfs /sys
hostname pve01

ip link set lo up
ip link add eno1 type dummy
ip link add vmbr0 type bridge
ip link set eno1 master vmbr0
ip link set eno1 up
ip link set vmbr0 up
ip addr add 192.168.1.10/24 dev vmbr0
ip route add default via 192.168.1.1 dev vmbr0
# the script counts the ports of the bridge that have a device behind them,
# which a dummy interface has not: its sysfs entry is replaced by one that has
mount -t tmpfs none /sys/class/net/eno1
mkdir /sys/class/net/eno1/brport /sys/class/net/eno1/device

for i in $(seq 0 11); do
    printf 'processor\t: %s\nvendor_id\t: GenuineIntel\nmodel name\t: 12th Gen Intel(R) Core(TM) i5-12500\ncpu MHz\t\t: 3000.000\nphysical id\t: 0\ncore id\t\t: %s\ncpu cores\t: 6\n\n' "$i" "$((i / 2))"
done >"$DEMO/cpuinfo"
cat >"$DEMO/meminfo" <<'EOF'
MemTotal:       65612844 kB
MemFree:        30123456 kB
MemAvailable:   41234567 kB
Buffers:          123456 kB
Cached:          9876543 kB
SwapCached:            0 kB
SwapTotal:       8388604 kB
SwapFree:        8388604 kB
Shmem:            234567 kB
SReclaimable:     456789 kB
EOF
printf 'Filename\tType\tSize\tUsed\tPriority\n/dev/dm-0\tpartition\t8388604\t0\t-2\n' >"$DEMO/swaps"
echo "1209720.42 13916000.00" >"$DEMO/uptime"
echo "nameserver 192.168.1.1" >"$DEMO/resolv.conf"
mkdir "$DEMO/dmi"
echo "Mini PC" >"$DEMO/dmi/product_name"
for f in cpuinfo meminfo swaps uptime; do
    mount --bind "$DEMO/$f" "/proc/$f"
done
mount --bind "$DEMO/resolv.conf" /etc/resolv.conf
mount --bind "$DEMO/dmi" /sys/class/dmi/id
# no sensor, no graphics card, no CPU topology of this machine
for d in /sys/class/hwmon /sys/class/thermal /sys/bus/pci /sys/class/drm /sys/devices/system/cpu \
         /proc/bus/pci /dev/dri /usr/share/vulkan /usr/share/glvnd; do
    [[ -e "$d" ]] && mount -t tmpfs none "$d"
done

# the commands the configuration calls, answering for a node with a ZFS pool and two jails
mkdir "$DEMO/bin"
cat >"$DEMO/bin/pveversion" <<'EOF'
#!/bin/sh
echo "pve-manager/9.2.24/0123456789abcdef (running kernel: 6.17.2-1-pve)"
EOF
cat >"$DEMO/bin/zpool" <<'EOF'
#!/bin/sh
printf 'rpool\tONLINE\n'
EOF
cat >"$DEMO/bin/fail2ban-client" <<'EOF'
#!/bin/sh
case "$*" in
    status) printf 'Status\n|- Number of jail:\t2\n`- Jail list:\tproxmox, sshd\n' ;;
    "status sshd") printf '|- Currently banned:\t1\n|- Total banned:\t7\n' ;;
    *) printf '|- Currently banned:\t0\n|- Total banned:\t0\n' ;;
esac
EOF
cat >"$DEMO/bin/curl" <<'EOF'
#!/bin/sh
echo 203.0.113.42
EOF
chmod 0755 "$DEMO"/bin/*

PATH="$DEMO/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=en_US.UTF-8 "$FASTFETCH" -c "$CONFIG" --pipe false
