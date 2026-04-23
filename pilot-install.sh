#!/bin/bash
# JinnLabs fleet device bring-up: installs Tailscale, joins tailnet with unique
# MAC-derived hostname, seeds team SSH keys. Run once per freshly-flashed JP6.2
# Orin Nano card after oem-config completes.
#
# Usage (from a device's terminal, after WiFi is connected):
#
#     TS_AUTHKEY=tskey-auth-xxxxx curl -fsSL \
#         https://raw.githubusercontent.com/JinnLabs-ai/fleet/main/pilot-install.sh \
#         | sudo -E bash
#
# The `-E` on sudo is required so the TS_AUTHKEY env var propagates to root.
# TS_AUTHKEY must be a REUSABLE auth key, tagged tag:nano (or tag:agx/onboarded),
# with 7-day expiry or similar. Generate fresh ones at:
#     https://login.tailscale.com/admin/settings/keys
# and revoke immediately after a batch run.

set -eu

if [ -z "${TS_AUTHKEY:-}" ]; then
    echo "ERROR: TS_AUTHKEY env var not set." >&2
    echo "Usage: TS_AUTHKEY=tskey-auth-... curl ... | sudo -E bash" >&2
    exit 1
fi

TEAM_GITHUB_USERS="${TEAM_GITHUB_USERS:-atif275 JinnHarjeev}"
# Override which GitHub accounts' pubkeys get installed into /home/jinn-sync/.ssh/authorized_keys.
# Default = current fleet team.

echo "=== 0. Wait for apt lock (packagekitd often holds it on first boot) ==="
for i in $(seq 1 30); do
    if ! fuser /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        break
    fi
    echo "apt locked, waiting ($i/30)..."
    systemctl stop packagekit 2>/dev/null || true
    sleep 2
done

echo "=== 1. Derive STABLE hostname from permanent NIC MAC ==="
IFACE=$(ip -4 route show default | awk '/default/ {print $5; exit}')
if [ -z "${IFACE:-}" ]; then
    echo "ERROR: no default route. Connect WiFi/Ethernet before running." >&2
    exit 1
fi
# Prefer permanent hardware MAC — NetworkManager can randomize the runtime MAC.
PERM_MAC=$(ethtool -P "$IFACE" 2>/dev/null | awk '{print $NF}')
if [ -z "${PERM_MAC:-}" ] || [ "$PERM_MAC" = "00:00:00:00:00:00" ]; then
    PERM_MAC=$(cat /sys/class/net/${IFACE}/address 2>/dev/null || echo "")
fi
if [ -z "$PERM_MAC" ]; then
    echo "ERROR: couldn't read MAC for $IFACE" >&2
    exit 1
fi
MAC_CLEAN=$(echo "$PERM_MAC" | tr -d ':' | tr -d '\n')
MAC_SUFFIX="${MAC_CLEAN: -6}"
HOSTN="${HOSTN_OVERRIDE:-jinn-nano-${MAC_SUFFIX}}"
echo "Interface: $IFACE, PermMAC: $PERM_MAC -> hostname: $HOSTN"

echo "=== 2. Set hostname ==="
hostnamectl set-hostname "$HOSTN"

echo "=== 3. Join Tailscale ==="
if ! command -v tailscale >/dev/null 2>&1; then
    echo "Tailscale not installed — installing"
    curl -fsSL https://tailscale.com/install.sh | sh
fi
tailscale up \
    --reset \
    --auth-key="$TS_AUTHKEY" \
    --hostname="$HOSTN" \
    --advertise-tags="${TS_TAGS:-tag:nano}" \
    --accept-routes \
    --ssh

echo "=== 4. Install team SSH keys ==="
mkdir -p /home/jinn-sync/.ssh
: > /home/jinn-sync/.ssh/authorized_keys
for gh_user in $TEAM_GITHUB_USERS; do
    curl -fsSL "https://github.com/${gh_user}.keys" >> /home/jinn-sync/.ssh/authorized_keys
done
chown -R jinn-sync:jinn-sync /home/jinn-sync/.ssh
chmod 700 /home/jinn-sync/.ssh
chmod 600 /home/jinn-sync/.ssh/authorized_keys

echo "=== 5. Disable WiFi MAC randomization (stable hostname across reboots) ==="
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/01-jinnlabs-mac-permanent.conf <<'EOF'
[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.cloned-mac-address=permanent
ethernet.cloned-mac-address=permanent
EOF

echo "=== 6. Status ==="
echo "Hostname: $(hostname)"
echo "authorized_keys lines: $(wc -l < /home/jinn-sync/.ssh/authorized_keys)"
echo "--- tailscale status ---"
tailscale status | head -3
echo "=== DONE ==="
echo "This device is now on Tailscale as: $HOSTN"
echo "Reboot (sudo reboot) to apply permanent-MAC setting."
