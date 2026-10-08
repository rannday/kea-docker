---
name: kea-docker
description: Work on this kea-docker repository's Compose topology, Kea DHCP HA, BIND9 DDNS, PostgreSQL replication, Stork monitoring, and Windows lifecycle scripts. Use for repository changes, reviews, and stack diagnosis; not for unrelated DHCP deployments.
---

# kea-docker

Work from the repository root. Read `AGENTS.md` and inspect the worktree before editing. Diagnose from the affected service's source, healthcheck, and bounded runtime evidence before proposing a change. This skill provides repository context, not permission to alter running services or persistent data.

## Map the stack

`docker-compose.yml` defines project `kea`, seven services, explicitly named volumes, and bridge network `net`. The bridge subnets are `192.168.69.0/24` and `fd69:69:69::/64`. IPv6 service addresses use the same final component as their IPv4 addresses, for example `fd69:69:69::10`.

| Service | IPv4 | Responsibility | Published host ports |
| --- | --- | --- | --- |
| `dhcp1` | `192.168.69.10` | Primary Kea DHCP4/DHCP6/DDNS, local lease PostgreSQL, Stork agent | `8100:8000`, `8101:8001`, `8102:8002` |
| `dhcp2` | `192.168.69.11` | Secondary Kea peer, its own lease PostgreSQL and Stork agent | `8200:8000`, `8201:8001`, `8202:8002` |
| `dns1` | `192.168.69.200` | Primary BIND9 zones and exporter | None |
| `dns2` | `192.168.69.201` | Secondary BIND9 zones and exporter | None |
| `database` | `192.168.69.2` | Shared Kea hosts/forensic database | None |
| `backups` | `192.168.69.69` | PostgreSQL streaming standbys for dhcp1 leases and the shared database | None |
| `stork` | `192.168.69.100` | Stork server, its PostgreSQL, Prometheus, Grafana | `8080`, `9090`, `3000` |

All published ports bind to `127.0.0.1`. GUI URLs are `http://127.0.0.1:8080` (Stork), `http://127.0.0.1:3000` (Grafana), and `http://127.0.0.1:9090` (Prometheus). Kea's published ports are HTTP control APIs, not GUIs. Container IPs are bridge addresses; on Docker Desktop, use published ports from the Windows host. DNS and DHCP traffic are not published to the host by this Compose file. Do not infer physical LAN service from healthy containers.

The `backups` service maintains streaming replicas, not independent historical backups. Its healthcheck tests readiness and recovery mode on local ports `5432` and `5433`; it does not prove recent WAL replay or a tested restore.

## Find the responsible files

- Each service directory contains a `Dockerfile`, `entrypoint.sh`, `healthcheck.sh`, and firewall rules. These are multi-process containers; inspect startup ordering, PID supervision, signal handling, and database setup together.
- `dhcp1/` and `dhcp2/`: Kea `kea-dhcp4.conf`, `kea-dhcp6.conf`, and `kea-dhcp-ddns.conf` are read-only bind mounts. PostgreSQL templates and scripts are copied into the image. Each peer stores leases locally; Kea HA synchronizes lease state. PostgreSQL streaming replication is a separate mechanism.
- `dns1/`: `named.conf` and primary `zones/` are bind-mounted. `dns2/named.conf` defines the secondary. Check both BIND configuration and Kea DDNS destinations when changing zones or update routing.
- `database/` and `backups/`: initialization and standby setup live in entrypoints. Preserve existing volume initialization guards and identify schema/version compatibility before migrations.
- `stork/`: Prometheus scrape configuration, Grafana settings, provisioning, dashboards, and server settings are copied into the image. The entrypoint copies bundled dashboards to the Grafana volume on startup. Do not read protected `server.env`; request redacted settings if needed.
- `scripts/`: PowerShell helpers use the repository root. `quick-up.ps1` creates DHCP log directories and starts Compose; `quick-down.ps1` stops/removes containers while retaining volumes. `full-up.ps1` builds without cache and recreates containers. `full-down.ps1` deletes volumes, images, orphan containers, and DHCP logs; require explicit reset authorization.

Images use Debian Bookworm. Kea and Stork packages come from development repositories without version pins; check the installed runtime version when behavior depends on a release. Do not assume documentation for a stable release matches the image.

