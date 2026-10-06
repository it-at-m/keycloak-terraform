# Zertifikatswechsel Checkliste

## 📋 Vorbereitung

- [ ] Neues PKI-Zertifikat von interner CA erhalten
- [ ] Private Key sicher gespeichert (GitLab CI/CD Variable oder Vault)
- [ ] Ablaufdatum des alten Zertifikats notiert: `__________`
- [ ] Liste aller SAML-Clients erstellt (siehe unten)
- [ ] Zeitfenster für Migration geplant: `__________`
- [ ] Rollback-Plan dokumentiert

## 🔧 Phase 1: Neues Zertifikat hinzufügen (DEV/TEST)

- [ ] Zertifikat als GitLab CI/CD Variable hinzugefügt
  - Variable: `REALM_NEW_CERT_<ENV>`
  - Variable: `REALM_NEW_KEY_<ENV>`
- [ ] Terraform Konfiguration aktualisiert (beide Certs)
- [ ] `terraform plan` durchgeführt (DEV)
- [ ] `terraform apply` durchgeführt (DEV)
- [ ] Keycloak Admin Console geprüft:
  - [ ] Beide Certs unter Realm Settings → Keys sichtbar
  - [ ] Neues Cert hat höhere Priority (z.B. 200)
  - [ ] Altes Cert hat niedrigere Priority (z.B. 100)
  - [ ] Beide Certs sind "Active"
- [ ] SAML Metadata geprüft:
  ```bash
  curl https://keycloak-dev/realms/{realm}/protocol/saml/descriptor | grep X509Certificate
  ```
  - [ ] Zwei unterschiedliche Zertifikate im Metadata

## 🧪 Phase 2: Test-Client Migration

- [ ] Test-SAML-Client identifiziert: `__________`
- [ ] SAML Metadata URL an Test-Client Team gesendet
- [ ] Test-Client konfiguriert mit neuem Cert
- [ ] SAML-Login getestet:
  - [ ] Login erfolgreich
  - [ ] Token-Validierung erfolgreich
  - [ ] Keine Certificate-Errors in Logs
- [ ] Bei Problemen: Rollback durchgeführt?
  - [ ] Nein, alles OK ✅
  - [ ] Ja, Problem: `__________`

## 🚀 Phase 3: PREDEV/TEST Environment

- [ ] Terraform in PREDEV deployed
- [ ] Alle Test-Clients migriert
- [ ] Monitoring eingerichtet:
  - [ ] Keycloak Logs überwacht (1 Woche)
  - [ ] Keine SAML-Certificate-Errors
- [ ] Bewährungsphase abgeschlossen (min. 1 Woche)

## 📊 Phase 4: SAML-Client Migration (PROD)

### Client Liste:

| Client Name | Team | Status | Migriert am | Notizen |
|-------------|------|--------|-------------|---------|
| App 1       | Team A | ⏳ Pending | | |
| App 2       | Team B | ⏳ Pending | | |
| App 3       | Team C | ⏳ Pending | | |

**Status-Legende:**
- ⏳ Pending = Noch nicht begonnen
- 🔄 In Progress = Migration läuft
- ✅ Done = Erfolgreich migriert
- ❌ Blocked = Problem, siehe Notizen

### Migration pro Client:

Für jeden Client:

1. [ ] SAML Metadata URL gesendet
2. [ ] Client-Team hat Update bestätigt
3. [ ] Test der SAML-Authentifizierung durchgeführt
4. [ ] Monitoring: Keine Errors (24h)
5. [ ] Status auf ✅ Done gesetzt

## 🎯 Phase 5: Production Deployment

- [ ] Alle Test-Environments erfolgreich
- [ ] Alle SAML-Clients bereit (siehe Tabelle oben)
- [ ] Wartungsfenster vereinbart (falls nötig): `__________`
- [ ] Terraform in PROD deployed:
  ```bash
  terraform plan -var-file=prod.tfvars
  terraform apply -var-file=prod.tfvars
  ```
- [ ] Keycloak Admin Console geprüft (PROD)
- [ ] SAML Metadata geprüft (PROD)
- [ ] Monitoring aktiv (nächste 2-4 Wochen)

## 🔄 Phase 6: Altes Zertifikat deaktivieren

**Warten Sie mindestens 2-4 Wochen nach Production-Deployment!**

- [ ] Kein SAML-Client nutzt noch altes Cert (Logs geprüft)
- [ ] Alle Clients in Tabelle haben Status ✅ Done
- [ ] Bewährungsphase abgeschlossen: `__________`
- [ ] Terraform aktualisiert (altes Cert: enabled=false, priority=0)
- [ ] `terraform apply` durchgeführt
- [ ] Monitoring: Keine neuen Errors (1 Woche)

## 🧹 Phase 7: Cleanup

**Weitere 2-4 Wochen warten!**

- [ ] Kein Incident seit Deaktivierung
- [ ] Altes Cert aus Terraform Config entfernt
- [ ] State manuell bereinigt:
  ```bash
  terraform state rm 'module.realm_keys.keycloak_realm_keystore_rsa.realm_key["realm-old"]'
  ```
- [ ] `terraform apply` durchgeführt
- [ ] Backup des alten Certs extern gespeichert (für Notfälle)
- [ ] Dokumentation aktualisiert

## 🚨 Rollback-Plan

Falls Probleme auftreten:

1. **Sofort-Rollback (beide Certs noch aktiv):**
   - [ ] Altes Cert wieder auf höhere Priority setzen (z.B. 200)
   - [ ] Neues Cert auf niedrigere Priority (z.B. 100)
   - [ ] `terraform apply`
   - [ ] Problem analysieren

2. **Rollback nach Deaktivierung:**
   - [ ] Altes Cert wieder aktivieren: `enabled=true, priority=200`
   - [ ] `terraform apply`
   - [ ] Alle Clients informieren

3. **Rollback-Zeitfenster:**
   - Phase 1-4: Sofortiges Rollback möglich
   - Phase 5-6: Rollback mit Koordination
   - Nach Phase 7: Rollback schwierig (Backup-Cert nutzen)

## 📝 Lessons Learned

Nach Abschluss:

- [ ] Was lief gut? `__________`
- [ ] Was lief nicht gut? `__________`
- [ ] Verbesserungen für nächsten Wechsel? `__________`
- [ ] Dokumentation aktualisiert

## 🔗 Referenzen

- GitLab CI/CD Variables: `https://git.muenchen.de/your-project/-/settings/ci_cd`
- Keycloak Admin Console: `https://keycloak.example.com/admin`
- SAML Metadata URL: `https://keycloak.example.com/realms/{realm}/protocol/saml/descriptor`
- Terraform Docs: `Terraform/modules/realm-keys/README.md`

## 📞 Kontakte

- PKI Team: `__________`
- Keycloak Admin: `__________`
- Notfall-Hotline: `__________`
