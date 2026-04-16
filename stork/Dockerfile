FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  debian-keyring \
  debian-archive-keyring \
  apt-transport-https \
  nftables \
  postgresql \
  postgresql-client \
  postgresql-contrib \
  procps \
  wget \
  && rm -rf /var/lib/apt/lists/*

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/stork-dev/gpg.7885B43C1E71563A.key' \
  | gpg --dearmor -o /usr/share/keyrings/isc-stork-dev-archive-keyring.gpg

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/stork-dev/config.deb.txt?distro=debian&codename=bookworm&component=main' \
  > /etc/apt/sources.list.d/isc-stork-dev.list

RUN mkdir -p /etc/apt/keyrings \
  && wget -q -O - https://apt.grafana.com/gpg-full.key \
  | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg \
  && chmod 644 /etc/apt/keyrings/grafana.gpg

RUN printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main' \
  > /etc/apt/sources.list.d/grafana.list

RUN chmod 644 /usr/share/keyrings/isc-stork-dev-archive-keyring.gpg \
  && chmod 644 /etc/apt/sources.list.d/isc-stork-dev.list \
  && chmod 644 /etc/apt/sources.list.d/grafana.list

RUN apt-get update && apt-get install -y \
  isc-stork-server \
  prometheus \
  grafana \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
  /etc/stork \
  /var/lib/stork \
  /var/lib/postgresql \
  /var/log/stork \
  /var/lib/prometheus \
  /var/log/prometheus \
  /var/lib/grafana \
  /var/log/grafana \
  /var/lib/grafana/dashboards \
  /usr/local/share/grafana/dashboards \
  /etc/grafana/provisioning/datasources \
  /etc/grafana/provisioning/dashboards \
  /usr/lib/stork-server/hooks \
  /var/run/postgresql

COPY server.env /etc/stork/server.env
COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY grafana.ini /etc/grafana/grafana.ini
COPY provisioning/datasources/prometheus.yml /etc/grafana/provisioning/datasources/prometheus.yml
COPY provisioning/dashboards/dashboards.yml /etc/grafana/provisioning/dashboards/dashboards.yml
COPY dashboards/kea-stork-overview.json /usr/local/share/grafana/dashboards/kea-stork-overview.json
COPY dashboards/bind-overview.json /usr/local/share/grafana/dashboards/bind-overview.json
COPY --chmod=755 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
