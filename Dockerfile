# syntax=docker/dockerfile:1
# =============================================================================
# Jetson Thor Pinmux — single-container image
# Platform : linux/arm64 (aarch64)  Base: ubuntu:noble (24.04)
# Services : PostgreSQL 16 · Node.js 20 API (port 3001) · nginx (port 80)
#
# Build:
#   docker build --platform linux/arm64 -t pinmux:latest .
#
# Run:
#   docker run --platform linux/arm64 -p 8080:80 pinmux:latest
#   open http://localhost:8080
#
# Data persists across restarts only if you mount a volume:
#   docker run --platform linux/arm64 -p 8080:80 \
#     -v pinmux-pgdata:/var/lib/postgresql pinmux:latest
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1 — builder
#   • Installs Node.js and npm
#   • Builds the Vite/React frontend (produces /build/frontend/dist)
#   • Installs production-only backend npm packages
# -----------------------------------------------------------------------------
FROM ubuntu:noble AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# --- frontend -----------------------------------------------------------------
COPY pinmux-app/frontend/package*.json ./frontend/
RUN npm ci --prefix frontend --silent

COPY pinmux-app/frontend/ ./frontend/
RUN npm run build --prefix frontend
# output: ./frontend/dist/

# --- backend (production deps only) ------------------------------------------
COPY pinmux-app/backend/package*.json ./backend/
RUN npm ci --prefix backend --silent --omit=dev

# =============================================================================
# Stage 2 — runtime
# =============================================================================
FROM ubuntu:noble

ARG DEBIAN_FRONTEND=noninteractive

# Install PostgreSQL 16, Node.js 20, nginx, supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg nano init-system-helpers \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends \
        nodejs \
        postgresql-16 \
        nginx \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Application files
# ---------------------------------------------------------------------------
COPY --from=builder /build/frontend/dist        /app/frontend/dist
COPY --from=builder /build/backend/node_modules /app/backend/node_modules
COPY pinmux-app/backend/src/                    /app/backend/src/
COPY pinmux-app/backend/package.json            /app/backend/package.json
COPY schema.sql seed.sql                        /app/db/

# Backend env file — explicit postgres user; trust auth inside container
RUN printf 'DATABASE_URL=postgres://postgres@/pinmux?host=/var/run/postgresql\nPORT=3001\n' \
    > /app/backend/.env

# ---------------------------------------------------------------------------
# PostgreSQL — trust all local Unix-socket connections (no password in container)
# Replace every "local ... peer" line regardless of spacing or trailing whitespace
# ---------------------------------------------------------------------------
RUN PG_VER=$(ls /etc/postgresql/) \
    && sed -i -E 's/^(local[[:space:]].*)peer[[:space:]]*$/\1trust/' \
        /etc/postgresql/$PG_VER/main/pg_hba.conf

# ---------------------------------------------------------------------------
# nginx — serve built frontend, proxy /api to Node.js backend
# ---------------------------------------------------------------------------
RUN rm -f /etc/nginx/sites-enabled/default

RUN cat > /etc/nginx/sites-enabled/pinmux.conf <<'NGINX'
server {
    listen 80;
    root /app/frontend/dist;
    index index.html;

    location /api/ {
        proxy_pass         http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_read_timeout 30s;
    }

    # React SPA — fall back to index.html for client-side routes
    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# ---------------------------------------------------------------------------
# supervisord — manages PostgreSQL + Node.js + nginx as a single unit
# The PG version is baked in at build time so no runtime detection needed.
# ---------------------------------------------------------------------------
RUN PG_VER=$(ls /etc/postgresql/) \
    && cat > /etc/supervisor/conf.d/pinmux.conf <<EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:postgresql]
