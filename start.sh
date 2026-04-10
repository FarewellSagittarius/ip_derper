#!/bin/bash
set -e

TAILSCALED_PID=""

cleanup() {
    if [ -n "$TAILSCALED_PID" ]; then
        kill "$TAILSCALED_PID" 2>/dev/null || true
        wait "$TAILSCALED_PID" 2>/dev/null || true
    fi
    if [ -n "$DERPER_PID" ]; then
        kill "$DERPER_PID" 2>/dev/null || true
        wait "$DERPER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT TERM INT

# Generate self-signed certs
bash /app/build_cert.sh "$DERP_HOST" "$DERP_CERTS" /app/san.conf

# Start tailscaled if verify-clients is enabled and no host socket is mounted
if [ "$DERP_VERIFY_CLIENTS" = "true" ] && [ ! -S /var/run/tailscale/tailscaled.sock ]; then
    echo "Starting tailscaled for client verification..."
    /app/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock --tun=userspace-networking &
    TAILSCALED_PID=$!
    sleep 2

    if /app/tailscale-cli --socket=/var/run/tailscale/tailscaled.sock status >/dev/null 2>&1; then
        echo "Tailscale already registered, reconnecting..."
        /app/tailscale-cli --socket=/var/run/tailscale/tailscaled.sock up --hostname=derper
    elif [ -n "$TAILSCALE_AUTHKEY" ]; then
        echo "Registering with auth key..."
        /app/tailscale-cli --socket=/var/run/tailscale/tailscaled.sock up --authkey="$TAILSCALE_AUTHKEY" --hostname=derper
    else
        echo "WARNING: No auth key and not previously registered. Client verification may not work."
    fi
    echo "Tailscale connected, client verification enabled."
elif [ "$DERP_VERIFY_CLIENTS" = "true" ]; then
    echo "Using host tailscaled socket for client verification."
fi

/app/derper \
    --hostname="$DERP_HOST" \
    --certmode=manual \
    --certdir="$DERP_CERTS" \
    --stun="$DERP_STUN" \
    --a="$DERP_ADDR" \
    --http-port="$DERP_HTTP_PORT" \
    --verify-clients="$DERP_VERIFY_CLIENTS" &
DERPER_PID=$!

wait "$DERPER_PID"
