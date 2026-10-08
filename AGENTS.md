# Working in kea-docker

This repository builds a Docker Compose lab for Kea DHCP high availability, BIND9 DNS/DDNS, PostgreSQL, and Stork monitoring. It contains Linux container configuration and POSIX shell entrypoints, with PowerShell lifecycle helpers for Windows hosts.

Read [.agents/skills/kea-docker/SKILL.md](.agents/skills/kea-docker/SKILL.md) when changing or diagnosing this stack. It maps the services, configuration dependencies, and validation commands. Treat the current Compose file and Dockerfiles as authoritative for addresses, mounts, and installed packages.

## Scope and data

- Inspect Git status before editing. Preserve unrelated changes and local `.serena/` configuration.
- Keep fixes at the responsible service or configuration layer. Inspect both DHCP peers before changing shared behavior; their files contain intentional differences.
- Preserve named volumes, database contents, Stork agent identities, Grafana state, and `.logs/`. Do not use a clean rebuild or reset to diagnose an unknown failure.
- `scripts/full-down.ps1` removes volumes, images, orphan containers, and DHCP logs. Run it only when the user explicitly authorizes that data loss. `quick-down.ps1` also stops the stack; a review does not authorize running it.
- Builds, container recreation, database initialization/migration, agent registration, and network changes affect runtime state. Perform them only within the user's authorized task.
- Do not read or edit protected environment files or PEM files, including `stork/server.env`. Ask for a redacted example when those settings matter. Do not copy credentials or keys into guidance, logs, or review reports.
- Keep the current loopback-only published ports unless wider access is requested. The Docker bridge is a lab network; changing it to serve a physical LAN requires explicit scope.

## Tools and edits

Follow the user's global tool routing: FFF for bounded names/text search, Desktop Commander for known-file reads, Serena for semantic work, gk for local Git, and native shell for validation. Name unavailable tools before using a bounded fallback. Do not activate another Serena project or modify its configuration as routine setup.

Preserve `.gitattributes`: container shell scripts, Dockerfiles, and configuration use LF. Shell entrypoints use `/bin/sh`; avoid Bash-only syntax. Keep PowerShell helpers native. Do not run the repository-wide CRLF fixer for a narrow edit.

Dockerfile `COPY` changes require rebuilding the affected image before runtime verification. Read-only bind mounts use repository files, but running daemons may still need reload or restart. Do not describe a source edit as deployed until the affected runtime has been checked.

## Validation and completion

Use the skill's task-specific validation commands. Start with static checks; run live checks only when the task covers runtime interaction. This repository has service healthchecks rather than a dedicated automated test suite. A healthy container does not prove DHCP failover, DNS updates, replication freshness, or LAN reachability.

Report changed files, checks run, review findings, skipped checks, and Windows/Linux limits. Do not fix review findings, install dependencies, commit, push, or reset data unless requested.
