FROM golang:latest AS builder

LABEL org.opencontainers.image.source https://github.com/FarewellSagittarius/ip_derper

WORKDIR /app

ADD tailscale /app/tailscale

# build derper
RUN cd /app/tailscale/cmd/derper && \
    CGO_ENABLED=0 go build -buildvcs=false -ldflags "-s -w" -o /app/derper

# build tailscaled
RUN cd /app/tailscale/cmd/tailscaled && \
    CGO_ENABLED=0 go build -buildvcs=false -ldflags "-s -w" -o /app/tailscaled

# build tailscale CLI
RUN cd /app/tailscale/cmd/tailscale && \
    CGO_ENABLED=0 go build -buildvcs=false -ldflags "-s -w" -o /app/tailscale

FROM ubuntu:20.04
WORKDIR /app

# ========= CONFIG =========
ENV DERP_ADDR :443
ENV DERP_HTTP_PORT 80
ENV DERP_HOST=127.0.0.1
ENV DERP_CERTS=/app/certs/
ENV DERP_STUN true
ENV DERP_VERIFY_CLIENTS false
ENV TAILSCALE_AUTHKEY=
# ==========================

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssl curl iptables ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY build_cert.sh /app/
COPY start.sh /app/
COPY --from=builder /app/derper /app/derper
COPY --from=builder /app/tailscaled /app/tailscaled
COPY --from=builder /app/tailscale /app/tailscale

CMD ["bash", "/app/start.sh"]
