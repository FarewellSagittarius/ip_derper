#!/bin/bash
set -e

# Generate self-signed certs
bash /app/build_cert.sh "$DERP_HOST" "$DERP_CERTS" /app/san.conf

# Start tailscaled if verify-clients is enabled
if [ "$DERP_VERIFY_CLIENTS" = "true" ] && [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "Starting tailscaled for client verification..."
    /app/tailscaled --state=/app/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock --tun=userspace-networking &
    sleep 2

    /app/tailscale-cli --socket=/var/run/tailscale/tailscaled.sock up --authkey="$TAILSCALE_AUTHKEY" --hostname=derper
    echo "Tailscale connected, client verification enabled."
fi

exec /app/derper \
    --hostname="$DERP_HOST" \
    --certmode=manual \
    --certdir="$DERP_CERTS" \
    --stun="$DERP_STUN" \
    --a="$DERP_ADDR" \
    --http-port="$DERP_HTTP_PORT" \
    --verify-clients="$DERP_VERIFY_CLIENTS"
