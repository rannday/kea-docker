#!/bin/sh
set -eu

curl -fsL http://127.0.0.1:8080/ >/dev/null
curl -fsL http://127.0.0.1:8080/metrics >/dev/null
curl -fsL http://127.0.0.1:9090/-/healthy >/dev/null
curl -fsL http://127.0.0.1:3000/api/health >/dev/null
