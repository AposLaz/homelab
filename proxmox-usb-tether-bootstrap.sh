#!/usr/bin/env bash
set -euo pipefail

# proxmox-usb-tether-bootstrap.sh
#
# Purpose:
#   Use Android/iPhone USB tethering as temporary internet on a fresh Proxmox host.
#   Then install the basic Wi-Fi tools needed to connect Proxmox to Wi-Fi.
#
# Usage:
#   chmod +x proxmox-usb-tether-bootstrap.sh
#   ./proxmox-usb-tether-bootstrap.sh
#
# Before running:
#   1. Connect your phone to the Proxmox mini PC with USB.
#   2. Enable USB tethering/hotspot on your phone.
#   3. Run this script as root on Proxmox.

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: Run this script as root."
  echo "Example: sudo $0"
  exit 1
fi

echo "============================================================"
echo " Proxmox USB Tether Bootstrap"
echo "============================================================"
echo

echo "[1/8] Showing current network interfaces..."
ip -br link || true
echo

echo "[2/8] Looking for possible USB tether interface..."

mapfile -t CANDIDATES < <(
  ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1 \
  | grep -E '^(usb[0-9]+|enx[0-9a-fA-F]+|enp.*u.*)$' \
  || true
)

if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
  echo "No obvious USB tether interface found."
  echo
  echo "Current interfaces:"
  ip -br link || true
  echo
  echo "What to do:"
  echo "  1. Make sure phone is connected with USB."
  echo "  2. Enable USB tethering on the phone."
  echo "  3. Run: ip -br link"
  echo "  4. Look for a new interface like usb0, enx..., or enp...u..."
  echo
  read -rp "Enter the USB tether interface name manually, or press ENTER to exit: " USB_IFACE
  if [[ -z "${USB_IFACE}" ]]; then
    echo "Exiting."
    exit 1
  fi
else
  echo "Found possible USB tether interface(s):"
  printf '  - %s\n' "${CANDIDATES[@]}"
  USB_IFACE="${CANDIDATES[0]}"

  if [[ "${#CANDIDATES[@]}" -gt 1 ]]; then
    echo
    echo "Using first candidate by default: ${USB_IFACE}"
    read -rp "Press ENTER to use ${USB_IFACE}, or type another interface name: " CHOSEN
    if [[ -n "${CHOSEN}" ]]; then
      USB_IFACE="${CHOSEN}"
    fi
  fi
fi

echo
echo "Selected USB tether interface: ${USB_IFACE}"
echo

if ! ip link show "${USB_IFACE}" >/dev/null 2>&1; then
  echo "ERROR: Interface ${USB_IFACE} does not exist."
  exit 1
fi

echo "[3/8] Bringing interface up..."
ip link set "${USB_IFACE}" up
sleep 2
ip -br link show "${USB_IFACE}" || true
echo

echo "[4/8] Requesting IP address with DHCP..."

if command -v dhclient >/dev/null 2>&1; then
  dhclient -r "${USB_IFACE}" >/dev/null 2>&1 || true
  dhclient -v "${USB_IFACE}" || true
elif command -v udhcpc >/dev/null 2>&1; then
  udhcpc -i "${USB_IFACE}" || true
else
  echo "ERROR: No DHCP client found."
  echo "Missing dhclient and udhcpc."
  echo "You may need temporary Ethernet or offline package install."
  exit 1
fi

echo
echo "Current IP addresses:"
ip -br addr show "${USB_IFACE}" || true
echo

USB_IP="$(ip -4 -o addr show "${USB_IFACE}" | awk '{print $4}' | head -n1 || true)"

if [[ -z "${USB_IP}" ]]; then
  echo "ERROR: No IPv4 address received on ${USB_IFACE}."
  echo
  echo "Try:"
  echo "  - Disable and re-enable USB tethering on the phone"
  echo "  - Unplug/replug USB cable"
  echo "  - Run the script again"
  exit 1
