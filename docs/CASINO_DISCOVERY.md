# CASINO DISCOVERY — Phase 1 (asset audit) — COMPLETE

**Status:** Discovery COMPLETE. Probe v2 rulate de Horia, output citit din `docker logs` (1159 linii).
**Interior ID:** 275201 (confirmat la toate cele 5 ancore + ped entity).
**Build:** 3751 (mp2025_02).

---

## 1. Verified assets (from probe output)

### Interior ID — VERIFIED
| Anchor | Coords | Interior ID | Ready |
|---|---|---|---|
| ped (player) | (1111.07, 228.45, -49.64) | **275201** | true |
| interiorExit | (1089.63, 205.89, -49.00) | **275201** | true |
| bar | (1108.45, 208.87, -49.44) | **275201** | true |
| cashier | (1116.03, 219.69, -49.44) | **275201** | true |
| floorCenter | (1110.20, 216.60, -49.45) | **275201** | true |

**Toate cele 5 ancore rezolvă la același interior ID = 275201.** Acesta este ID-ul verificat al cazinoului main floor.

### IPLs — VERIFIED (bob74_ipl source + auto-load at build 3751)
| IPL | Purpose | Status |
|---|---|---|
| `hei_dlc_windows_casino` | exterior windows | loaded by bob74 |
| `hei_dlc_casino_aircon` | exterior aircon | loaded by bob74 |
| `vw_dlc_casino_door` | casino doors | loaded by bob74 |
| `hei_dlc_casino_door` | casino doors | loaded by bob74 |
| `vw_casino_main` | **MAIN FLOOR interior** | loaded by bob74 |
| `vw_casino_garage` | garage/vault | loaded by bob74 |
| `vw_casino_carpark` | carpark | loaded by bob74 |
| `vw_casino_penthouse` | penthouse (separate interior 274689) | loaded by bob74 |

### Entity Sets — ALL 36 CANDIDATES = active=false
Probe v2 a testat 36 nume candidate de entity sets pe interiorId=275201. **Toate au returnat `active=false`.**

Asta înseamnă una din două:
1. **Numele candidate sunt greșite** — interior-ul main floor are entity sets cu nume complet diferite de convenția `Set_*` folosită de penthouse.
2. **Interior-ul main floor NU are entity sets configurabile** — props-urile sunt baked direct în IPL (nu pot fi activate/dezactivate runtime).

**Concluzie:** Spre deosebire de penthouse (care are `Set_Pent_*` entity sets documentate în bob74_ipl), **vw_casino_main nu expune entity sets prin bob74_ipl**. Props-urile de slot machines, mese, scaune sunt **baked în IPL** și apar direct în lume fără activare.

### Props VERIFIED — există în interior (din entity scan)
| Prop | Hash | Count | First Position | Notes |
|---|---|---|---|---|
| `vw_prop_casino_slot_01a` | -1932041857 | 5 | (1114.12, 235.08, -50.84) | Slot machines — baked în IPL |
| `vw_prop_casino_stool_02a` | -2139482741 | 3 | (1117.67, 218.64, -50.44) | Scaune bar |
| `vw_prop_casino_chair_01a` | -1195678770 | 12 | (1111.55, 211.61, -50.44) | Scaune mese |

### Props VERIFIED — valide pe build 3751 (IsModelValid=true, IsModelInCdimage=true)
| Prop | Notes |
|---|---|
| `vw_prop_casino_slot_01a` | Slot machine (confirmat și în scan) |
| `vw_prop_vw_table_01a` | Masă generică |
| `vw_prop_vw_table_casino_short_01` | Masă cazino scurtă |
| `vw_prop_vw_table_casino_short_02` | Masă cazino scurtă |
| `vw_prop_vw_table_casino_tall_01` | Masă cazino înaltă |
| `vw_prop_casino_roulette_01` | Masă roulette |
| `vw_prop_casino_roulette_01b` | Masă roulette (variantă) |
| `vw_prop_roulette_ball` | Bila roulette |
| `vw_prop_roulette_marker` | Marker roulette |
| `vw_prop_casino_stool_02a` | Scaun (confirmat și în scan) |
| `vw_prop_casino_chair_01a` | Scaun (confirmat și în scan) |
| `vw_prop_vw_chip_carrier_01a` | Suport chips |

