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
## Check Status
### DHCP4 Status
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"status-get"}' http://127.0.0.1:8000/
```
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"status-get"}' http://127.0.0.1:8001/
```
#### HA Heartbeat
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"ha-heartbeat"}' http://127.0.0.1:8000/
```
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"ha-heartbeat"}' http://127.0.0.1:8001/
```
### DHCP6 Status
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"status-get"}' http://127.0.0.1:9000/
```
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"status-get"}' http://127.0.0.1:9001/
```
#### HA Heartbeat
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"ha-heartbeat"}' http://127.0.0.1:9000/
```
```bash
curl -u kea:keapass -X POST -H "Content-Type: application/json" -d '{"command":"ha-heartbeat"}' http://127.0.0.1:9001/
```