fi

echo "Received IP on ${USB_IFACE}: ${USB_IP}"
echo

echo "[5/8] Showing routing table..."
ip route || true
echo

echo "[6/8] Testing internet connectivity..."

echo "Testing ping to 8.8.8.8..."
if ping -c 4 -W 3 8.8.8.8; then
  echo "OK: Internet by IP works."
else
  echo "WARNING: Could not ping 8.8.8.8."
  echo "Temporary internet may not be working."
fi

echo
echo "Testing DNS with google.com..."
if ping -c 4 -W 3 google.com; then
  echo "OK: DNS works."
else
  echo "WARNING: DNS test failed."
  echo "Trying to add temporary DNS servers to /etc/resolv.conf..."

  cp /etc/resolv.conf "/etc/resolv.conf.backup.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true

  cat > /etc/resolv.conf <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

  echo "Retrying DNS..."
  if ping -c 4 -W 3 google.com; then
    echo "OK: DNS works after temporary resolv.conf update."
  else
    echo "WARNING: DNS still does not work."
  fi
fi

echo
echo "[7/8] Updating apt package index..."

if apt update; then
  echo "OK: apt update completed."
else
  echo
  echo "WARNING: apt update failed."
  echo "Fresh Proxmox may have enterprise repository enabled without subscription."
  echo
  read -rp "Disable Proxmox enterprise repo and add no-subscription repo? [y/N]: " FIX_REPOS

  if [[ "${FIX_REPOS,,}" == "y" ]]; then
    echo "Checking Debian codename..."
    CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"

    if [[ -z "${CODENAME}" ]]; then
      echo "ERROR: Could not detect Debian codename from /etc/os-release."
      exit 1
    fi

    echo "Detected codename: ${CODENAME}"

    if [[ -f /etc/apt/sources.list.d/pve-enterprise.list ]]; then
      cp /etc/apt/sources.list.d/pve-enterprise.list "/etc/apt/sources.list.d/pve-enterprise.list.backup.$(date +%Y%m%d-%H%M%S)"
      sed -i 's/^[[:space:]]*deb/# deb/' /etc/apt/sources.list.d/pve-enterprise.list
      echo "Disabled /etc/apt/sources.list.d/pve-enterprise.list"
    fi

    cat > /etc/apt/sources.list.d/pve-no-subscription.list <<EOF
deb http://download.proxmox.com/debian/pve ${CODENAME} pve-no-subscription
EOF

    echo "Added no-subscription repo:"
    cat /etc/apt/sources.list.d/pve-no-subscription.list
    echo

    apt update
  else
    echo "Skipping repo fix."
  fi
fi

echo
echo "[8/8] Installing Wi-Fi tools..."

read -rp "Install Wi-Fi tools now? [Y/n]: " INSTALL_WIFI_TOOLS
INSTALL_WIFI_TOOLS="${INSTALL_WIFI_TOOLS:-Y}"

if [[ "${INSTALL_WIFI_TOOLS,,}" == "y" ]]; then
  apt install -y wpasupplicant iw wireless-tools isc-dhcp-client
else
  echo "Skipping Wi-Fi tool install."
fi

echo
echo "Checking installed tools:"
for cmd in wpa_supplicant iw dhclient; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    echo "OK: ${cmd} -> $(command -v "${cmd}")"
  else
    echo "MISSING: ${cmd}"
  fi
done

echo
echo "============================================================"
echo " Done"
echo "============================================================"
echo
echo "Temporary USB tether interface:"
echo "  ${USB_IFACE} -> ${USB_IP}"
echo
echo "Next steps:"
echo "  1. Configure real Wi-Fi using wpa_supplicant."
echo "  2. Get a Wi-Fi IP with dhclient."
echo "  3. Confirm: ip route"
echo "  4. Confirm: ping -c 4 google.com"
echo "  5. SSH from laptop to Proxmox."
echo "  6. Run Ansible."
echo
