# Prossimi passi

Stato al 2/11/2026. Lo stack gira su dhgeo con la porta solo su 127.0.0.1. Il DNS è attivo: mancano firewall, porta e merge del proxy.

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
- [x] DNS: `mergin.dh.unica.it` è un CNAME di `dh.unica.it` (90.147.144.144), attivo dal 2/11/2026
- [x] `pg_dumpall` di riserva da Faunalia (2/11/2026) in `~/archivi-faunalia/pgdump_mergin_unica_20261102.sql`, checksum in `SHA256SUMS`: 15 progetti e 151 versioni, l'ultima del 15/05/2026, come nel DB ripristinato. Dopo l'export non ci sono sincronizzazioni da recuperare
- [x] Credenziali amministrative ricevute da Faunalia il 2/11/2026 (fuori dal repository)

## Da fare

- [ ] Verifica via tunnel SSH con un account: login, progetti, storico, download; poi reset delle password
- [ ] Firewall dal repository Lizmap (`sudo scripts/firewall-dhgeo.sh installa`, copre anche la 8086), poi porta sull'IP di dhgeo e verifica da dhwp
- [ ] Merge della PR #25 di `proxy.dh.unica` (virtual host), solo dopo la verifica da dhwp
- [ ] Prova con un telefono e con il plugin QGIS, poi avviso agli utenti del nuovo indirizzo
- [ ] Backup giornaliero in cron e copia fuori dalla VM
- [ ] Tag `prod-<data>` sul primo rilascio
- [ ] Prima dello spegnimento del vecchio server (acceso fino a inizio dicembre 2026), conferma da Faunalia che l'ultima versione di progetto è ancora del 15/05/2026

## Dopo la messa in servizio

- [ ] **PostgreSQL 14 → 16 o 17**: la 14 esce dal supporto il 12/11/2026 (dump e restore)
- [ ] Mergin Maps 2025.7.3 → ultima 2026.x, seguendo le note di rilascio e le migrazioni del DB
- [ ] SMTP d'ateneo, per abilitare il reset password da parte degli utenti
