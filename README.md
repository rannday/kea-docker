# Kea Docker
Goal - Two ISC Kea instances in a load balancing HA pair using a PostgreSQL  
lease database backend, along with a separate MySQL hosts database backend,  
and a final instance with both PostgreSQL and MySQL for database backups.  

Our billing/provisioning system for our cable modem plant requires MySQL.  

**This is not something you can spin up and server DHCP with. It's mainly for  
testing, especially future integration tests for a web app I'm making. It's  
also meant to be used as a proof-of-concept for our future production  
ISC Kea servers.**