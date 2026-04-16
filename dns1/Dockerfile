FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  bind9 \
  bind9-utils \
  curl \
  dnsutils \
  nftables \
  procps \
  prometheus-bind-exporter \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/share/bind/zones /var/cache/bind /var/run/named

COPY --chmod=755 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
