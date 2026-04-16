$TTL 300
@   IN  SOA ns1.example.com. hostmaster.example.com. (
        2026041501
        300
        120
        604800
        300
)

    IN  NS  ns1.example.com.
    IN  NS  ns2.example.com.

ns1 IN  A   192.168.69.200
ns1 IN  AAAA fd69:69:69::200
ns2 IN  A   192.168.69.201
ns2 IN  AAAA fd69:69:69::201
