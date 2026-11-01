#!/usr/bin/env bash
# Ripristina database e progetti di Mergin Maps dall'export Faunalia nella cartella del repository.
#
# Uso (sulla VM, dalla radice del repository):
#   scripts/ripristina-export.sh ~/archivi-faunalia/mergin_export_20261027.tar.gz
#
# Cosa fa:
#   - estrae come root, con --numeric-owner, solo mergin_db/, projects/, diagnostic_logs/ e .prod.env
#     dell'export: i file appartengono a 999 (postgres) e 901:999 (Mergin) e i container contano
#     su quei numeri, non sui nomi;
#   - rimuove il postmaster.pid rimasto dalla copia a caldo;
#   - crea .prod.env dall'originale (segreti invariati) con i valori del DH e .env con la password
#     del database ricavata da .prod.env.
# Si ferma se i dati sono già presenti: non sovrascrive mai.
set -euo pipefail

ARCHIVIO=${1:?"uso: $0 /percorso/mergin_export_AAAAMMGG.tar.gz"}
ARCHIVIO=$(realpath "$ARCHIVIO")
BASE_URL=${MERGIN_BASE_URL:-mergin.dh.unica.it}
CONTATTO=${CONTACT_EMAIL:-dh@unica.it}
QUOTA=${GLOBAL_STORAGE:-32212254720}   # 30 GiB
REPO=$(cd "$(dirname "$0")/.." && pwd)
PREFISSO=mergin_export/deployment/community

cd "$REPO"
for p in mergin_db projects diagnostic_logs .prod.env .env; do
  if [ -e "$p" ]; then
    echo "$p esiste già: interrompo per non sovrascrivere." >&2
    exit 1
  fi
done

TMP=$(mktemp -d "$REPO/.ripristino.XXXXXX")
trap 'sudo rm -rf "$TMP"' EXIT

echo "Estrazione di $(basename "$ARCHIVIO") (circa 6,5 GB)..."
sudo tar --numeric-owner -xzpf "$ARCHIVIO" -C "$TMP" \
  "$PREFISSO/mergin_db" "$PREFISSO/projects" "$PREFISSO/diagnostic_logs" "$PREFISSO/.prod.env"

for d in mergin_db projects diagnostic_logs; do
  sudo mv "$TMP/$PREFISSO/$d" "$d"
done
sudo rm -f mergin_db/postmaster.pid

# .prod.env: segreti originali, valori del DH. SECURITY_PASSWORD_SALT non si tocca mai.
# umask 077 prima di creare i file, così i segreti non sono mai leggibili da altri.
umask 077
sudo cat "$TMP/$PREFISSO/.prod.env" \
  | sed -E "s|^MERGIN_BASE_URL=.*|MERGIN_BASE_URL=$BASE_URL|; s|^CONTACT_EMAIL=.*|CONTACT_EMAIL=$CONTATTO|; s|^GLOBAL_STORAGE=.*|GLOBAL_STORAGE=$QUOTA|" \
  > .prod.env
{
  grep -E '^DB_PASSWORD=' .prod.env | sed 's/^DB_PASSWORD=/POSTGRES_PASSWORD=/'
  echo "MERGIN_PORT=127.0.0.1:8086"
} > .env

echo "Proprietari e permessi (attesi 999:0 700 per mergin_db, 901:999 2750 per projects):"
sudo stat -c '  %u:%g %a %n' mergin_db projects diagnostic_logs
echo "Valori in .prod.env:"
grep -E '^(MERGIN_BASE_URL|CONTACT_EMAIL|GLOBAL_STORAGE)=' .prod.env | sed 's/^/  /'
echo "Ripristino completato. Prossimo passo: scripts/verifica-db.sh"
