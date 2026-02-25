function anzahl_event(markerFile, forceplateFile)
    % Vergleicht die Anzahl der Eventtypen:
    % Marker:      HS, TS, HO, TO
    % Forceplate:  HS, LRP, HO, TO
    %
    % TS (Marker) wird mit LRP (Forceplate) verglichen.

    if nargin < 2
        [markerFile, path1] = uigetfile('*.txt', 'Wähle Marker-Event-Datei');
        if isequal(markerFile,0), return; end
        [forceplateFile, path2] = uigetfile('*.txt', 'Wähle Forceplate-Event-Datei');
        if isequal(forceplateFile,0), return; end
        markerFile = fullfile(path1, markerFile);
        forceplateFile = fullfile(path2, forceplateFile);
    end

    % --- Daten einlesen ---
    M = readtable(markerFile, 'FileType', 'text', 'Delimiter', '\t');
    F = readtable(forceplateFile, 'FileType', 'text', 'Delimiter', '\t');

    % --- Nur relevante Spalten behalten ---
    M = M(:, {'Side', 'Event'});
    F = F(:, {'Side', 'Event'});

    % --- Definierte Seiten ---
    sides = {'R', 'L'};

    % Marker-Events
    markerEvents = {'HS', 'TS', 'HO', 'TO'};

    % Forceplate-Events (TS → LRP)
    forceEvents  = {'HS', 'LRP', 'HO', 'TO'};

    % --- Ergebnis-Tabelle vorbereiten ---
    results = table();

    for s = 1:numel(sides)
        for e = 1:numel(markerEvents)

            side = sides{s};
            markerEv = markerEvents{e};
            forceEv  = forceEvents{e};   % gleiche Position → TS ↔ LRP

            % Anzahl Marker
            nM = sum(strcmp(M.Side, side) & strcmp(M.Event, markerEv));

            % Anzahl Forceplate
            nF = sum(strcmp(F.Side, side) & strcmp(F.Event, forceEv));

            % Ergebnisse sammeln
            results = [results; table({side}, {markerEv}, {forceEv}, nM, nF, ...
                'VariableNames', {'Side', 'MarkerEvent', 'ForceplateEvent', ...
                                  'nMarker', 'nForceplate'})];
        end
    end

    % --- Ausgabe ---
    fprintf('\n--- Anzahl der Events: Marker vs. Forceplate ---\n');
    disp(results);
end
