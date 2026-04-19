#!/usr/bin/env bash
# =============================================================================
# setup.sh — Bootstrap the Jetson Thor Pinmux web application
#
# Run once from the pinmux1.7/ directory:
#   bash setup.sh
#
# What it does:
#   1. Verifies PostgreSQL is reachable via Unix socket (peer auth)
#   2. Creates the 'pinmux' database if it does not exist
#   3. Drops existing pinmux tables and reloads schema.sql + seed.sql
#   4. Creates pinmux-app/backend/.env if it does not already exist
#   5. Runs npm install in backend and frontend directories
#      (includes ag-grid-community ^35 and ag-grid-react ^35)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/pinmux-app/backend"
FRONTEND_DIR="$SCRIPT_DIR/pinmux-app/frontend"
SCHEMA_SQL="$SCRIPT_DIR/schema.sql"
SEED_SQL="$SCRIPT_DIR/seed.sql"
DB_NAME="pinmux"
PSQL_SOCKET_DIR="/var/run/postgresql"

# Colour helpers
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $*"; }
warn() { echo -e "${YELLOW}  !${NC} $*"; }
die()  { echo -e "${RED}  ✗ ERROR:${NC} $*" >&2; exit 1; }
step() { echo -e "\n${YELLOW}▶${NC} $*"; }

# =============================================================================
# 0. Preflight
# =============================================================================
step "Checking prerequisites"

command -v psql  >/dev/null 2>&1 || die "psql not found — install postgresql-client"
command -v node  >/dev/null 2>&1 || die "node not found — install Node.js 18+"
command -v npm   >/dev/null 2>&1 || die "npm not found — install Node.js 18+"

[[ -f "$SCHEMA_SQL" ]] || die "schema.sql not found at $SCHEMA_SQL"
[[ -f "$SEED_SQL"   ]] || die "seed.sql not found at $SEED_SQL"
[[ -d "$BACKEND_DIR"  ]] || die "Backend directory not found: $BACKEND_DIR"
[[ -d "$FRONTEND_DIR" ]] || die "Frontend directory not found: $FRONTEND_DIR"

ok "psql, node, npm found"
ok "schema.sql and seed.sql present"

# =============================================================================
# 1. PostgreSQL connectivity check
# =============================================================================
step "Verifying PostgreSQL Unix-socket connection"

if ! psql -h "$PSQL_SOCKET_DIR" -d postgres -c "SELECT 1" -q --tuples-only >/dev/null 2>&1; then
    die "Cannot connect to PostgreSQL at $PSQL_SOCKET_DIR\n" \
        "     Make sure PostgreSQL is running: sudo systemctl start postgresql"
fi
ok "PostgreSQL reachable via Unix socket"

# =============================================================================
# 2. Create database (idempotent)
# =============================================================================
step "Ensuring database '$DB_NAME' exists"

DB_EXISTS=$(psql -h "$PSQL_SOCKET_DIR" -d postgres \
    -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null || true)

if [[ "$DB_EXISTS" != "1" ]]; then
    psql -h "$PSQL_SOCKET_DIR" -d postgres -c "CREATE DATABASE $DB_NAME;" >/dev/null
    ok "Database '$DB_NAME' created"
else
    ok "Database '$DB_NAME' already exists"
fi

# =============================================================================
# 3. Load schema and seed data
# =============================================================================
step "Loading schema (drops existing tables)"

psql -h "$PSQL_SOCKET_DIR" -d "$DB_NAME" -q <<'SQL'
DROP TABLE IF EXISTS pad_voltage_configs, pin_configs, pad_voltage_rails, configurations, pins CASCADE;
SQL
ok "Existing tables dropped"

psql -h "$PSQL_SOCKET_DIR" -d "$DB_NAME" -q -f "$SCHEMA_SQL"
ok "schema.sql loaded"

step "Seeding reference data and DevKit template configuration"

psql -h "$PSQL_SOCKET_DIR" -d "$DB_NAME" -q -f "$SEED_SQL"

PIN_COUNT=$(psql -h "$PSQL_SOCKET_DIR" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM pins" 2>/dev/null)
CFG_COUNT=$(psql -h "$PSQL_SOCKET_DIR" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM configurations" 2>/dev/null)
ok "seed.sql loaded — $PIN_COUNT pins, $CFG_COUNT configuration(s)"

# =============================================================================
# 4. Backend .env
# =============================================================================
step "Configuring backend .env"

ENV_FILE="$BACKEND_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    cat > "$ENV_FILE" <<ENV
# Unix socket (peer auth) — no password needed on this machine
DATABASE_URL=postgres:///$DB_NAME?host=$PSQL_SOCKET_DIR
PORT=3001
ENV
    ok ".env created at $ENV_FILE"
else
    ok ".env already exists — not overwritten"
fi

# =============================================================================
# 5. npm install — backend
# =============================================================================
step "Installing backend npm packages"

(cd "$BACKEND_DIR" && npm install --silent)
ok "Backend packages installed (express, pg, cors, dotenv, archiver)"

# =============================================================================
# 6. npm install — frontend (includes ag-grid v35)
# =============================================================================
step "Installing frontend npm packages"

(cd "$FRONTEND_DIR" && npm install --silent)
ok "Frontend packages installed (React, Vite, ag-grid-community ^35, ag-grid-react ^35)"

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete.${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo "  To start the application, open two terminals:"
echo ""
echo "    Terminal 1 — Backend:"
echo "      cd $BACKEND_DIR"
echo "      npm run dev"
echo ""
echo "    Terminal 2 — Frontend:"
echo "      cd $FRONTEND_DIR"
echo "      npm run dev"
echo ""
echo "  Then open: http://localhost:5173"
echo ""
