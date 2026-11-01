#!/usr/bin/env bash
# Backup di Mergin Maps: dump del database e copia incrementale dei progetti.
#
# Uso (sulla VM, dalla radice del repository, anche da cron):
#   scripts/backup.sh [cartella_di_destinazione]     # predefinita: ./backup
#
# - database: pg_dump in formato custom (si ripristina con pg_restore);
# - progetti: un'istantanea al giorno con rsync --link-dest, quindi i file invariati
#   non occupano spazio due volte;
# - conserva gli ultimi $GIORNI giorni. La copia fuori dalla VM è un passo separato.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST=$(realpath -m "${1:-backup}")
GIORNI=${GIORNI:-14}
STAMP=$(date +%F_%H%M)
sudo mkdir -p "$DEST/db" "$DEST/projects"

# database del backend: DB_DATABASE di .prod.env, predefinito "postgres"
DB=$(grep -E '^DB_DATABASE=' .prod.env | cut -d= -f2 || true)
docker compose exec -T db pg_dump -U postgres -Fc "${DB:-postgres}" | sudo tee "$DEST/db/mergin_$STAMP.dump" >/dev/null
sudo test -s "$DEST/db/mergin_$STAMP.dump" || { echo "dump vuoto: controlla il container db" >&2; exit 1; }

ULTIMA=$(sudo find "$DEST/projects" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
sudo rsync -a --numeric-ids --delete ${ULTIMA:+--link-dest="$ULTIMA"} projects/ "$DEST/projects/$STAMP/"

sudo find "$DEST/db" -name 'mergin_*.dump' -mtime +"$GIORNI" -delete
# le istantanee si scartano in base al nome: rsync -a copia la data di modifica di projects/
LIMITE=$(date -d "-$GIORNI days" +%F)
for d in $(sudo find "$DEST/projects" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'); do
  if [[ "${d%%_*}" < "$LIMITE" ]]; then sudo rm -rf "${DEST:?}/projects/$d"; fi
done
sudo du -sh "$DEST/db/mergin_$STAMP.dump" "$DEST/projects/$STAMP"
