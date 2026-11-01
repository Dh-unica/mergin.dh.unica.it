#!/usr/bin/env bash
# Backup di Mergin Maps: dump del database e copia incrementale dei progetti.
#
# Uso (sulla VM, dalla radice del repository, anche da cron):
#   scripts/backup.sh [cartella_di_destinazione]     # predefinita: ./backup
#
# - durante il backup il server è in manutenzione (file MAINTENANCE_FILE): rifiuta le scritture,
#   quindi dump e istantanea dei progetti sono coerenti tra loro;
# - database: pg_dump in formato custom (si ripristina con pg_restore);
# - progetti: un'istantanea al giorno con rsync --link-dest, quindi i file invariati
#   non occupano spazio due volte;
# - il dump contiene gli hash delle password: cartelle 700, dump 600;
# - conserva gli ultimi $GIORNI giorni. La copia fuori dalla VM è un passo separato.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST=$(realpath -m "${1:-backup}")
GIORNI=${GIORNI:-14}
STAMP=$(date +%F_%H%M)
install -d -m 700 "$DEST"
sudo install -d -m 700 "$DEST/db" "$DEST/projects"
DUMP="$DEST/db/mergin_$STAMP.dump"
# database del backend: DB_DATABASE di .prod.env, predefinito "postgres"
DB=$(grep -E '^DB_DATABASE=' .prod.env | cut -d= -f2 || true)

# MAINTENANCE_FILE=/data/MAINTENANCE nel container, cioè projects/MAINTENANCE sull'host
MANUTENZIONE=projects/MAINTENANCE
sudo touch "$MANUTENZIONE"
trap 'sudo rm -f "$MANUTENZIONE"' EXIT
sleep 10   # lascia finire le richieste di scrittura già in corso

docker compose exec -T db pg_dump -U postgres -Fc "${DB:-postgres}" | sudo sh -c 'umask 077; cat > "$1"' sh "$DUMP"
sudo test -s "$DUMP" || { echo "dump vuoto: controlla il container db" >&2; exit 1; }

ULTIMA=$(sudo find "$DEST/projects" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
sudo rsync -a --numeric-ids --delete --exclude=/MAINTENANCE ${ULTIMA:+--link-dest="$ULTIMA"} projects/ "$DEST/projects/$STAMP/"

sudo rm -f "$MANUTENZIONE"
trap - EXIT

sudo find "$DEST/db" -name 'mergin_*.dump' -mtime +"$GIORNI" -delete
# le istantanee si scartano in base al nome: rsync -a copia la data di modifica di projects/
LIMITE=$(date -d "-$GIORNI days" +%F)
for d in $(sudo find "$DEST/projects" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'); do
  if [[ "${d%%_*}" < "$LIMITE" ]]; then sudo rm -rf "${DEST:?}/projects/$d"; fi
done
sudo du -sh "$DUMP" "$DEST/projects/$STAMP"
