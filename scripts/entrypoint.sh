#!/bin/bash
set -e

echo "OpenVPN Container Initialization"

# === Public Key Infrastructure (PKI) Initialization ===
# Check whether PKI has already been generated
if [ ! -f /etc/openvpn/server/keys/ca.crt ]; then
    echo "Initializing new PKI"
    /usr/share/scripts/init-pki.sh
else
    echo "PKI already initialized, skipping."
fi

# === Detect interfaces for default gateway ===
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Using default (outbound) interface: $DEFAULT_IFACE"
echo "Using VPN interface: $VPN_IFACE"

# === Firewall & Routing Rules ===

# If ufw or other routing manager is being used, allow incoming traffic on UDP port (default 1194):
#
# sudo ufw allow 1194/udp
#
# If ufw is not in use, uncomment:
# if ! iptables -C INPUT -p udp --dport "$VPN_PORT" -j ACCEPT 2>/dev/null; then
#     iptables -A INPUT -p udp --dport "$VPN_PORT" -j ACCEPT
#     echo "Allowed inbound UDP port $VPN_PORT (OpenVPN)"
# fi

# NAT: Allow VPN clients to reach the internet through server external interface
if ! iptables -t nat -C POSTROUTING -s "$VPN_SUBNET" -o "$DEFAULT_IFACE" -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -s "$VPN_SUBNET" -o "$DEFAULT_IFACE" -j MASQUERADE
    echo "Added NAT rule for VPN -> Internet access"
fi

# Forward VPN -> Internet
if ! iptables -C FORWARD -i "$VPN_IFACE" -o "$DEFAULT_IFACE" -s "$VPN_SUBNET" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$VPN_IFACE" -o "$DEFAULT_IFACE" -s "$VPN_SUBNET" -j ACCEPT
    echo "Added FORWARD rule VPN -> Internet"
fi

# Forward Internet -> VPN (only established connections)
if ! iptables -C FORWARD -i "$DEFAULT_IFACE" -o "$VPN_IFACE" -d "$VPN_SUBNET" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$DEFAULT_IFACE" -o "$VPN_IFACE" -d "$VPN_SUBNET" -m state --state RELATED,ESTABLISHED -j ACCEPT
    echo "Added FORWARD rule Internet -> VPN (responses)"
fi

# Forward VPN -> LAN
if ! iptables -C FORWARD -i "$VPN_IFACE" -o "$DEFAULT_IFACE" -s "$VPN_SUBNET" -d "$LAN_SUBNET" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$VPN_IFACE" -o "$DEFAULT_IFACE" -s "$VPN_SUBNET" -d "$LAN_SUBNET" -j ACCEPT
    echo "Added FORWARD rule VPN -> LAN"
fi

# Forward LAN -> VPN
if ! iptables -C FORWARD -i "$DEFAULT_IFACE" -o "$VPN_IFACE" -s "$LAN_SUBNET" -d "$VPN_SUBNET" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$DEFAULT_IFACE" -o "$VPN_IFACE" -s "$LAN_SUBNET" -d "$VPN_SUBNET" -j ACCEPT
    echo "Added FORWARD rule LAN -> VPN"
fi

# === Permissions ===
chmod 644 /var/log/openvpn/*

# === Start OpenVPN ===
echo "Starting OpenVPN"
openvpn --config /etc/openvpn/server/server.conf
