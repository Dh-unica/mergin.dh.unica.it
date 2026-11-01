# mergin.dh.unica.it: istruzioni per Claude Code

Configurazione di produzione e strumenti di manutenzione di mergin.dh.unica.it, il server Mergin Maps Community Edition del Centro DH UNICA (primi progetti: gruppo PARC).

**All'inizio di ogni sessione leggi [PROSSIMI-PASSI.md](PROSSIMI-PASSI.md)**: contiene lo stato attuale e cosa manca. A fine lavoro aggiornalo.

## Contesto

- Produzione su **dhgeo** `90.147.144.148`, utente `dhgeo`. SSH: `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_rsa dhgeo@90.147.144.148`. La password per sudo non sta nel repository.
- Stack in `/home/dhgeo/mergin.dh.unica.it` (clone di questo repository più `mergin_db/`, `projects/`, `.prod.env` e `.env` non versionati), Docker Compose v2.
- Sulla stessa VM gira Lizmap (`/home/dhgeo/lizmap.dh.unica.it`, repository `Dh-unica/lizmap.dh.unica.it`).
- Pubblicazione tramite il reverse proxy di dhwp (`proxy.dh.unica`, branch `master`: **un push su master va in produzione via cron entro un minuto**).
- Migrazione da Faunalia: [docs/MIGRAZIONE.md](docs/MIGRAZIONE.md). Archivi originali in `/home/dhgeo/archivi-faunalia/`.

## Regole

- **Nessuna modifica alla produzione senza un ok esplicito.** Le letture vanno bene.
- Prima di ogni intervento: `scripts/backup.sh`; dopo: `scripts/smoke-test.sh`.
- Comandi vietati: `docker compose down -v`, `docker system prune`, `docker volume prune`, `rm` su `mergin_db/` o `projects/`, `flask init-db`, `DROP DATABASE` (si usa `ALTER DATABASE … RENAME`), estrazioni con `tar` senza `--numeric-owner`.
- **`SECURITY_PASSWORD_SALT` non si cambia mai**: invaliderebbe le password di tutti gli utenti. `SECRET_KEY` e gli altri salt solo con un motivo, sapendo che chiudono le sessioni attive.
- I tag delle immagini (`2025.7.3`) e di `postgres:14` cambiano solo con un piano di aggiornamento: migrazioni dello schema per il backend, dump e restore per PostgreSQL.
- Uid e gid sono numerici e fissi (999, 901:999, 101:999): su dhgeo il gid 999 è il gruppo `docker` e `systemd-journal` è 101, quindi mai `chown` per nome.
- La porta 8086 si apre verso l'esterno solo con le regole `DOCKER-USER` attive (docs/MIGRAZIONE.md): Docker scavalca `ufw`.
- Mai stream da `docker run` senza `--log-driver none`: lo stdout finisce nel log del container sul disco.
- Git: mai commit su `main`. Un branch per attività (`feat/`, `fix/`, `docs/`, `chore/`, `refactor/`), commit in italiano, poi PR, merge e cancellazione del branch. `main` è protetto su GitHub: si arriva solo da PR con il check «regole» verde. Tag `prod-<data>` per ogni rilascio in produzione. Hook locale: `git config core.hooksPath .githooks`.
- Mai segreti né dati nel repo: `.prod.env` e `.env` non sono versionati, `.prod.env.example` ha i valori oscurati.
- Su dhgeo il repository si aggiorna solo con `git pull` (deploy key in sola lettura): lì non si fanno commit.
