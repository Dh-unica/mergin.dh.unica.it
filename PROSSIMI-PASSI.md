# Prossimi passi

Stato al 1/11/2026. Lo stack gira su dhgeo con la porta solo su 127.0.0.1, in attesa di DNS e proxy.

## Fatto

- [x] Analisi dell'export Faunalia del 27/10/2026 e correzioni al deployment (docs/MIGRAZIONE.md)
- [x] Scelta della VM: dhgeo, insieme a Lizmap
- [x] Archivi copiati su dhgeo in `~/archivi-faunalia/`, checksum verificate
- [x] Docker su dhgeo aggiornato da 18.09 a 24.0.2 con il plugin compose 2.18.1
- [x] Repository clonato su dhgeo con deploy key in sola lettura (`~/.ssh/deploy_mergin`, alias `github.com-mergin`)
- [x] Ripristino dall'export: permessi corretti (999:0 700 su `mergin_db`, 901:999 2750 su `projects`)
- [x] `scripts/verifica-db.sh --amcheck`: recovery concluso, dump completo, 70 indici btree verificati. Nel database `postgres`: 2 utenti, 15 progetti, 151 versioni
- [x] Stack avviato: `/ping` e `/config` rispondono (CE), interfaccia web raggiungibile da tunnel
- [x] Backup provato: dump di 148 KB (16 tabelle con dati) e istantanea dei progetti di 6,3 GB, con la manutenzione attiva durante la copia (verificato: i push ricevono 503)

## Da fare

- [ ] Verifica via tunnel SSH con un account: login, progetti, storico, download (le credenziali sono da chiedere a Faunalia)
- [ ] `pg_dump` di riserva da Faunalia (da chiedere: il DB ripristinato è già risultato coerente)
- [ ] Ticket DNS per `mergin.dh.unica.it` → 90.147.144.144
- [ ] Firewall `DOCKER-USER` e porta sull'IP di dhgeo
- [ ] Virtual host nel proxy (PR su `proxy.dh.unica`, da unire solo a DNS attivo)
- [ ] Prova con un telefono e con il plugin QGIS, poi avviso agli utenti del nuovo indirizzo
- [ ] Backup giornaliero in cron e copia fuori dalla VM
- [ ] Tag `prod-<data>` sul primo rilascio

## Dopo la messa in servizio

- [ ] **PostgreSQL 14 → 16 o 17**: la 14 esce dal supporto il 12/11/2026 (dump e restore)
- [ ] Mergin Maps 2025.7.3 → ultima 2026.x, seguendo le note di rilascio e le migrazioni del DB
- [ ] SMTP d'ateneo, per abilitare il reset password da parte degli utenti
