#!/bin/bash
set -e

# Initialize PKI
${EASYRSA}/easyrsa init-pki

# Create vars file
cat > vars <<EOF
set_var EASYRSA_REQ_COUNTRY    "${EASYRSA_REQ_COUNTRY}"
set_var EASYRSA_REQ_PROVINCE   "${EASYRSA_REQ_PROVINCE}"
set_var EASYRSA_REQ_CITY       "${EASYRSA_REQ_CITY}"
set_var EASYRSA_REQ_ORG        "${EASYRSA_REQ_ORG}"
set_var EASYRSA_REQ_EMAIL      "${EASYRSA_REQ_EMAIL}"
set_var EASYRSA_REQ_OU         "${EASYRSA_REQ_OU}"
set_var EASYRSA_ALGO           "${EASYRSA_ALGO}"
set_var EASYRSA_DIGEST         "${EASYRSA_DIGEST}"
EOF

export KEYS_DIR=/etc/openvpn/server/keys
export KEY_NAME=vpnserver

# Build CA
echo "Building CA"
${EASYRSA}/easyrsa --batch build-ca nopass

# Generate server certificate
${EASYRSA}/easyrsa --batch gen-req ${KEY_NAME} nopass
${EASYRSA}/easyrsa --batch sign-req server ${KEY_NAME}
${EASYRSA}/easyrsa --batch gen-crl

# Copy server certificates
mkdir -p ${KEYS_DIR}

cp pki/private/${KEY_NAME}.key ${KEYS_DIR}
cp pki/issued/${KEY_NAME}.crt ${KEYS_DIR}
cp pki/ca.crt ${KEYS_DIR}

# Generate ta.key
cd ${KEYS_DIR}
openvpn --genkey secret ta.key
chmod 400 ${KEYS_DIR}/*

# Copy ca.crt and ta.key to client folder for easy sharing
cp ${KEYS_DIR}/ca.crt ${CLIENT_CERTS}
cp ${KEYS_DIR}/ta.key ${CLIENT_CERTS}
chmod 644 ${CLIENT_CERTS}/*

echo "PKI initialized successfully!"
