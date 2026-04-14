FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  debian-keyring \
  debian-archive-keyring \
  apt-transport-https \
  mariadb-server \
  mariadb-client \
  && rm -rf /var/lib/apt/lists/*

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-3-0/gpg.B16C44CD45514C3C.key' \
  | gpg --dearmor -o /usr/share/keyrings/isc-kea-3-0-archive-keyring.gpg

RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-3-0/config.deb.txt?distro=debian&codename=bookworm&component=main' \
  > /etc/apt/sources.list.d/isc-kea-3-0.list

RUN chmod 644 /usr/share/keyrings/isc-kea-3-0-archive-keyring.gpg \
  && chmod 644 /etc/apt/sources.list.d/isc-kea-3-0.list

RUN apt-get update && apt-get install -y \
  isc-kea-admin \
  isc-kea-mysql \
  && rm -rf /var/lib/apt/lists/*

COPY kea.cnf /etc/mysql/conf.d/kea.cnf
COPY --chmod=755 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