### Props care NU există pe build 3751 (valid=false, incdimage=false)
| Prop | Notes |
|---|---|
| `vw_prop_vw_slot_01a` .. `vw_prop_vw_slot_08a` | Toate lipsesc |
| `prop_vw_slot_01` .. `prop_vw_slot_03` | Toate lipsesc |
| `prop_casino_slot_01` | Lipsește |
| `vw_prop_vw_lucky_wheel_01a` | **Lipsește** |
| `vw_prop_vw_lucky_wheel_02a` | **Lipsește** |
| `vw_prop_vw_luckywheel` | **Lipsește** |
| `prop_vw_lucky_wheel` | **Lipsește** |
| `vw_prop_vw_card_club_01a` | Lipsește |
| `vw_prop_casino_card_01` | Lipsește |
| `vw_prop_cas_calc_roulette_01` | Lipsește |
| `vw_prop_casino_stool_01a` | Lipsește |
| `vw_prop_casino_chair_02a`, `03a` | Lipsesc |
| `prop_casino_chair_01`, `01b`, `02` | Lipsesc |
| `vw_prop_chip_01a` .. `vw_prop_chip_05a` | Lipsesc |
| `vw_prop_vw_barstool_01a` | Lipsește |
| `vw_prop_vw_bar_01a` | Lipsește |
| `vw_prop_vw_tv_video_01a` | Lipsește |
| `vw_prop_vw_screen_tv_01a` | Lipsește |

### Animation Dicts — TOATE LIPSESC pe build 3751
| Dict | Status |
|---|---|
| `anim_casino_poker@*` | missing |
| `anim_casino_blackjack@*` | missing |
| `anim_casino_roulette@*` | missing |
| `anim_casino_slots@*` | missing |
| `anim_casino_slot_machine@*` | missing |
| `anim_casino_lucky_wheel@*` | missing |
| `anim_casino@lucky7wheel@*` | missing |
| `mp_casino@lucky7wheel@*` | missing |
| `anim_casino_wof@*` | missing |
| `casino@slots@*` | missing |
| `amb@prop_human_slot_machine@*` | missing |
| `anim@mp_player_intmenu@key_fob@base` | missing |
| `anim@heists@money_grab@briefcase` | **AVAILABLE** (singurul disponibil) |

**Concluzie:** Pe build 3751, **niciun dicționar de animații de cazino nu este disponibil**. Toate animațiile de slot/blackjack/roulette/lucky wheel lipsesc. Va trebui să folosim animații generice (sit, interact) sau emote-uri existente.

---

## 2. Lucky Wheel — analiză detaliată

### Ce există la poziția roții (~1115, 248, -45)
Entity scan-ul a găsit entități cu următoarele hash-uri UNMATCHED la poziția roții:

| Hash | Count | Position |
|---|---|---|
| -1711526423 | 1 | (1115.49, 248.23, -45.84) |
| -1525506599 | 1 | (1115.54, 248.98, -45.84) |
| -1551002089 | 1 | (1115.79, 247.64, -45.84) |
| -1296547421 | 6 | (1115.04, 249.30, -45.84) |
| -2065226472 | 2 | (1115.79, 248.63, -44.77) |
| -420103132 | 1 | (1115.83, 247.39, -45.25) |
| -1136258091 | 2 | (1115.83, 247.74, -45.25) |
| 674110876 | 1 | (1115.78, 248.70, -45.84) |

**Niciunul din aceste hash-uri nu se rezolvă** cu numele candidate testate (100+ nume de props vw/casino/wheel).

### Interpretare
1. **Rama/cadrul roții EXISTĂ** — entitățile de la poziția roții sunt props baked în IPL (parte din interior geometry).
2. **Discul cu premiile LIPSEȘTE** — nu există niciun prop de tip "wheel disc" sau "lucky wheel" valid pe build 3751.
3. **Nu este un entity set lipsă** — toate 36 entity set-uri candidate sunt inactive, dar asta e pentru că numele sunt greșite sau interior-ul nu are entity sets configurabile.

### Concluzie Lucky Wheel
**Nu putem identifica numele exact al prop-ului sau entity set-ului lipsă din probele actuale.** Avem nevoie de:
- O listă completă a entity set-urilor pentru `vw_casino_main` (nu există în bob74_ipl)
- Sau de numele reale ale props-urilor de la roată (hash-urile nu se rezolvă)

**Recomandare:** Pentru Lucky Wheel, va trebui să **emulăm discul cu premiile prin NUI overlay** sau prin rotirea unui prop existent. **NU spawna o roată completă duplicată** — rama există deja în interior.

---

## 3. Unknown/unavailable assets (rămân necunoscute)

