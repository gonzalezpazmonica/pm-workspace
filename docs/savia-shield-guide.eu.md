# Savia Shield Gida — Datuen babesa egunerokoan

> Erabilera praktikoa. Arkitektura teknikorako: [docs/savia-shield.md](savia-shield.md)

## Zer da Savia Shield

Savia Shield-ek bezeroaren proiektuen datu konfidentzialak (N4/N4b maila) repositorioko fitxategi publikoetara (N1 maila) filtratzea ekiditen du. 5 geruza independenterekin funtzionatzen du, bakoitza auditagarria. Desaktibatuta dago lehenespenez eta bezeroen datuekin lanean hasten zarenean aktibatzen da.

## 4 hook profilak

Profilek kontrolatzen dute zein hook exekutatzen diren. Profil bakoitzak aurrekoa barne hartzen du:

| Profila | Hook aktiboak | Erabilera kasua |
|---------|--------------|-----------------|
| `minimal` | Segurtasun blokeatzaileak bakarrik (kredentzialak, force-push, infra suntsitzailea, subiranotasuna) | Demoak, onboarding, debugging |
| `standard` | Segurtasuna + kalitatea (bash baliozkotzea, plan gate, TDD, scope guard, compliance) | Eguneroko lana (gomendatua) |
| `strict` | Standard + dispatch baliozkotzea, gelditzean quality gate, konpetentzia jarraipena | Release aurretik, kode kritikoa |
| `ci` | standard bezala baina interaktibitaterik gabe | Pipeline automatikoak, script-ak |

```bash
bash scripts/hook-profile.sh get           # Profil aktiboa ikusi
bash scripts/hook-profile.sh set standard  # Aldatu (saioen artean irauten du)
export SAVIA_HOOK_PROFILE=ci               # Edo ingurune-aldagaiarekin
```

Profil GUZTIETAN exekutatzen diren segurtasun hook-ak: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `data-sovereignty-gate.sh`.

---

## 5 babes geruzak

**Geruza 0 — API Proxy-a**: Anthropic-era irteten diren prompt-ak atzematen ditu. Entitateak automatikoki ezkutatzen ditu. Aktibatu honekin: `export ANTHROPIC_BASE_URL=http://127.0.0.1:8443`.

**Geruza 1 — Gate deterministikoa** (< 2s): PreToolUse hook-a, fitxategi publikoetan idatzi aurretik edukia eskaneatzen duena. Regex kredentzialentzat, IPentzat, tokenentzat. NFKC eta base64 barne.

**Geruza 2 — LLM-arekin sailkapen lokala**: Ollama qwen2.5:7b-k testua semantikoki sailkatzen du CONFIDENTIAL edo PUBLIC gisa. Datuak ez dira inoiz localhost-etik irteten. Ollama gabe, Geruza 1 bakarrik funtzionatzen du.

**Geruza 3 — Post-idazketa auditoria**: Hook asinkronoa fitxategi osoa berriz eskaneatzen duena. Ez du blokeatzen. Berehalako alerta filtrazioa detektatzen badu.

**Geruza 4 — Masking itzulgarria**: Entitate errealak fiktizioez ordezkatzen ditu cloud APIetara bidali aurretik. Mapa lokala (N4, inoiz ez git-en).

```bash
bash scripts/sovereignty-mask.sh mask "datu errealekin testua" --project nire-proiektua
bash scripts/sovereignty-mask.sh unmask "Claude-ren erantzuna"
```

---

## Aktibatu eta desaktibatu

```bash
/savia-shield enable    # Aktibatu
/savia-shield disable   # Desaktibatu
/savia-shield status    # Egoera eta instalazioa ikusi
```

Edo `.claude/settings.local.json` editatuz:

```json
{ "env": { "SAVIA_SHIELD_ENABLED": "true" } }
```

## Proiektu bakoitzeko konfigurazioa

Proiektu bakoitzak entitate sentikorrak defini ditzake hemen:

- `projects/{izena}/GLOSSARY.md` — domeinu terminoak
- `projects/{izena}/GLOSSARY-MASK.md` — masking-erako entitateak
- `projects/{izena}/team/TEAM.md` — stakeholder-en izenak

Shield-ek fitxategi hauek automatikoki kargatzen ditu proiektuan lan egitean.

## Instalazio osoa (aukerakoa)

5 geruza guztietarako proxy eta NER barne:

```bash
bash scripts/savia-shield-setup.sh
export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
```

Baldintzak: Python 3.12+, Ollama, jq, gutxienez 8GB RAM. Instalazio osorik gabe: 1 eta 3 geruzak (regex + auditoria) beti funtzionatzen dute.

## 5 konfidentzialtasun mailak

| Maila | Nork ikusten du | Adibidea |
|-------|----------------|---------|
| N1 Publikoa | Internet | Workspace-aren kodea |
| N2 Enpresa | Erakundea | Org-aren konfigurazioa |
| N3 Erabiltzailea | Zuk bakarrik | Zure profila |
| N4 Proiektua | Proiektu taldea | Bezeroaren datuak |
| N4b PM bakarrik | PMk bakarrik | Banakako elkarrizketak |

Shield-ek **N4/N4b-tik N1-era** mugak babesten ditu. Kokapen pribatuetan idaztea beti baimenduta dago.

> Arkitektura osoa: [docs/savia-shield.md](savia-shield.md) | Testak: `bats tests/test-data-sovereignty.bats`
