#!/bin/sh
set -eu

dig @127.0.0.1 example.com SOA +short | grep -q 'ns1.example.com.'
curl -sf http://127.0.0.1:9119/metrics >/dev/null
