FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  debian-keyring \
  debian-archive-keyring \
  apt-transport-https \
  postgresql \
  postgresql-client \
  procps \
  && rm -rf /var/lib/apt/lists/*

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-dev/gpg.98CB594EC0EC6D3A.key' \
  | gpg --dearmor -o /usr/share/keyrings/isc-kea-dev-archive-keyring.gpg

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-dev/config.deb.txt?distro=debian&codename=bookworm&component=main' \
  > /etc/apt/sources.list.d/isc-kea-dev.list

RUN chmod 644 /usr/share/keyrings/isc-kea-dev-archive-keyring.gpg \
  && chmod 644 /etc/apt/sources.list.d/isc-kea-dev.list

RUN apt-get update && apt-get install -y \
  isc-kea-admin \
  isc-kea-dhcp4 \
  isc-kea-dhcp6 \
  isc-kea-hooks \
  isc-kea-pgsql \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/kea /var/lib/kea /var/log/kea /usr/local/share/kea /var/run/postgresql
RUN printf 'kea\n' > /etc/kea/api-user \
  && printf 'keapass\n' > /etc/kea/api-password \
  && chmod 600 /etc/kea/api-user /etc/kea/api-password

COPY postgresql.conf /usr/local/share/kea/postgresql.conf
COPY pg_hba.conf /usr/local/share/kea/pg_hba.conf
COPY --chmod=755 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
