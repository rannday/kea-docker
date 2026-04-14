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
  postgresql \
  postgresql-client \
  procps \
  netcat-openbsd \
  && rm -rf /var/lib/apt/lists/*

RUN printf '%s\n' '[mariadbd]' 'log-bin-trust-function-creators=1' > /etc/mysql/conf.d/kea.cnf

COPY --chmod=755 healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]