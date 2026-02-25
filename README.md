# Bachelorthesis

# Schrittdetektion mit Vicon-Markerdaten in MATLAB

Dieses MATLAB-Projekt dient der Detektion von Gangereignissen (Heel Strike, Heel Off, Toe Strike und Toe Off) anhand von Vicon-Markerdaten. Die Daten werden zunächst gefiltert und geglättet, anschließend werden die relevanten Gangereignisse automatisch erkannt. Jeder Verarbeitungsschritt ist als eigene MATLAB-Funktion implementiert, sodass die Abläufe modular und flexibel gestaltet sind.

## Inhalt

- [Überblick](#überblick)
- [Projektstruktur](#projektstruktur)
- [Installation und Voraussetzungen](#installation-und-voraussetzungen)
- [Anwendung](#anwendung)
- [Beispielablauf](#beispielablauf)
- [Datenbereinigung und Qualitätsbewertung](Datenbereinigung-und-Qualitätsbewertung)
  - [removeZeroColumns](#removezerocolumns)
  - [cleanMarkersWithPredict](#cleanmarkerswithpredict)
  - [PredictMissingMarkers](#predictmissingmarkers)
  - [cleanGrailTxt](#cleangrailtxt)
  - [Cleancomplete.m](#cleancompletem)
- [Score-Berechnung und Datenqualitätsbewertung](#score-berechnung-und-datenqualitätsbewertung)
- [Detektion der Marker Gangereignisse ](#detektion-der-marker-gangereignisse)
  - [detectHeelStrike](#detectheelstrike)
  - [detectHeelOff](#detectheeloff)
  - [detectToeStrike](#detecttoestrike)
  - [detectToeOff](#detecttoeoff)
  - [Extras: Visualisierung und Export relevanter Marker](#extras-visualisierung-und-export-relevanter-marker)
- [Detektion der Kraft Gangereignisse](#detektion-der-kraft-gangereignisse)
  - [detect_forceplate_HS_LRP_HO_TO](#detect_forceplate_HS_LRP_HO_TO)
  - [detect_LRP](#detect_LRP)
  - [detect_Caderby_HO_segmented](#detect_Caderby_HO_segmented)
- [Vergleich der beiden Methoden](#vergleich-der-beiden-methoden)
  - [compare_event_timing_meanStd](#compare_event_timing_meanstd)
  - [anzahl_event](#anzahl_event)
  - [zusammenfuegen](#zusammenfuegen)
  - [plot_heelstrike_events](#plot_heelstrike_events)
  - [plot_heeloff_events](#plot_heeloff_events)
  - [plot_toeoff_events](#plot_toeoff_events)
  - [plot_TS_mit_LRP](#plot_ts_mit_lrp)

- [Mitwirken](#mitwirken)
- [Lizenz](#lizenz)
- [Kontakt](#kontakt)

## Überblick

Das Projekt umfasst folgende Hauptschritte:
1. **Filterung und Glättung** der Markerdaten
2. **Score-Berechnung** zur Überprüfung der Datenqualität
3. **Detektion von Gangereignissen**:
   - Heel Strike (Fersenkontakt)
   - Heel Off (Fersenablösung)
   - Toe Strike (Zehenspitzkontakt)
   - Toe Off (Zehenspitzenablösung)
4. **Vergleich marker- und kraftbasierter Ereignisse**

Alle Schritte sind als eigenständige MATLAB-Funktionen umgesetzt und können je nach Bedarf kombiniert werden.

## Projektstruktur

Matlab/
│
├── Reinigung/
│   ├── score/
│   ├── clean.m
│   ├── cleanMarkersWithPredict.m
│   ├── filter_forceplate_from_clean.m
│   ├── filter_heeltoe.m
│   ├── PredictMissingMarkers.m
│   ├── process_grail_data.m
│   └── removeZero.m
│
├── Schrittdetektion/
│   ├── Marker/
│   │   ├── detectHeelOff.m
│   │   ├── detectHeelStrike.m
│   │   ├── detectToeOff.m
│   │   ├── detectToeStrike.m
│   │   ├── ladenHeel.m
│   │   └── ladenToe.m
│   │
│   └── Forceplate/
│       ├── detect_Caderby_HO_segmented.m
│       ├── detect_forceplate_HS_LRP_HO_TO.m
│       └── detect_LRP.m
│
└── Vergleich/
    ├── anzahl_event.m
    ├── compare_event_timing_meanStd.m
    ├── extract_posY_and_convert_frame_to_sample.m
    ├── plot_heeloff_events.m
    ├── plot_heelstrike_events.m
    ├── plot_toeoff_events.m
    ├── plot_TS_mit_LRP.m
    └── zusammenfuegen.m

## Installation und Voraussetzungen

- MATLAB (empfohlene Version: R2025 oder neuer)
- Signal Processing Toolbox (für Filteroperationen)
- Vicon-Daten im unterstützten Format (`.txt` aus D-Flow)

## Datenbereinigung und Qualitätsbewertung

### removeZeroColumns
Liest eine `.txt`-Datei mit tabulatorgetrennten Daten ein, entfernt alle Spalten, die ausschließlich Nullen enthalten, und speichert die bereinigten Daten als neue Datei mit dem Suffix `_removeZero.txt`.  

### cleanMarkersWithPredict
Bereinigt Marker-Daten aus Motion-Capture-Aufnahmen (z. B. 3D-Koordinaten eines Markers über die Zeit).  
- Nullwerte (Frames mit [0 0 0]) werden als NaN gesetzt.
- Ausreißer werden als NaN markiert.
- Fehlende Werte werden mit `PredictMissingMarkers` rekonstruiert, notfalls linear interpoliert.

### PredictMissingMarkers
Schätzt fehlende Marker-Daten (NaNs) mittels Marker-Korrelationen und Hauptkomponentenanalyse (PCA) nach Gløersen & Federolf (2016, PLoS ONE).  
- Arbeitet mit einer Matrix aller Marker (nFrames x 3n).
- Optional steuerbar (Algorithmus, Gewichtungsparameter etc.).
- **Ausgabe:** Matrix, in der die NaNs rekonstruiert wurden.

### cleanGrailTxt
Lädt Marker- und Forceplate-Daten aus einer TXT-Datei (aus D-Flow).  
- Marker: Bereinigung via `cleanMarkersWithPredict` und `removeZeroColumns` (Nullwerte, Ausreißer, NaNs auffüllen).
- Forceplate: NaNs füllen und Daten glätten.
- Visualisiert Bewegungen (RightToe vs. RightHeel, 2D und 3D).
- Speichert die bereinigten Daten als neue Datei mit Suffix `_clean.txt` und legt die bereinigten Strukturen im Workspace an.

### filter_heeltoe
Bereitet gefilterte Fersen/Zehen-Positionsdaten (Heel/Toe) aus einer TXT-Datei auf:
- Tiefpassfiltert die Signale (Butterworth, 5 Hz), berechnet Geschwindigkeit und Beschleunigung.
- Optional: z-Transformation für PosY-basierte Reihen.
- Glättet Ausreißer nachträglich.
- Gibt eine Ergebnistabelle mit Position, Geschwindigkeit und Beschleunigung zurück.
- Speichert die Tabelle als `<Originalname>_filter_with_deriv.txt` (tab-getrennt) ab.
  
### Cleancomplete.m
Zentrale Steuerfunktion für die Datenbereinigung und -vorverarbeitung. Ruft die Einzelfunktionen auf und fasst diese zusammen, insbesondere:  
- Entfernt Spalten mit ausschließlich Nullen (`removeZeroColumns`)
- Bereinigt Marker mit Ausreißer-/NaN-Behandlung und Interpolation (`cleanMarkersWithPredict`, `PredictMissingMarkers`)
- Filtert und leitet Heel-/Toe-Marker ab (`filter_heeltoe`)
- Bereinigt und glättet Forceplate-Daten
- Visualisiert und speichert die bereinigten Ergebnisse

Diese Funktionen sorgen für eine automatisierte und robuste Vorverarbeitung von Vicon-Markerdaten.

## Score-Berechnung und Datenqualitätsbewertung

Im Ordner `score/` findet man Funktionen zur Qualitätsbewertung deiner Daten.  
`Score.m` liest eine `.txt`-Datei ein, extrahiert die numerischen Messwerte (ohne erste Spalte) und prüft sie mit `analyzeDataQuality2` auf NaNs, Nullwerte und Ausreißer. Es wird ein Qualitäts-Score (0 %–100 %) berechnet und mit einer Ampel (grün/gelb/rot) bewertet. Die Ergebnisse werden direkt in der MATLAB-Konsole ausgegeben.


## Detektion der Marker Gangereignisse

Die vier Hauptfunktionen zur Ereignisdetektion arbeiten adaptiv und robust gegenüber Rauschen und Tempoänderungen, indem Schwellenwerte auf Basis lokaler Signalstatistiken (z.B. MAD) gesetzt werden.

### detectHeelStrike
- **Zweck:** Erkennt Fersenkontakte (HS) anhand von vertikaler Position, Geschwindigkeit und Beschleunigung der Ferse.
- **Kandidatenfindung:** Sucht robuste Zero-Crossings von vy (negativ zu ≥0) oder "Klemmen" nahe vy=0 mit Aufwärtstrend.
- **Vorbedingung:** Im Lookback-Fenster muss vy einen starken negativen Wert unterschreiten.
- **Validierung:** ay muss um den Kandidaten ein Plateau nahe dem lokalen Median zeigen.
- **Snapping:** Feinjustierung des Zeitpunkts auf das Minimum von posY im nahen Zeitfenster.
- **Refraktärzeit:** Mindestabstand zwischen HS-Ereignissen.
- **Parameter:** VY_EPS, LOOKBACK_S, NEG_DROP_K, REFRACT_S, SNAP_WIN_S, u.a.
- **Ergebnis:** Liefert einzigartige HS-Indizes und zugehörige Zeiten.

### detectHeelOff
- **Zweck:** Erkennt Fersenablösung (HO) nach jedem HS und vor dem nächsten HS.
- **Vorgehen:** Sucht im adaptiven Fenster nach dem frühesten Zeitpunkt mit starker vy-Steigung und ay-Peak.
- **Schwellen:** Adaptiv über lokale MADs.
- **Fallback:** Wählt zur Not das Fenster mit maximaler positiver vy-Steigung.
- **Sequenzschutz:** Achtet darauf, dass HO zwischen HS-Ereignissen und mit Mindestabstand liegt.
- **Parameter:** MIN_DELAY_S, SEARCH_MAX_S, RISE_WIN_S, REFRACT_S.
- **Ergebnis:** HO-Indizes und Zeiten.

### detectToeStrike
- **Zweck:** Erkennt Zehenkontakt (TS) direkt aus Rohdaten, ohne Glättung.
- **Vorgehen:** 
  - Sucht lokale Minima von posY für adaptiven Refraktärabstand.
  - Kandidat: Vorphase mit fallendem posY und negativem vy, dann vy≈0 und ay-Plateau nach dem Event.
- **Parameter:** LOOKBACK_S, FALL_FRAC_MIN, VY_NEG_MIN, ALIGN_WIN_S, PLAT_DUR_S, PLAT_HIT_FRAC.
- **Ergebnis:** TS-Indizes (Beginn des vy≈0-Plateaus nach Fall) und Zeiten.

### detectToeOff
- **Zweck:** Erkennt Zehenablösung (TO) nach posY-Minimum als Onset eines Geschwindigkeitsanstiegs.
- **Vorgehen:** 
  - Sucht erstes posY-Minimum nach TS, dann im nachfolgenden Fenster nach positivem vy- und posY-Trend.
  - Vor-Onset müssen vy/ay ruhig sein.
  - Adaptiv schwellenbasiert (MAD).
  - Fallbacks für schwierige Fälle.
- **Parameter:** GUARD_AFTER_MIN_S, SEARCH_MAX_S, RISE_WIN_S, REFRACT_S, POSY_SLOPE_MIN.
- **Ergebnis:** TO-Indizes (Onset der Aufwärtsbewegung) und Zeiten.

### Toe-Events aus ReStoWa-Daten erkennen und visualisieren

- **Ziel:** Automatische Detektion und Visualisierung von Toe Strike (TS) und Toe Off (TO) für rechts und links aus einer geladenen `.txt`-Datei.
- **Ablauf:** Datei per Dialog wählen, relevante Spalten (`TimeStamp`, `Right/LeftToe_PosY`, `Right/LeftToe_PosY_vy/ay`) einlesen. Erkennung über `detectToeStrike`/`detectToeOff` (je Seite). Anzahl der Events wird in der Konsole ausgegeben.
- **Plots:** PosY, vy, ay (rechts/links) mit TS/TO-Markern.
- **Abhängigkeiten:** Benötigt `detectToeStrike` und `detectToeOff`.
- **Ausgabe:** Keine Datei, Ergebnisse im Workspace und als Plot/Konsole.

## Detektion der Kraft Gangereignisse

### detect_forceplate_HS_LRP_HO_TO
- Zweck: Erkennt kraftplattenbasierte Gangereignisse (HS, TO, LRP, HO) anhand der vertikalen Bodenreaktionskraft (vGRF).
- Datengrundlage: Verwendung der vertikalen Kraftkomponente (z. B. ForY) beider Kraftplatten.
- Kontaktdefinition: Schwellenwert von 10 N zur Klassifikation von Kontakt (vGRF > 10 N) und Schwungphase (vGRF ≤ 10 N).
- HS-Detektion: Übergang von 0 → 1 im binarisierten Kraftsignal.
- TO-Detektion: Übergang von 1 → 0 im binarisierten Kraftsignal.
- Sequenzschutz: Verhindert TO-Detektion ohne vorherigen HS.
- Segmentierung: HS–TO-Intervalle dienen als Basis für weitere Eventanalysen.
- LRP-Integration: Aufruf von detect_LRP zur Bestimmung des Loading Response Peaks.
- HO-Integration: Aufruf von detect_Caderby_HO_segmented zur HO-Detektion.
- Visualisierung: Plot der vGRF mit Markierung aller detektierten Events.
- Export: Speicherung als _ForceplateEvents.txt mit Side, Event, SampleIdx, Time_s, Source.
- Ergebnis: Liefert strukturierte Eventliste für beide Seiten.

### detect_LRP
- Zweck: Detektiert den Loading Response Peak (LRP) innerhalb der Standphase.
- Segmentierung: Analyse zwischen HS und TO.
- Kandidatenfindung: Erstes lokales Maximum der vGRF nach HS.
- Biomechanische Bedeutung: Erster deutlicher Kraftpeak während Lastübernahme.
- Validierung: Peak muss innerhalb früher Standphase liegen.
- Parameter: Peak-Suchfenster abhängig von HS–TO-Dauer.
- Ergebnis: Liefert LRP-Indizes und Zeitpunkte

### detect_Caderby_HO_segmented
- Zweck: Bestimmt Heel Off (HO) aus Kraftplattendaten nach Caderby-Methode.
- Vorverarbeitung: 10-Hz-Butterworth-Filter.
- Normierung: Korrektur um Körpergewicht.
- Integration: Integration des Kraftsignals innerhalb Standphase.
- Kandidatenfindung: Letztes ausgeprägtes Minimum nach Kraftpeak.
- Segmentierung: HO liegt zwingend zwischen HS und TO.
- Ergebnis: Liefert HO-Indizes und Zeitpunkte.

## Vergleich der beiden Methoden

### ### compare_event_timing_meanStd
- Zweck: Zeitlicher Vergleich marker- und kraftbasierter Events.
- Matching: Nearest-Neighbor-Zuordnung pro Seite (R/L).
- Differenzberechnung: Markerzeit − Kraftplattenzeit.
- Statistik: Mittelwert und Standardabweichung der Zeitdifferenzen.
- Ergebnis: Übersichtstabelle mit Seitenzuordnung und Abweichungen.

### anzahl_event
- Zweck: Vergleich der Anzahl detektierter Events zwischen Marker und Forceplate.
- Analyse: Zählt Events pro Typ (HS, HO, TS, TO).
- Seitengetrennt: Rechte und linke Körperseite.
- Ergebnis: Konsolenausgabe mit Eventanzahl pro Methode.

### zusammenfuegen
- Zweck: Zusammenführung mehrerer Event-Tabellen.
- Struktur: Vereinheitlicht Side, Event, SampleIdx, Time_s.
- Ergebnis: Kombinierte Eventliste für weiterführende Analyse.

### plot_heelstrike_events
- Zweck: Visualisierung HS Marker vs. Forceplate.
- Darstellung: vGRF und MarkerposY im selben Plot.
- Markierung: Marker-Ereignisse als Punkte, Forceplate-Ereignisse als Linien.
- Ergebnis: Grafische Vergleichsdarstellung.

### plot_heeloff_events
- Zweck: Visualisierung HO Marker vs. Forceplate.
- Ergebnis: Plot mit Event-Markierungen.

### plot_toeoff_events
- Zweck: Visualisierung TO Marker vs. Forceplate.
- Ergebnis: Grafischer Vergleich beider Methoden.

### plot_TS_mit_LRP
- Zweck: Vergleich markerbasiertes TS mit kraftbasiertem LRP.
- Ergebnis: Visualisierung zeitlicher Übereinstimmung

## Mitwirken

Beiträge, Fehlerberichte oder Verbesserungsvorschläge sind herzlich willkommen!  
Bitte öffne ein Issue oder einen Pull Request.
Die verwendeten Literaturen sind in den Matlab-Funktionen beigefügt

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz.

## Kontakt

Bei Fragen oder Anregungen gerne ein Issue erstellen oder eine E-Mail an pia.fischer002@stud.fh-dortmund.de senden.
