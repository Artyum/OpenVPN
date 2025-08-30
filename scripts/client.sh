#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <add|remove> <client-name>"
    exit 1
fi

ACTION="$1"
CLIENT_NAME="$2"

# Reject unsafe names (e.g. "client", ".", "..", names with spaces or special chars)
if [[ "${CLIENT_NAME}" == "client" ]] || [[ ! "${CLIENT_NAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: invalid client name '${CLIENT_NAME}'"
    exit 2
fi

case "${ACTION}" in
    add)
        echo "Generating certificate for client: ${CLIENT_NAME}"
        ${EASYRSA}/easyrsa --batch gen-req "${CLIENT_NAME}" nopass
        ${EASYRSA}/easyrsa --batch sign-req client "${CLIENT_NAME}"

        cp ${EASYRSA_PKI}/private/${CLIENT_NAME}.key ${CLIENT_CERTS}
        cp ${EASYRSA_PKI}/issued/${CLIENT_NAME}.crt ${CLIENT_CERTS}
        chmod 644 ${CLIENT_CERTS}/*

        echo "Client certificate for ${CLIENT_NAME} generated successfully."
        ;;
    revoke)
        echo "Revoking and removing certificate for client: ${CLIENT_NAME}"
        ${EASYRSA}/easyrsa --batch revoke "${CLIENT_NAME}"
        ${EASYRSA}/easyrsa --batch gen-crl

        rm -f ${CLIENT_CERTS}/${CLIENT_NAME}*

        echo "Client certificate for ${CLIENT_NAME} revoked and removed successfully. Please restart the Docker container to apply CRL changes."

        ;;
    *)
        echo "Error: unknown action '${ACTION}'. Use add or revoke."
        exit 3
        ;;
esac
