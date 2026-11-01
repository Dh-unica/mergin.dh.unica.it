# Prossimi passi

Stato al 1/11/2026.

## Fatto

- [x] Analisi dell'export Faunalia del 27/10/2026 e correzioni al deployment (docs/MIGRAZIONE.md)
- [x] Scelta della VM: dhgeo, insieme a Lizmap
- [x] Archivi copiati su dhgeo in `~/archivi-faunalia/`, checksum verificate

## Da fare

- [ ] Aggiornare Docker su dhgeo a 24.0.2 con il plugin compose v2
- [ ] Clonare il repository su dhgeo con una deploy key in sola lettura
- [ ] Ripristino dall'export, `scripts/verifica-db.sh`, avvio completo e `scripts/smoke-test.sh`
- [ ] Verifica via tunnel SSH: login, progetti, storico, download
- [ ] `pg_dump` di riserva da Faunalia (richiesto)
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
