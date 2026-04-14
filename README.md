# Kea Docker
Goal - Two ISC Kea instances in a load balancing HA pair using a PostgreSQL  
lease database backend, along with a separate MySQL hosts database backend,  
and a final instance with both PostgreSQL and MySQL for database backups.  

Our billing/provisioning system for our cable modem plant requires MySQL.  

*TO-DO: Add final instance for database backups.*  

**This is not something you can spin up and server DHCP with. It's mainly for  
testing, especially future integration tests for a web app I'm making. It's  
also meant to be used as a proof-of-concept for our future production  
ISC Kea servers.**

## Documenation
[Kea Installation](https://kea.readthedocs.io/en/stable/arm/install.html)
### Hooks
[Hook Libraries](https://kea.readthedocs.io/en/stable/arm/hooks.html#available-hook-libraries)
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-bootp
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-class-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-ddns-tuning
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-flex-id
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-flex-option
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-legal-log
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-gss-tsig
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-high-availability
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-host-cache
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-host-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-lease-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-lease-query
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-limits
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-mysql
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-perfmon
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-ping-check
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-stat-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-subnet-cmds
- https://kea.readthedocs.io/en/stable/arm/hooks.html#hooks-user-chk