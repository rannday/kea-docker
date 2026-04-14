#!/bin/sh
set -eu

mariadb-admin -uroot -prootpass ping >/dev/null 2>&1
pg_isready -h 127.0.0.1 -p 5432 -U postgres -d postgres >/dev/null 2>&1
