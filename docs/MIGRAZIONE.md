# Migrazione di Mergin Maps dal server Faunalia a dhgeo

Fino a ottobre 2026 Faunalia (Ulisse Cavallini) ospitava Mergin Maps su `mergin.webparc.it`. Il 28/10/2026 ha consegnato l'export `mergin_export_20261027.tar.gz` (3,4 GB). Il nuovo indirizzo è `mergin.dh.unica.it`, su dhgeo dietro il reverse proxy del Centro.

Il piano complessivo, che comprende Lizmap, la scelta della VM, il DNS e il proxy, sta nella cartella di lavoro `mergin-lizmap/PIANO-MIGRAZIONE.md`. Qui c'è la parte che riguarda Mergin.

## Contenuto dell'export

L'export è il clone git di [MerginMaps/server](https://github.com/MerginMaps/server) usato da Faunalia, con i dati dentro `deployment/community/`:

| Percorso | Contenuto | Destinazione |
|---|---|---|
| `deployment/community/docker-compose.yml` | 7 servizi: db, redis, server, celery-beat, celery-worker, web, proxy | versionato in radice, con le correzioni sotto |
| `deployment/community/.prod.env` | configurazione con i segreti | `.prod.env` sul server; copia oscurata in `.prod.env.example` |
| `deployment/common/nginx.conf` | proxy interno | `nginx.conf` in radice, invariato |
| `deployment/common/telemetry/.otel.env` | telemetria (disattivata) | `otel.env` in radice |
| `deployment/community/mergin_db/` | cartella dati di PostgreSQL 14 (69 MB) | dati, non versionati |
| `deployment/community/projects/` | 6,4 GB: 6 progetti e 0,9 GB di archivi zip | dati, non versionati |
| resto del clone (`server/`, `web-app/`, `.git/`) | sorgente upstream alla 2026.5.0 | non serve: le immagini sono già costruite |

## Problemi trovati e correzioni

1. **Database copiato con PostgreSQL acceso.** In `mergin_db/` c'erano `postmaster.pid` e file di `pg_stat_tmp/` modificati alle 12:28 del 27/10, un minuto prima della chiusura dell'archivio. Al primo avvio PostgreSQL fa il crash recovery dal WAL. `scripts/verifica-db.sh` avvia il solo database, legge il log del recovery e fa un `pg_dumpall` completo come prova di lettura. A Faunalia è stato chiesto anche un `pg_dump` fatto a servizi fermi.
2. **Proprietari dei file.** Nell'archivio i file appartengono agli uid 999 e 901, con il gruppo registrato per nome come `systemd-journal` (gid 999 sul server Faunalia). Su dhgeo `systemd-journal` è il gid **101**: un'estrazione senza `--numeric-owner`, come nelle istruzioni ricevute, avrebbe tolto a Nginx e al frontend (che girano come `101:999`) l'accesso ai progetti.
3. **Versioni.** Il sorgente del clone è stato aggiornato il 14/10 alla 2026.5.0, ma il compose usa le immagini 2025.7.3 ed è con queste che girava il database. Si resta sulla 2025.7.3; l'aggiornamento è un passo separato.
4. **Porte.** L'originale pubblicava `8080` e `8082` su tutte le interfacce. La 8082 serviva solo a Grafana (blocco commentato in `nginx.conf`) e non si pubblica più. La 8080 diventa `MERGIN_PORT`, predefinita `127.0.0.1:8086`.
5. **Password del database in chiaro nel compose.** Ora arriva da `.env` (`POSTGRES_PASSWORD`), ricavata da `DB_PASSWORD` di `.prod.env`: nel pacchetto le due coincidevano.
6. **Log senza limite.** Aggiunto `json-file` con `max-size: 50m` e `max-file: 3` a tutti i servizi: a ottobre 2026 i log dei container hanno riempito i dischi di dharch e dhlake.
7. **Configurazione dell'applicazione.** `MERGIN_BASE_URL` da `mergin.webparc.it` a `mergin.dh.unica.it`; `CONTACT_EMAIL` da `admin@faunalia.it` a `dh@unica.it`; `GLOBAL_STORAGE` da 10 a 30 GiB, perché 6,4 GB erano già occupati e il gruppo PARC prevede di caricare immagini e planimetrie.

