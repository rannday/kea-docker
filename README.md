# Kea Docker
Primary and secondary [ISC Kea](https://www.isc.org/kea/) DHCP servers in a load balancing high availability pair.  

Each servers stores leases in their own local [PostgreSQL](https://www.postgresql.org/) database, which Kea syncs via HA logic, and each server uses an external PostgreSQL database for host table entries as well as forensic logging.  

The primary Kea server’s lease database and the external hosts/logs database are each replicated to a fourth PostgreSQL instance, which runs two separate clusters acting as streaming standbys—one for the lease data and one for the shared hosts/logs data.

## Bring containers up
```bash
docker compose up -d --build
```
## Tear them down
```bash
docker compose down
```
## Wipe them
```bash
docker compose down --volumes --remove-orphans
```
## Clear cache
```bash
docker builder prune -a -f
```
# API
[API Reference](https://kea.readthedocs.io/en/stable/api.html)
- Primary Kea Server
  - DHCP4: Port 8100
  - DHCP6: Port 8101
- Secondary Kea Server
  - DHCP4: Port 8200
  - DHCP6: Port 8201
Replace port number to query the other servers
## Status
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"status-get"}' http://127.0.0.1:8100/
```
## Heartbeat
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"ha-heartbeat"}' http://127.0.0.1:8100/
```
# PostgreSQL
- https://kea.readthedocs.io/en/stable/arm/admin.html#pgsql-database-create
# Logging
- https://kea.readthedocs.io/en/stable/arm/logging.html
# Hooks
[Available Libraries](https://kea.readthedocs.io/en/stable/arm/hooks.html#available-hook-libraries)
## Included
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-bootp
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-class-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-legal-log
  - https://kea.readthedocs.io/en/stable/arm/hooks.html#forensic-log-configuration
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-high-availability
  - https://kea.readthedocs.io/en/stable/arm/hooks.html#load-balancing-configuration
  - If multithreading is enabled, use different internal ports for HA
  - If multithreading is disabled, use the control socket port
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-host-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-lease-cmds
  - https://kea.readthedocs.io/en/stable/arm/hooks.html#binding-variables
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-lease-query
  - https://kea.readthedocs.io/en/stable/arm/hooks.html#dhcpv4-leasequery-configuration
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-limits
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-perfmon
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-pgsql
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-stat-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-subnet-cmds
