#!/bin/sh
set -eu

pg_isready -h 127.0.0.1 -p 5432 -U postgres -d postgres >/dev/null 2>&1
pg_isready -h 127.0.0.1 -p 5433 -U postgres -d postgres >/dev/null 2>&1