command=/usr/lib/postgresql/${PG_VER}/bin/postgres -D /var/lib/postgresql/${PG_VER}/main
user=postgres
autostart=true
autorestart=true
priority=10
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:backend]
command=node /app/backend/src/index.js
directory=/app/backend
environment=DATABASE_URL="postgres://postgres@/pinmux?host=/var/run/postgresql",PORT="3001"
autostart=true
autorestart=true
startretries=10
startsecs=2
priority=20
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
priority=30
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# ---------------------------------------------------------------------------
# Entrypoint — seeds the database on first boot, then starts supervisord
# ---------------------------------------------------------------------------
RUN PG_VER=$(ls /etc/postgresql/) \
    && cat > /entrypoint.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

PG_VER="${PG_VER}"
PG_BIN="/usr/lib/postgresql/\${PG_VER}/bin"
PG_DATA="/var/lib/postgresql/\${PG_VER}/main"
SOCKET_DIR="/var/run/postgresql"
DB_NAME="pinmux"

# Ensure socket directory is writable by postgres
mkdir -p "\$SOCKET_DIR"
chown postgres:postgres "\$SOCKET_DIR"
chmod 2775 "\$SOCKET_DIR"

# ---------------------------------------------------------------------------
# If the data directory is empty or missing (e.g. a fresh host-path volume
# mount shadows the image's pre-installed cluster), initialise a new cluster.
# This makes the image work with both named volumes and host-path binds.
# ---------------------------------------------------------------------------
if [[ ! -f "\${PG_DATA}/PG_VERSION" ]]; then
    echo "==> Data directory empty — initialising PostgreSQL cluster..."
    mkdir -p "\${PG_DATA}"
    chown -R postgres:postgres "\${PG_DATA}"
    chmod 700 "\${PG_DATA}"
    su -s /bin/bash postgres -c "
        \${PG_BIN}/initdb \\
            --pgdata=\${PG_DATA} \\
            --auth-local=trust \\
            --auth-host=scram-sha-256 \\
            --encoding=UTF8 \\
            --locale=C.UTF-8
    "
    # Ensure postgres listens on the expected Unix socket path
    echo "unix_socket_directories = '\${SOCKET_DIR}'" >> "\${PG_DATA}/postgresql.conf"
    echo "==> Cluster initialised."
fi

# Start PostgreSQL temporarily for DB initialisation
# Uses the data directory's own postgresql.conf (trust auth, correct socket)
echo "==> Starting PostgreSQL \${PG_VER} for first-boot check..."
su -s /bin/bash postgres -c "\${PG_BIN}/pg_ctl -D \${PG_DATA} -w start"

# Seed only if the database does not yet exist (volume re-use safe)
DB_EXISTS=\$(psql -h "\$SOCKET_DIR" -U postgres -d postgres \\
    -tAc "SELECT 1 FROM pg_database WHERE datname='\$DB_NAME'" 2>/dev/null || true)

if [[ "\$DB_EXISTS" != "1" ]]; then
    echo "==> Creating database '\${DB_NAME}' and loading schema + seed..."
    psql -h "\$SOCKET_DIR" -U postgres -d postgres \\
        -c "CREATE DATABASE \${DB_NAME};" > /dev/null
    psql -h "\$SOCKET_DIR" -U postgres -d "\$DB_NAME" -q -f /app/db/schema.sql
    psql -h "\$SOCKET_DIR" -U postgres -d "\$DB_NAME" -q -f /app/db/seed.sql
    PIN_COUNT=\$(psql -h "\$SOCKET_DIR" -U postgres -d "\$DB_NAME" \\
        -tAc "SELECT COUNT(*) FROM pins")
    echo "==> Seeded: \${PIN_COUNT} pins loaded."
else
    echo "==> Database '\${DB_NAME}' already exists — skipping seed."
fi

# Stop the temporary instance; supervisord will start the permanent one
echo "==> Stopping temporary PostgreSQL instance..."
su -s /bin/bash postgres -c "\${PG_BIN}/pg_ctl -D \${PG_DATA} -w stop"

echo "==> Handing off to supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
