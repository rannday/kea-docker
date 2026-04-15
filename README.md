# Kea Docker
Goal - Two ISC Kea instances in a load balancing HA pair using a PostgreSQL  
lease database backend, along with a separate MySQL hosts database backend,  
and a final instance with both PostgreSQL and MySQL for database backups.  

Our billing/provisioning system for our cable modem plant requires MySQL.  

**This is not something you can spin up and server DHCP with. It's mainly for  
testing, especially future integration tests for a web app I'm making. It's  
also meant to be used as a proof-of-concept for our future production  
ISC Kea servers.**

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
docker builder prune -a
```
# API
[API Reference](https://kea.readthedocs.io/en/stable/api.html)
- Primary Kea Server
  - DHCP4: Port 8000
  - DHCP6: Port 9000
- Secondary Kea Server
  - DHCP4: Port 8001
  - DHCP6: Port 9001
Replace port number to query the other servers
## Status
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"status-get"}' http://127.0.0.1:8000/
```
## Heartbeat
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"ha-heartbeat"}' http://127.0.0.1:8000/
```
# Hooks
[Available Libraries](https://kea.readthedocs.io/en/stable/arm/hooks.html#available-hook-libraries)
## Included
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-bootp
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-class-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-legal-log
  - https://kea.readthedocs.io/en/stable/arm/hooks.html#forensic-log-configuration
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-high-availability
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-host-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-lease-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-lease-query
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-limits
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-mysql
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-perfmon
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-ping-check
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-pgsql
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-stat-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-subnet-cmds