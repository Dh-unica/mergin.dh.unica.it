#!/usr/bin/env bash
# Primo avvio del solo database dopo il ripristino e verifica di coerenza.
#
# La cartella mergin_db dell'export è stata copiata con PostgreSQL acceso (c'erano postmaster.pid e
# pg_stat_tmp aggiornati): al primo avvio PostgreSQL fa il crash recovery dal WAL. Questo script
# controlla che il recovery sia andato a buon fine e che tutte le tabelle siano leggibili, producendo
# un dump completo che vale anche come primo backup.
#
# Uso (sulla VM, dalla radice del repository):
#   scripts/verifica-db.sh            # avvio del db, log, conteggi, dump completo
#   scripts/verifica-db.sh --amcheck  # in più verifica gli indici btree con amcheck
#                                     # (crea l'estensione amcheck nel DB mergin)
set -euo pipefail

cd "$(dirname "$0")/.."
DEST=backup
STAMP=$(date +%F_%H%M)
mkdir -p "$DEST"
psql() { docker compose exec -T db psql -U postgres -d mergin -v ON_ERROR_STOP=1 -At "$@"; }

docker compose up -d db
echo "Attesa del database..."
for _ in $(seq 1 60); do
  docker compose exec -T db pg_isready -U postgres -q && break
  sleep 2
done
docker compose exec -T db pg_isready -U postgres

echo "Log di avvio (recovery):"
docker compose logs db 2>&1 | grep -E 'interrupted|recovery|redo|ready to accept|PANIC|FATAL|ERROR|invalid' | sed 's/^/  /'

echo "Versione dello schema (alembic): $(psql -c 'select version_num from alembic_version;')"
echo "Utenti: $(psql -c 'select count(*) from "user";')"
echo "Progetti: $(psql -c 'select count(*) from project;')"
echo "Versioni di progetto: $(psql -c 'select count(*) from project_version;')"

echo "Dump completo (prova di lettura di tutte le tabelle)..."
docker compose exec -T db pg_dumpall -U postgres | gzip > "$DEST/mergin_pg_dumpall_$STAMP.sql.gz"
echo "  OK: $(ls -lh "$DEST/mergin_pg_dumpall_$STAMP.sql.gz" | awk '{print $5, $9}')"

if [ "${1:-}" = "--amcheck" ]; then
  echo "Verifica degli indici btree con amcheck..."
  psql -c 'create extension if not exists amcheck;' >/dev/null
  psql -c "select count(*) from (
             select bt_index_check(c.oid) from pg_index i
             join pg_class c on c.oid = i.indexrelid
             join pg_am a on a.oid = c.relam
             join pg_namespace n on n.oid = c.relnamespace
             where a.amname = 'btree' and n.nspname = 'public') t;" \
    | sed 's/^/  indici verificati: /'
fi
echo "Database coerente. Prossimo passo: docker compose up -d && scripts/smoke-test.sh"
