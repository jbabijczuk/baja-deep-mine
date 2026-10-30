# Prototyp kopalni 2D (DM-120, Issue #8)

Pionowy wycinek: górnik chodzi w 4 kierunkach po siatce, szuka rzadkich żył po śladach w skale, kopie, nosi bryłki w małym plecaku, unika głazów i wynosi łup windą (wielokrotnie w rundzie) przed zawaleniem.

## Uruchomienie (Godot 4.7.2)

- Edytor: otwórz projekt, `F6` na `scenes/MinePrototype.tscn`, albo `F5` → przycisk **NOWA KOPALNIA — PROTOTYP** w bazie. Przycisk **BAZA** wraca do starej bazy (zapis bazy jest zapisywany przed przejściem).
- Z linii poleceń: `Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/MinePrototype.tscn`.
- Sterowanie: WASD / strzałki albo dotykowy krzyżak w prawym dolnym rogu. Wejście w materiał kopie go, wejście do klatki windy wynosi łup na powierzchnię. **DEBUG: KONIEC RUNDY** przestawia zegar na 0:10 przed zawaleniem.

## Zasady prototypu (po korekcie DM-121, Issue #10)

- Mapa 48×64 z seeda (`data/mine_prototype.json`), szyb z windą przy kolumnie 14, 3 lampy przy stacji, komora startowa i korytarz zawsze otwarte.
- Teren to głównie ziemia i kamień; rudy rosną w nieregularnych żyłach 2–8 sąsiednich komórek (`veins`). Wokół żył część skał ma przebarwienia i odłamki rudy (`hints`) — ślad do szukania, nie mapa. Złoto tylko w rzadkich, głębszych żyłach.
- HP: ziemia 1, węgiel 4, kamień 6, miedź 7, złoto 13; uderzenie co 0,38 s. Każde uderzenie: błysk, odpryski, pęknięcia w 4 etapach, pasek HP bloku.
- Jeden rozbity blok rudy = 1 bryłka. Plecak: 3 sloty (HUD `PLECAK 0/3` + ikony). Gdy plecak pełny, bryłka zostaje na mapie do podniesienia (wejście na pole). **Q / WYRZUĆ TAŃSZY** zostawia najtańszą bryłkę na ziemi. Masa liczona osobno: od 8 kg górnik zwalnia ×1,6.
- Spadający głaz ogłusza na 3,8 s (gwiazdki, chwianie, licznik nad głową). Z pełnego plecaka wypada połowa bryłek (w górę zaokrąglając) na sąsiednie wolne pola; pusty plecak = tylko ogłuszenie. Przez 2,5 s po ogłuszeniu kolejny głaz tylko się odbija (brak re-stunu). Łup przygnieciony głazem przesuwa się na pole, z którego głaz zszedł.
- Winda: wyniesiony łup trafia do skarbca; na powierzchni można od razu zjechać ponownie w tej samej rundzie (zegar 4:40 się nie resetuje). Po końcu fazy aktywnej zjazd jest zablokowany do końca przerwy 0:20. Zawalenie zabiera tylko łup w plecaku i na ziemi.
- Ulepszenia (na powierzchni, za skarbiec): Hartowany kilof 25 zł (siła 1→2, np. złoto 13→7 uderzeń) i Plecak 4 sloty 50 zł (≈2–4 dostawy po 3 bryłki węgla/miedzi). Zakup sprawdza saldo przed przyznaniem.
- Postęp prototypu (skarbiec, poziom kilofa i plecaka) zapisuje się w `user://mine_prototype_progress.json` po każdej dostawie i zakupie; plecak w trakcie kursu nie jest zapisywany (brak duplikacji). Uszkodzony lub obcy zapis = start od zera. Zapis starej bazy (`user://save_v12.json`) nie jest dotykany.

## Przed / po (DM-121)

| Parametr | Przed (PR #9) | Po |
|---|---|---|
| HP ziemia / węgiel / kamień / miedź / złoto | 1 / 2 / 3 / 3 / 5 | 1 / 4 / 6 / 7 / 13 (kilof 2: 1 / 2 / 3 / 4 / 7) |
| Tempo kopania | 0,22 s | 0,38 s |
| Ogłuszenie | 1,6 s, bez konsekwencji | 3,8 s + wypada ½ plecaka, 2,5 s ochrony |
| Plecak | 40 kg | 3 sloty (→4 za 50 zł), masa osobno (≥8 kg wolniej) |
| Rudy w płytkiej części | ~20% komórek, losowo | 4,0–7,3% (śr. 5,4%, 30–40 seedów), żyły 2–8 |
| Drop | 1–3 jednostki, nadmiar kasowany | 1 bryłka/blok, nadmiar zostaje na mapie |
## Architektura

| Plik | Rola |
|---|---|
| `data/mine_prototype.json` | balans: mapa, żyły i wskazówki, HP, sloty, masa, ogłuszenie, ulepszenia, czasy rundy |
| `scripts/mine_prototype/mine_model.gd` | czysta logika (bez węzłów): generowanie, kopanie, ruch, głazy, winda, zegar |
| `scripts/mine_prototype/mine_art.gd` | proceduralne tekstury pixel art (32×32, skala 2) i klatki górnika |
| `scripts/mine_prototype/mine_world.gd` | rysowanie tylko widocznych komórek, obrysy tuneli, cienie, pęknięcia |
| `scripts/mine_prototype/surface_backdrop.gd` | niebo, wzgórza, wieża wyciągowa, budynek |
| `scripts/mine_prototype/mine_prototype.gd` | sterowanie, kamera, światła (`CanvasModulate` + `PointLight2D`), efekty, HUD |

## Weryfikacja

- `bash tests/run_tests.sh <Godot 4.7.2 console>` uruchamia też `tests/test_mine_prototype.gd` (19 testów, 121 asercji; m.in. generator na 30 seedach: odsetek rud, skupienie w żyłach, rzadkość złota, wskazówki przy starcie; HP i ulepszenie kilofa; sloty i masa; nadmiar na mapie i odzysk; ogłuszenie, wypadanie łupu, odporność na re-stun; wiele dostaw w jednej rundzie; ulepszenia między rundami; zapis/odczyt postępu i odporność na uszkodzony zapis; HUD 0/3).
- Screenshoty z prawdziwego renderera (OpenGL 3.3, GTX 1660 Ti) w `docs/screenshots/dm-121/` (start z HUD 0/3, wskazówki, postęp kopania, pierwsza ruda, pełny plecak z bryłką na ziemi, ogłuszenie, przegląd żył z rozjaśnioną mapą — tylko do dokumentacji, powierzchnia z ulepszeniami) generuje `Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/capture_prototype.gd` (bez `--headless`). Skrypt wywołuje te same akcje co klawisze; zawartość plecaka w scenach „pełny plecak”, „ogłuszenie” i „powierzchnia” jest ustawiana skryptem, renderuje `SubViewport` 720×1280 do PNG.
- Weryfikacja interaktywna: sceny `MinePrototype.tscn` i `Main.tscn` uruchomione w oknie bez błędów; ręczne granie klawiaturą i dotykiem **nie zostało wykonane przez agenta** — wymaga oceny właściciela.

## Pochodzenie i licencja assetów

Wszystkie grafiki są autorskie, generowane w kodzie (`mine_art.gd`, `surface_backdrop.gd`) w czasie uruchomienia; brak plików z zewnątrz i z innych gier. Proponowana licencja: CC0 1.0 (decyzja właściciela repozytorium). Czcionka: domyślna czcionka wbudowana w Godot, dostarczana z silnikiem.
