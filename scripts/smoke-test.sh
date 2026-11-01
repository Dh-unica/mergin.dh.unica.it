#!/usr/bin/env bash
# Controlli rapidi dello stack Mergin Maps, da lanciare sulla VM dalla radice del repository.
# Solo letture: non modifica nulla. Esce con codice 1 se un controllo fallisce.
set -uo pipefail

cd "$(dirname "$0")/.."
PORTA=$(grep -E '^MERGIN_PORT=' .env 2>/dev/null | cut -d= -f2)
PORTA=${PORTA:-127.0.0.1:8086}
esito=0

ok() { echo "  OK    $*"; }
ko() { echo "  ERRORE $*"; esito=1; }

echo "Container:"
for c in merginmaps-db merginmaps-redis merginmaps-server celery-beat celery-worker merginmaps-web merginmaps-proxy; do
  stato=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo assente)
  [ "$stato" = running ] && ok "$c" || ko "$c: $stato"
done

echo "API:"
ping=$(curl -s "http://$PORTA/ping")
echo "$ping" | grep -q '"version"' && ok "/ping $(echo "$ping" | tr -d '\n ' | cut -c1-120)" || ko "/ping: $ping"
config=$(curl -s "http://$PORTA/config")
echo "$config" | grep -q 'server_type' && ok "/config $(echo "$config" | grep -oE '"(server_type|version)": *"[^"]*"' | tr '\n' ' ')" || ko "/config non valido"
codice=$(curl -s -o /dev/null -w '%{http_code}' "http://$PORTA/")
[ "$codice" = 200 ] && ok "interfaccia web -> 200" || ko "interfaccia web -> $codice"

echo "Permessi dei dati:"
stat -c '%u:%g %a' mergin_db | grep -q '^999:.* 700$' && ok "mergin_db 999, 700" || ko "mergin_db: $(stat -c '%u:%g %a' mergin_db)"
stat -c '%u:%g' projects | grep -q '^901:999$' && ok "projects 901:999" || ko "projects: $(stat -c '%u:%g' projects)"

echo "Errori recenti nei log (ultimi 15 minuti):"
n=$(docker compose logs --since 15m server celery-worker db 2>&1 | grep -iE 'error|exception|traceback|fatal|panic' \
  | grep -vc 'the database system is starting up' || true)
[ "$n" -eq 0 ] && ok "nessuno" || ko "$n righe: docker compose logs --since 15m server celery-worker db"

exit $esito
