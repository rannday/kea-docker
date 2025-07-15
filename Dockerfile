FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install system deps
RUN apt-get update && apt-get install -y \
  curl wget ca-certificates gnupg gnupg2 lsb-release apt-transport-https \
  systemd iproute2 net-tools procps \
  && rm -rf /var/lib/apt/lists/*

# Add MySQL repo
RUN wget https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb && \
  DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.29-1_all.deb && \
  apt-get update

# Install MySQL
RUN apt-get install -y mysql-server

# Add ISC Kea Cloudsmith repo and install Kea
RUN curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea-2-6/setup.deb.sh' | bash && \
  apt-get update && \
  apt-get install -y isc-kea

# Optional: Expose the Control Agent port
EXPOSE 8000

# Copy Kea config
COPY config /etc/kea/

# Create Kea log directory
RUN mkdir -p /var/log/kea && chown -R _kea:_kea /var/log/kea

# Wipe and initialize MySQL and import Kea schema manually
RUN bash -c '\
  rm -rf /var/lib/mysql/* && \
  mkdir -p /var/run/mysqld && \
  chown -R mysql:mysql /var/lib/mysql /var/run/mysqld && \
  mysqld --initialize-insecure --user=mysql && \
  mysqld_safe \
    --skip-networking \
    --socket=/var/run/mysqld/mysqld.sock \
    --log-bin-trust-function-creators=1 \
    --innodb-flush-log-at-trx-commit=2 \
    --default-time-zone='+00:00' & \
  pid=$! && \
  echo "Waiting for MySQL to be ready..." && \
  for i in $(seq 1 30); do \
    mysqladmin ping --silent && break; \
    sleep 1; \
  done && \
  echo "Creating Kea DB and user..." && \
  mysql -e "CREATE DATABASE IF NOT EXISTS kea; CREATE USER IF NOT EXISTS '\''kea'\''@'\''localhost'\'' IDENTIFIED BY '\''kea'\''; GRANT ALL PRIVILEGES ON kea.* TO '\''kea'\''@'\''localhost'\''; FLUSH PRIVILEGES;" && \
  echo "Loading Kea schema manually..." && \
  mysql -ukea -pkea kea < /usr/share/kea/scripts/mysql/dhcpdb_create.mysql && \
  kill $pid && wait $pid || true \
'

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Healthcheck
HEALTHCHECK CMD curl --fail http://localhost:8000/ | grep 'Control-agent' || exit 1

# Set entrypoint
CMD ["/entrypoint.sh"]
