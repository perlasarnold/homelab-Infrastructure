#!/bin/bash
# docker/guacamole/init/generate-schema.sh
# Run this ONCE locally to generate the Guacamole initdb.sql schema.
# Then commit the generated initdb.sql file.
#
# Usage:
#   bash docker/guacamole/init/generate-schema.sh
#
# Requires Docker available locally.

set -euo pipefail
OUT="$(dirname "$0")/initdb.sql"

echo "Generating Guacamole PostgreSQL schema..."
docker run --rm guacamole/guacamole:latest /opt/guacamole/bin/initdb.sh --postgresql > "$OUT"
echo "Schema written to: $OUT"
echo "Commit this file, then run: docker compose up -d"
