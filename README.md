# Deep Mine: Cursed Depths — build 0.2

Nowa ścieżka produkcyjna: build → publikacja → obserwacja → aktualizacja. Bez osobnego porównania dwóch wariantów prototypu.

## Uruchomienie

1. Zainstaluj Godot 4.7.x standard/GDScript. Testy: ustaw `GODOT_BIN` na binarium 4.7.x i uruchom `bash tests/run_tests.sh` (szczegóły w `AGENTS.md`).
2. Wybierz Import i otwórz plik `project.godot`.
3. Uruchom F5. Gra otwiera się w pionie, w rozdzielczości 720×1280.
4. Rozpocznij wyprawę, kop od pierwszego rzędu, znajdź rdzeń, wróć, odbierz dochód na sekundę i kup ulepszenie.

Na Androidzie skonfiguruj SDK + JDK17, szablony eksportu, preset Android i uruchom przez USB. Google Play wymaga w 2026 r. target API 36 dla nowych aplikacji.

## Funkcje w buildzie 0.2

- Mapa 6×9 generowana deterministycznie według numeru wyprawy
- Sąsiedztwo kopania, HP bloków, surowce, wartości, hałas
- Rdzeń zasilający bazę, dochód pasywny, limit sześciu generatorów, zastępowanie najsłabszego
- Kopanie, sprzedaż, rozwój kilofa, trening
- Serce kopalni: ryzyko lub rezygnacja, bonus do przyszłego łupu
- Spotkanie potwora, decyzja walczyć/uciec
- Zapis złota, ulepszeń, generatorów i postępu; naliczenie offline do 12 godzin
- Lokalne zdarzenia diagnostyczne `user://events_v12.jsonl`

## Ograniczenia

To grywalny prototyp rdzenia w szacie technicznej. Nie ma animacji, assetów docelowych, AdMob, Billing, uwierzytelniania ani backendu. Nie jest jeszcze gotowy do publikacji. Brak dostępu do środowiska Godot w tym kontenerze uniemożliwia potwierdzenie uruchomienia i eksportu Android; wymagane lokalne uruchomienie i poprawienie ewentualnych błędów parsera.

## Zasada balansu

Jedynym źródłem parametrów jest `data/balance.json`. Cel: pierwszy rdzeń w 2–3 min, pierwsze ulepszenie w 5 min, wyprawa 2–5 min, baza zarabia także podczas przerwy.

## Najbliższa iteracja

1. Uruchomienie bez błędów parsera i test działania mechanik na Windows/Android.
2. Opracowanie czytelnej oprawy mapy, animacji kopania, wibracji i feedbacku łupu.
3. Pierwsze cele i odblokowywanie stref, cykl dobowy oraz codzienne wyzwanie.
4. Integracja SDK reklam, Google Play Billing, analityki i zgód.
5. Publiczny release w pierwszym stabilnym zakresie, monitoring i cotygodniowe poprawki.
