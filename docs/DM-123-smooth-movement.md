# DM-123 — płynny ruch górnika: diagnoza, pomiar, test RDP

## Wniosek

Szarpanie przy trzymaniu kierunku było błędem w Godot, niezależnym od RDP: na każdej granicy pola postać stała w miejscu przez jedną klatkę. Ruch przeszedł z osobnych Tweenów na jedną interpolację liczoną w `_process` z przeniesieniem nadwyżki czasu. Kamera i postać są teraz ustawiane na całe piksele. Balans się nie zmienił (`move_time=0.30`, `dig_interval=0.38`, ziemia 2 HP, kilof 2→1 uderzenie).

## Pomiar (Godot 4.7.2, okno, nie headless)

Środowisko: Windows 11, sesja lokalna `Console` (to nie RDP), GL Compatibility, NVIDIA GTX 1660 Ti, vsync 60 Hz. Scenariusz: 12 wolnych pól w prawo, kierunek przytrzymany, bez głazów. Każdy pomiar powtórzono 2–3 razy i wyniki się zgadzały.

| Metryka | Przed | Po |
|---|---|---|
| FPS Godot | 60 | 60 |
| Klatka: średnio / max | 16,67 / 17,2 ms | 16,67 / 16,9 ms |
| Czas 12 pól (oczekiwane 3,60 s) | 3,80–3,82 s | 3,62 s |
| Klatki bez ruchu przy trzymanym klawiszu | 11–12 (≈1 na pole) | 0 |
| Klatki z ruchem wstecz | 0 | 0 |
| Klatki z pozycją podpikselową | 192 z 228 | 0 |
| Skoki odległości postać–kamera > 2 px | 16–17 | 2 (start ruchu kamery) |
| Pozycja końcowa | dokładnie środek pola | dokładnie środek pola |

Czego nie zmierzono: FPS podczas kopania, kolizji z głazem, jazdy windą i z obciążeniem 8 kg (pomiar objął wyłącznie chodzenie); FPS na Androidzie; liczby klatek, które dociera przez RDP. Skrypt pomiarowy był jednorazowy i nie wszedł do repozytorium.

## Diagnoza — co sprawdzono

1. **Przerwa między polami (przyczyna potwierdzona pomiarem).** `busy` było obcinane do zera (`maxf(0, busy - delta)`), więc nadwyżka czasu z klatki przepadała. Do tego nowy Tween startował dopiero w następnej klatce. Efekt: na każdej granicy pola była jedna klatka postoju (16,7 ms co 300 ms, czyli rytmiczne „przeskakiwanie” 3,3 razy na sekundę) i 5% wolniejszy marsz.
2. **Tween bez trybu trans/ease.** Domyślny tryb jest liniowy, więc w obrębie jednego pola ruch był równy. Tween sam w sobie nie był winny; winne było łączenie kolejnych Tweenów.
3. **Kamera.** `camera.global_position = _camera_target()` odczytywało pozycję postaci przed krokiem Tweena w tej samej klatce (Tweeny są przetwarzane po `_process`). Wbudowane wygładzanie Camera2D liczy `speed * delta`, więc zależy od liczby klatek. W rezultacie odstęp postać–kamera skakał dokładnie w klatkach postoju.
4. **Subpiksele.** Postać (pixel art ×2, filtr nearest) i kamera miały pozycje ułamkowe w 84% klatek, co powoduje migotanie krawędzi tekseli.
5. **Shake/offset.** Działa tylko po kopaniu i uderzeniach. Przy samym chodzeniu wygasa po ≈0,1 s, więc nie wpływa na płynność marszu. Bez zmian.
6. **Klatki animacji walk.** Jeden cykl 4 klatek na pole (`_play_for`), kontynuowany bez restartu przy kolejnych polach. To celowy skok klatek pixel artu, a nie ruch postaci. Bez zmian.

## Co zmieniono