| Item | Status | Motiv |
|---|---|---|
| Entity set-uri reale pentru `vw_casino_main` | **UNKNOWN** | bob74_ipl nu le documentează; 36 candidate testate = toate false |
| Numele props-urilor de la Lucky Wheel | **UNKNOWN** | Hash-urile nu se rezolvă cu 100+ nume candidate |
| Dicționare animații cazino | **UNAVAILABLE** | Toate lipsesc pe build 3751 |
| Props Lucky Wheel (disc, cadru separat) | **UNAVAILABLE** | Toate numele candidate lipsesc |
| Props chips individuale | **UNAVAILABLE** | `vw_prop_chip_01a..05a` lipsesc |
| Props bar | **UNAVAILABLE** | `vw_prop_vw_bar_01a`, `vw_prop_vw_barstool_01a` lipsesc |
| Props TV/screens | **UNAVAILABLE** | `vw_prop_vw_tv_video_01a`, `vw_prop_vw_screen_tv_01a` lipsesc |

---

## 4. Assets available for implementation

| Category | Available | Notes |
|---|---|---|
| Slot machines | `vw_prop_casino_slot_01a` (5 baked) | Există în interior, nu trebuie spawnate |
| Chairs | `vw_prop_casino_chair_01a` (12 baked) | Există în interior |
| Stools | `vw_prop_casino_stool_02a` (3 baked) | Există în interior |
| Roulette table | `vw_prop_casino_roulette_01`, `01b` | Valide, pot fi spawnate |
| Roulette ball/marker | `vw_prop_roulette_ball`, `vw_prop_roulette_marker` | Valide |
| Casino tables | `vw_prop_vw_table_casino_short_01/02`, `tall_01` | Valide |
| Chip carrier | `vw_prop_vw_chip_carrier_01a` | Valid |
| Generic table | `vw_prop_vw_table_01a` | Valid |
| Animations | `anim@heists@money_grab@briefcase` | Singurul disponibil |
| Interior ID | 275201 | Verificat |

---

## 5. Implementation plan (updated)

### Slots
- **Props:** Folosim cele 5 `vw_prop_casino_slot_01a` baked în interior (poziții din scan).
- **Animații:** Emulăm cu animații generice (sit/interact) sau NUI overlay pentru reels.
- **Flow:** Apropiere → interact → rezervare server-side → sit pe scaun → select bet → server deduct chips → server result → client anim → settle → stand up.

### Blackjack/Roulette
- **Props:** Mesele există baked în interior (chairs + tables). Roulette table poate fi spawnat (`vw_prop_casino_roulette_01`).
- **Animații:** Emulăm cu animații generice sau NUI overlay pentru cards/wheel.
- **Flow:** Apropiere → interact → join table → bet → server result → client anim → payout.

### Lucky Wheel
- **Rama:** Există baked în interior (entități la ~1115, 248, -45).
- **Discul:** **LIPSEȘTE** — va trebui emulat prin NUI overlay sau prop custom.
- **Flow:** Apropiere → interact → spin → server result → client anim (NUI wheel) → payout.

### Chips/Cashier
- **Props:** `vw_prop_vw_chip_carrier_01a` valid. Chips individuale lipsesc — emulăm prin NUI.
- **Flow:** Cashier interaction → convert cash ↔ chips → server-authoritative.

### Bar
- **Props:** Lipsesc (`vw_prop_vw_bar_01a` etc.) — folosim zona existentă + NUI menu.
- **Flow:** Apropiere → interact → buy drink → inventory.

### Exit
- **Coords:** (1089.63, 205.89, -49.00) — verificat.

---

## 6. Emulation ledger

| Feature | Native GTA Online? | Plan |
|---|---|---|
| Casino interior | YES (vw_casino_main, loaded) | native |
| Slot machines | YES (5 baked props) | native props; reels emulated via NUI |
| Blackjack tables | YES (chairs/tables baked) | native props; cards emulated via NUI |
| Roulette table | YES (valid props) | native props; wheel emulated via NUI |
| Lucky Wheel frame | YES (baked entities) | native frame; disc emulated via NUI |
| Lucky Wheel disc | NO (prop missing) | **emulated via NUI overlay** |
| Chips | PARTIAL (carrier valid, individual missing) | carrier native; chips emulated via NUI |
| Bar | NO (props missing) | emulated via NUI menu |
| Casino animations | NO (all dicts missing on 3751) | emulated via generic anims + NUI |
| Chip economy | N/A (server concept) | custom, server-authoritative |
