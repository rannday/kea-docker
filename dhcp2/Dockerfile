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
  && rm -rf /var/lib/apt/lists/*

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-dev/gpg.98CB594EC0EC6D3A.key' \
  | gpg --dearmor -o /usr/share/keyrings/isc-kea-dev-archive-keyring.gpg

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-dev/config.deb.txt?distro=debian&codename=bookworm&component=main' \
  > /etc/apt/sources.list.d/isc-kea-dev.list

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/stork-dev/gpg.7885B43C1E71563A.key' \
  | gpg --dearmor -o /usr/share/keyrings/isc-stork-dev-archive-keyring.gpg

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/stork-dev/config.deb.txt?distro=debian&codename=bookworm&component=main' \
  > /etc/apt/sources.list.d/isc-stork-dev.list

RUN chmod 644 /usr/share/keyrings/isc-kea-dev-archive-keyring.gpg \
  && chmod 644 /etc/apt/sources.list.d/isc-kea-dev.list \
  && chmod 644 /usr/share/keyrings/isc-stork-dev-archive-keyring.gpg \
  && chmod 644 /etc/apt/sources.list.d/isc-stork-dev.list

RUN apt-get update && apt-get install -y \
  isc-kea-admin \
  isc-kea-dhcp4 \
  isc-kea-dhcp6 \
  isc-kea-dhcp-ddns \
  isc-kea-hooks \
  isc-kea-pgsql \
  isc-stork-agent \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/kea /etc/stork /var/lib/kea /var/lib/stork-agent /var/log/kea /usr/lib/stork-agent/hooks /usr/local/share/kea /var/run/postgresql \
  && rm -rf /var/lib/stork \
  && ln -s /var/lib/stork-agent /var/lib/stork
RUN printf 'kea\n' > /etc/kea/api-user \
  && printf 'keapass\n' > /etc/kea/api-password \
  && printf 'J7eVnYH4rY8gYz4j5A9LxK2pQm7nS3tVw2yB6cD9fG0=\n' > /etc/kea/kea-ddns.key \
  && chmod 600 /etc/kea/api-user /etc/kea/api-password
RUN chmod 600 /etc/kea/kea-ddns.key

COPY postgresql.conf /usr/local/share/kea/postgresql.conf
COPY --chmod=755 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