- `_move_player` zapisuje tylko `move_from`/`move_to`/`move_duration`. `_update_move` liczy pozycję z tego samego zegara `busy` i zaokrągla ją do pełnych pikseli. Kiedy ruch się kończy, postać stoi dokładnie w `_cell_center`. Na pozycji postaci podczas chodzenia nie działa już żaden Tween. Winda i zawalenie zostały na Tweenach, bo w tym czasie chodzenie jest zablokowane (`animating`); zawalenie dodatkowo przerywa trwający krok.
- Przy trzymanym kierunku następny krok startuje w tej samej klatce, w której kończy się poprzedni, a nadwyżka czasu przechodzi na nowy krok. Pierwszy krok po bezczynności startuje od zera.
- Kamera: wygładzanie wykładnicze `1 - exp(-7·delta)` (ta sama stała 7, ale niezależne od FPS), liczone po aktualizacji postaci w tej samej klatce, z pozycją zaokrągloną do pełnych pikseli. Wbudowane `position_smoothing` wyłączono, bo nie da się zaokrąglić jego wyniku ani ustalić jego kolejności względem ruchu.
- F3: nakładka diagnostyczna (FPS, średnia i maksymalna klatka z ostatnich 2 s, `move_time`, stan `moving/idle/dig/stun`), domyślnie ukryta, odświeżana co 0,5 s. Na Androidzie działa tylko w buildzie debug (`OS.is_debug_build()`).

## Wskazówki: lokalnie / RDP / Android

- **Lokalnie:** oczekiwane stałe 60 FPS i max klatki ≈17 ms. Jeśli F3 pokazuje max powyżej 25 ms, przyczyna leży w Godot lub w maszynie, nie w RDP.
- **RDP:** pulpit zdalny zwykle wysyła 15–30 klatek na sekundę i pomija klatki przy ruchu. Godot może renderować 60 FPS, a obraz zdalny i tak będzie się rwał. Ta zmiana nie naprawia RDP i nie twierdzi, że go naprawia.
- **Android:** F3 wymaga klawiatury i buildu debug. Na telefonie płynność należy ocenić gołym okiem, bo w tej rundzie nie sprawdzano jej przez ADB.

## Test porównawczy dla właściciela (5 minut)

1. Uruchom grę przez RDP, wejdź do kopalni, naciśnij **F3**. Przytrzymaj kierunek przez około 10 pól. Zanotuj FPS i max klatki widoczne na zdalnym ekranie.
2. Na maszynie z grą (lokalnie, nie przez RDP) nagraj ten sam marsz: **Win+Alt+R** (Xbox Game Bar), 60 FPS.
3. Porównaj nagranie lokalne z tym, co widać przez RDP. Jeśli nagranie jest płynne, a obraz RDP się rwie, to ogranicza transmisja. Jeśli rwie się również nagranie, a F3 pokazuje 60 FPS, zgłoś to z nagraniem jako błąd ruchu.

## Propozycja kolejnych poziomów kilofa (tylko tekst, bez implementacji)

Obecnie: ziemia 2 HP, kilof 1 → 2 uderzenia (0,76 s); kilof 2 (25 zł) → 1 uderzenie (0,38 s). Przyrost jest wyraźny, ale po pierwszym zakupie ziemi nie da się już przyspieszyć.

- **Wariant A (bez zmiany ziemi):** kolejne poziomy skracają kamień (6 HP): siła 3 → 2 uderzenia, siła 6 → 1. Ziemia zostaje na 1 uderzeniu od poziomu 2.
- **Wariant B (ziemia 3 HP):** siła 1 → 3 uderzenia (1,14 s), siła 2 → 2 (0,76 s), siła 3 → 1 (0,38 s). Daje trzy odczuwalne progi na ziemi, ale spowalnia start o 50%, a ten start właściciel dziś akceptuje. Wymaga zgody przed wdrożeniem.

## Testy automatyczne

`tests/test_mine_prototype.gd` zawiera nowe testy: 10 pól z przytrzymanym kierunkiem (czas = 10 × `move_time` z dokładnością do 2 klatek, bez ruchu wstecz, bez teleportu, koniec dokładnie w środku pola, całe piksele), zmiany kierunku (jeden krok na komendę, pozycja zawsze na linii pól), blokada i ogłuszenie (pozycja się nie zmienia), zawalenie w trakcie kroku oraz nakładka F3.
