# Kea Docker

Docker Compose lab with Kea DHCP in load balancing HA, primary/secondary BIND9
with DDNS, and Stork, Prometheus, and Grafana monitoring.

Each DHCP peer has a local PostgreSQL lease database; Kea HA synchronizes leases.
A shared PostgreSQL database stores host reservations and forensic logs. The
backups service maintains streaming standbys for the primary peer's leases and
the shared database.

## Start and switch modes

The default lab has no active container firewalls:

```sh
docker compose -f docker-compose.yml up -d --build --force-recreate
```

Enable firewalls for all seven services by adding the explicit override:

```sh
docker compose -f docker-compose.yml -f docker-compose.firewall.yml up -d --build --force-recreate
```

The firewall file is an override, not a standalone stack, and is never selected
automatically. It adds `NET_ADMIN`, read-only nftables mounts, and
`ENABLE_FIREWALL: "true"`. Only that exact value enables loading; loading errors
abort startup.

Both commands preserve the same `kea` project, volumes, network, addresses, and
ports. Use the desired command to switch modes. Recreating containers discards
previously loaded namespace firewall rules when disabling firewalls. Rebuilding
incorporates entrypoint changes copied into the images.

Stop and remove containers while retaining volumes; add the firewall override
if using that mode:

```sh
docker compose -f docker-compose.yml down --remove-orphans
```

## Lifecycle helpers

PowerShell uses `-Firewall`; POSIX shell uses `--firewall`. Omit the flag for
the default lab. Every helper explicitly selects the appropriate Compose files.

| Helper | Behavior |
| --- | --- |
| `quick-up` | Start existing images |
| `quick-down` | Remove containers and orphans; retain volumes |
| `full-up` | Build without cache and recreate; retain volumes |
| `full-down` | **Delete volumes, images, orphan containers, and DHCP log contents** |

```powershell
.\scripts\quick-up.ps1
.\scripts\quick-up.ps1 -Firewall
.\scripts\quick-down.ps1 -Firewall
.\scripts\full-up.ps1 -Firewall
```

```sh
sh scripts/quick-up.sh
sh scripts/quick-up.sh --firewall
sh scripts/quick-down.sh --firewall
sh scripts/full-up.sh --firewall
```

Use `full-up` with the desired flag to switch modes through a helper.
**Do not use `full-down` or `--volumes` to switch modes.**

## Access

Published ports bind only to `127.0.0.1`. This is a Docker bridge lab; DHCP and
DNS are not published to the host or physical LAN.

| Dashboard | URL |
| --- | --- |
| Stork | http://127.0.0.1:8080 |
| Grafana | http://127.0.0.1:3000 |
| Prometheus | http://127.0.0.1:9090 |

Kea HTTP control API ports:

| Peer | DHCP4 | DHCP6 | DDNS |
| --- | --- | --- | --- |
| Primary | 8100 | 8101 | 8102 |
| Secondary | 8200 | 8201 | 8202 |

Query status below; use `ha-heartbeat` for an HA heartbeat or change the port
for another daemon. Curl prompts for the API password.

```sh
curl --user kea -H "Content-Type: application/json" -d '{"command":"status-get"}' http://127.0.0.1:8100/
```

## References

- [Lab exercises and scoped replica recovery](doc/EXERCISES.md)
- [Kea API](https://kea.readthedocs.io/en/stable/api.html)
- [PostgreSQL setup](https://kea.readthedocs.io/en/stable/arm/admin.html#pgsql-database-create)
- [Logging](https://kea.readthedocs.io/en/stable/arm/logging.html)
- [Hooks](https://kea.readthedocs.io/en/stable/arm/hooks.html#available-hook-libraries)
- [Stork](https://kea.readthedocs.io/en/stable/arm/stork.html)