8. **Il database applicativo è `postgres`, non `mergin`.** `.prod.env` non imposta `DB_DATABASE` né `DB_USER`, quindi il backend usa i predefiniti (`postgres`/`postgres`). Il database `mergin`, creato da `POSTGRES_DB` alla prima inizializzazione, è vuoto. Script di verifica e backup leggono il nome da `.prod.env` con `postgres` come predefinito. Al ripristino del 1/11/2026: 2 utenti, 15 progetti (compresi quelli cancellati, che Mergin rinomina con un suffisso UUID), 151 versioni, schema alembic `35af0c8be41e` e `b9ec9ab6694f`.

## Procedura

### Preparazione di dhgeo

Comune a Lizmap: Docker 24.0.2 con il plugin compose v2 (vedi `Dh-unica/lizmap.dh.unica.it`, docs/MIGRAZIONE.md).

### Ripristino

```bash
cd ~ && git clone git@github.com-mergin:Dh-unica/mergin.dh.unica.it.git   # deploy key in sola lettura
cd ~/mergin.dh.unica.it
scripts/ripristina-export.sh ~/archivi-faunalia/mergin_export_20261027.tar.gz
docker compose pull
scripts/verifica-db.sh            # se il log del recovery riporta errori: fermarsi
docker compose up -d
scripts/smoke-test.sh
```

Verifica dal proprio PC con un tunnel: `ssh -L 8086:127.0.0.1:8086 dhgeo@90.147.144.148`, poi `http://localhost:8086`: login, elenco dei progetti, storico delle versioni, download di un progetto.

Se `verifica-db.sh` trova errori: `docker compose down`, rinominare `mergin_db` in `mergin_db.failed-<data>`, creare un database vuoto e ripristinare il `pg_dump` di Faunalia.

### Pubblicazione

1. **DNS**: record A `mergin.dh.unica.it` → `90.147.144.144`, con ticket a [helpdesk.unica.it](https://helpdesk.unica.it/servicePortal).
2. **Proxy**: virtual host `mergin_dhunica.conf` in `proxy.dh.unica`, con il certificato wildcard, verso `90.147.144.148:8086`, `client_max_body_size 4G`, `proxy_read_timeout 900s`, buffering delle richieste disattivato.
3. **Firewall e porta**: regole `DOCKER-USER` (coprono 8084–8087, vedi il repository Lizmap), poi in `.env` `MERGIN_PORT=90.147.144.148:8086` e `docker compose up -d proxy`.

### Comunicazione agli utenti

Chi usa l'app o il plugin deve sostituire `mergin.webparc.it` con `https://mergin.dh.unica.it`. Prima del cambio è bene che ognuno verifichi di non avere modifiche locali non sincronizzate: dopo il cambio di server l'app può chiedere di scaricare di nuovo i progetti. Va provato con un telefono prima di avvisare tutto il gruppo.

## Verifiche di accettazione

- [ ] `scripts/verifica-db.sh`: recovery concluso, dump completo senza errori
- [ ] `scripts/smoke-test.sh` tutto OK
- [ ] login web, progetti e storico visibili; download di un progetto e di una versione precedente
- [ ] app Mergin Maps su un telefono: sincronizzazione con download e upload di una modifica
- [ ] plugin Mergin di QGIS: sincronizzazione dello stesso progetto
- [ ] `scripts/backup.sh` produce dump e istantanea; restore di prova del dump in un container temporaneo

## Rollback

Gli archivi originali restano in `/home/dhgeo/archivi-faunalia/` con le checksum (`SHA256SUMS`). Per ripartire: `docker compose down`, spostare `mergin_db/`, `projects/`, `diagnostic_logs/`, `.prod.env` e `.env` in una cartella `*.failed-<data>` e rilanciare `scripts/ripristina-export.sh`.
