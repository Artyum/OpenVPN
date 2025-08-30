# Use the latest Ubuntu LTS image
FROM ubuntu:24.04

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV EASYRSA=/usr/share/easy-rsa
ENV EASYRSA_PKI=/etc/openvpn/pki
ENV EASYRSA_BATCH=1
ENV CLIENT_CERTS=/etc/openvpn/client

# Install packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common \
        openvpn \
        easy-rsa \
        iptables \
        openssl \
        iproute2 \
        ca-certificates \
        && rm -rf /var/lib/apt/lists/*

# Volumes
VOLUME ["/etc/openvpn","/var/log/openvpn"]

COPY scripts /usr/share/scripts/
RUN chmod +x /usr/share/scripts/*.sh

# Ports
EXPOSE 1194/udp 5555/tcp

# Startup
WORKDIR /etc/openvpn
ENTRYPOINT ["/usr/share/scripts/entrypoint.sh"]