## Preserve configuration relationships

- Compare both DHCP peers rather than copying one over the other. Preserve peer identities, reciprocal HA settings, shared pool/subnet definitions, and intentional hook differences.
- Keep Kea control ports `8000`/`8001`/`8002` distinct from HA endpoints `9000`/`9001` and Stork agent port `8080`. A host GUI port change does not require changing internal agent URLs.
- Address or port edits can affect Compose, Kea peer URLs, Stork agent settings, Prometheus targets, BIND transfer/update rules, PostgreSQL access rules, and `nftables.conf`. Inspect only the dependencies relevant to the change.
- Prometheus scrapes Kea agent exporters on `9547`, BIND exporters on `9119`, and Stork `/metrics` on internal `127.0.0.1:8080`. Dashboard datasource provisioning and query labels must agree with those jobs.
- Distinguish the Docker bridge from configured DHCP client subnets: IPv4 `192.0.3.0/24` and IPv6 `fd69:69:69:1::/64`. Subnet changes also need matching DNS reverse-zone and DDNS review.
- Keep POSIX shell syntax and LF endings. Kea configuration supports comments; use Kea's parser rather than treating these `.conf` files as strict JSON.

## Diagnose without resetting

For an authorized runtime diagnosis, start with bounded reads:

```powershell
docker compose ps
docker compose logs --tail 100 stork
docker port stork
docker network inspect net --format '{{json .IPAM.Config}}'
```

Select the affected service instead of dumping every log or full container inspection, which may expose credentials. For host port conflicts, inspect `Get-NetTCPConnection -LocalPort 8080 -State Listen`, identify the owning PID with `Get-Process`, and run `docker ps --filter publish=8080`. Docker Desktop's backend may own the Windows socket for a different container. Do not kill the backend or stop that container without authorization. Change only the host side of a mapping when the user chooses another GUI port.

For missing metrics, check exporter health, the Prometheus target, and dashboard datasource/query before changing dashboards. For standby problems, distinguish recovery mode from active WAL receipt/replay. Do not delete database volumes to make initialization succeed.

## Validate the affected layer

There is no dedicated automated test suite in this checkout. Choose checks appropriate to the files changed; do not run the full stack as a documentation check.

- Compose changes: `docker compose config --quiet`; avoid printing resolved configuration containing sensitive values. If a protected environment file would be required, use an approved redacted fixture rather than opening it.
- POSIX scripts: run `sh -n` with a Linux shell for each changed script. Use the global WSL test instructions for Windows-to-WSL execution; native PowerShell cannot validate `/bin/sh` syntax. Do not install a shell or linter without authorization.
- PowerShell scripts: use `[System.Management.Automation.Language.Parser]::ParseFile` and report syntax errors without executing lifecycle operations. `$ErrorActionPreference = "Stop"` alone does not establish that Docker native command failures stop a script; inspect exit-code handling.
- Kea configs: in the affected running container, use `kea-dhcp4 -t /etc/kea/kea-dhcp4.conf`, `kea-dhcp6 -t /etc/kea/kea-dhcp6.conf`, or `kea-dhcp-ddns -t /etc/kea/kea-dhcp-ddns.conf`. These checks require the matching installed packages/hooks and container context.
- BIND configs/zones: use `named-checkconf` and `named-checkzone` inside the affected image/container with the actual mounted paths. For dynamic zones, account for journal state; do not modify running zone files merely to validate them.
- Grafana dashboard JSON: parse the changed file as JSON. Validate provisioning and Prometheus configuration with installed tools where available; runtime metrics/query checks require the affected service to be running.
- Image changes: static source checks do not prove a build. Rebuild only the affected service when authorized, then check its health and relevant endpoint. Distinguish bind-mounted edits from Dockerfile `COPY` edits requiring a new image.

For live checks, `docker compose exec -T SERVICE /usr/local/bin/healthcheck.sh` runs the repository's existing healthcheck. Passing it proves only its implemented checks. HA failover, actual DHCP exchanges, DDNS updates, database replay freshness, and restore behavior need separate task-specific evidence.

Finish with changed paths, exact checks and results, unresolved findings, and skipped runtime/platform validation. A review authorizes findings, not unrequested fixes or resets.
