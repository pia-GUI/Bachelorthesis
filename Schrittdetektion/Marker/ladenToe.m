%% === 1) Datei wählen & laden ===
[filename, pathname] = uigetfile('*.txt', 'Wähle ReStoWa-Datei');
if isequal(filename, 0)
    disp('Abbruch durch Benutzer.');
    return;
end
filepath = fullfile(pathname, filename);
data = readtable(filepath);

%% === 2) Wichtige Spalten extrahieren (TOE) ===
time   = data.TimeStamp;
posY   = data.RightToe_PosY;
posY_L = data.LeftToe_PosY;
vy     = data.RightToe_PosY_vy;
ay     = data.RightToe_PosY_ay;
vy_L   = data.LeftToe_PosY_vy;
ay_L   = data.LeftToe_PosY_ay;

%% === 2b) Plot-Fenster: 30 s Ausschnitt ===
t0 = time(1);   % ggf. anpassen
W  = 30;
t1 = t0 + W;

inWin = (time >= t0) & (time <= t1);
if ~any(inWin)
    warning('Zeitfenster [%.3f, %.3f] s enthält keine Daten. Es wird das volle Signal verwendet.', t0, t1);
    inWin = true(size(time));
    t0 = time(1); t1 = time(end);
end

%% === 3. EVENTS: TO zuerst (Marker), TS davor ===
[TO_idx,   TO_t]   = detectToeOff(time, posY,   vy,   ay);
[TO_idx_L, TO_t_L] = detectToeOff(time, posY_L, vy_L, ay_L);

[TS_idx,   TS_t]   = detectToeStrike(time, posY,   vy,   ay,   TO_idx);
[TS_idx_L, TS_t_L] = detectToeStrike(time, posY_L, vy_L, ay_L, TO_idx_L);

fprintf("Gefundene Toe Offs   (R/L): %d / %d\n", numel(TO_idx),   numel(TO_idx_L));
fprintf("Gefundene Toe Strikes aus TO (R/L): %d / %d\n", numel(TS_idx), numel(TS_idx_L));

%% === 4) Separate Plots: Rechts & Links (PosY) — 30 s Fenster ===
% --- Rechts ---
figPosR = figure('Color','w','Name','Rechtes Bein (Toe)');
axPosR  = axes('Parent',figPosR); hold(axPosR,'on'); grid(axPosR,'on')
plot(axPosR, time, posY, 'LineWidth', 1.2, 'DisplayName','PosY rechts');

if ~isempty(TS_idx)
    scatter(axPosR, TS_t, posY(TS_idx), 36, 'v', 'filled', 'DisplayName','TS rechts');
end
if ~isempty(TO_idx)
    scatter(axPosR, TO_t, posY(TO_idx), 36, '^', 'filled', 'DisplayName','TO rechts');
end

xlabel(axPosR,'Zeit [s]'); ylabel(axPosR,'RightToe PosY');
title(axPosR, sprintf('Rechts — TS: %d, TO: %d', numel(TS_idx), numel(TO_idx)));
legend(axPosR,'Location','best');
xlim(axPosR,[t0 t1]);  % ✅ nur x-Achse begrenzen

% --- Links ---
figPosL = figure('Color','w','Name','Linkes Bein (Toe)');
axPosL  = axes('Parent',figPosL); hold(axPosL,'on'); grid(axPosL,'on')
plot(axPosL, time, posY_L, 'LineWidth', 1.2, 'DisplayName','PosY links');

if ~isempty(TS_idx_L)
    scatter(axPosL, TS_t_L, posY_L(TS_idx_L), 40, 'v', 'MarkerFaceColor','none', ...
        'LineWidth',1.0, 'DisplayName','TS links');
end
if ~isempty(TO_idx_L)
    scatter(axPosL, TO_t_L, posY_L(TO_idx_L), 40, '^', 'MarkerFaceColor','none', ...
        'LineWidth',1.0, 'DisplayName','TO links');
end

xlabel(axPosL,'Zeit [s]'); ylabel(axPosL,'LeftToe PosY');
title(axPosL, sprintf('Links — TS: %d, TO: %d', numel(TS_idx_L), numel(TO_idx_L)));
legend(axPosL,'Location','best');
xlim(axPosL,[t0 t1]);  % ✅ nur x-Achse begrenzen

%% === 5) Beschleunigung: Events über ay (rechts & links) — 30 s Fenster ===
% --- Rechts ---
figAyR = figure('Color','w','Name','Rechts (Toe) – Beschleunigung');
axAyR  = axes('Parent',figAyR); hold(axAyR,'on'); grid(axAyR,'on')
plot(axAyR, time, ay, 'LineWidth', 1.2, 'DisplayName','ay rechts');

if ~isempty(TS_idx)
    scatter(axAyR, TS_t, ay(TS_idx), 36, 'v', 'filled', 'DisplayName','TS rechts (ay)');
end
if ~isempty(TO_idx)
    scatter(axAyR, TO_t, ay(TO_idx), 36, '^', 'filled', 'DisplayName','TO rechts (ay)');
end

xlabel(axAyR,'Zeit [s]'); ylabel(axAyR,'ay [m/s^2]');
title(axAyR, sprintf('Rechts — ay mit TS/TO (N=%d / %d)', numel(TS_idx), numel(TO_idx)));
legend(axAyR,'Location','best');
xlim(axAyR,[t0 t1]);  % ✅ nur x-Achse

% --- Links ---
figAyL = figure('Color','w','Name','Links (Toe) – Beschleunigung');
axAyL  = axes('Parent',figAyL); hold(axAyL,'on'); grid(axAyL,'on')
plot(axAyL, time, ay_L, 'LineWidth', 1.2, 'DisplayName','ay links');

if ~isempty(TS_idx_L)
    scatter(axAyL, TS_t_L, ay_L(TS_idx_L), 40, 'v', 'MarkerFaceColor','none', ...
        'LineWidth',1.0, 'DisplayName','TS links (ay)');
end
if ~isempty(TO_idx_L)
    scatter(axAyL, TO_t_L, ay_L(TO_idx_L), 40, '^', 'MarkerFaceColor','none', ...
        'LineWidth',1.0, 'DisplayName','TO links (ay)');
end

xlabel(axAyL,'Zeit [s]'); ylabel(axAyL,'ay [m/s^2]');
title(axAyL, sprintf('Links — ay mit TS/TO (N=%d / %d)', numel(TS_idx_L), numel(TO_idx_L)));
legend(axAyL,'Location','best');
xlim(axAyL,[t0 t1]);  % ✅ nur x-Achse

%% === 6) Geschwindigkeit: Events über vy (rechts & links) — 30 s Fenster ===
% --- Rechts ---
figVyR = figure('Color','w','Name','Geschwindigkeit — rechts (Toe)');
axVyR  = axes('Parent',figVyR); hold(axVyR,'on'); grid(axVyR,'on')
plot(axVyR, time, vy, 'LineWidth', 1.3, 'DisplayName','v_y rechts');
yline(axVyR, 0, ':', 'DisplayName','v_y = 0');

if ~isempty(TS_idx)
    scatter(axVyR, TS_t, vy(TS_idx), 36, 'v', 'filled', 'DisplayName','TS rechts');
end
if ~isempty(TO_idx)
    scatter(axVyR, TO_t, vy(TO_idx), 36, '^', 'filled', 'DisplayName','TO rechts');
end

xlabel(axVyR,'Zeit [s]'); ylabel(axVyR,'v_y [m/s]');
title(axVyR, sprintf('Rechts — v_y mit Events (TS=%d, TO=%d)', numel(TS_idx), numel(TO_idx)));
legend(axVyR,'Location','best');
xlim(axVyR,[t0 t1]);  % ✅ nur x-Achse

% --- Links ---
figVyL = figure('Color','w','Name','Geschwindigkeit — links (Toe)');
axVyL  = axes('Parent',figVyL); hold(axVyL,'on'); grid(axVyL,'on')
plot(axVyL, time, vy_L, 'LineWidth', 1.3, 'DisplayName','v_y links');
yline(axVyL, 0, ':', 'DisplayName','v_y = 0');

if ~isempty(TS_idx_L)
    scatter(axVyL, TS_t_L, vy_L(TS_idx_L), 40, 'v', 'MarkerFaceColor','none', ...
        'LineWidth',1.0, 'DisplayName','TS links');
end
if ~isempty(TO_idx_L)
    scatter(axVyL, TO_t_L, vy_L(TO_idx_L), 40, '^', 'MarkerFaceColor','none', ...
        'LineWidth',1.0, 'DisplayName','TO links');
end

xlabel(axVyL,'Zeit [s]'); ylabel(axVyL,'v_y [m/s]');
title(axVyL, sprintf('Links — v_y mit Events (TS=%d, TO=%d)', numel(TS_idx_L), numel(TO_idx_L)));
legend(axVyL,'Location','best');
xlim(axVyL,[t0 t1]);  % ✅ nur x-Achse

%% === Events + Zeiten in TXT speichern (MARKER EVENTS – TOE) ===
% Speichert erkannte Toe Strike / Toe Off Ereignisse aus der Markeranalyse.
% Format: Side | Event | SampleIdx | Time_s | Source
%
% Hinweis:
%   Diese Datei enthält MARKER-basierte Events (Toe), nicht Forceplate-Daten.
%   Zur Validierung später mit Forceplate-Referenz vergleichen.

% Sicherstellen, dass Variablen existieren
varsToCheck = {'TS_idx','TS_t','TO_idx','TO_t','TS_idx_L','TS_t_L','TO_idx_L','TO_t_L'};
for v = varsToCheck
    if ~exist(v{1}, 'var')
        eval([v{1} ' = [];']);
    end
end

% Anzahl Events pro Seite
nTS_R = numel(TS_idx);
nTO_R = numel(TO_idx);
nTS_L = numel(TS_idx_L);
nTO_L = numel(TO_idx_L);

% Seitenzuordnung
Side = [ ...
    repmat({'R'}, nTS_R, 1); ...
    repmat({'R'}, nTO_R, 1); ...
    repmat({'L'}, nTS_L, 1); ...
    repmat({'L'}, nTO_L, 1) ...
];

% Eventtyp
Event = [ ...
    repmat({'TS'}, nTS_R, 1); ...
    repmat({'TO'}, nTO_R, 1); ...
    repmat({'TS'}, nTS_L, 1); ...
    repmat({'TO'}, nTO_L, 1) ...
];

% Indizes und Zeitpunkte
SampleIdx = [ ...
    TS_idx(:); ...
    TO_idx(:); ...
    TS_idx_L(:); ...
    TO_idx_L(:) ...
];

Time_s = [ ...
    TS_t(:); ...
    TO_t(:); ...
    TS_t_L(:); ...
    TO_t_L(:) ...
];

% Quelle (Marker)
Source = repmat({'Marker'}, numel(Time_s), 1);

% Tabelle erstellen
ToeEvents_Marker = table(Side, Event, SampleIdx, Time_s, Source, ...
    'VariableNames', {'Side','Event','SampleIdx','Time_s','Source'});

% Dateiname: enthält klar "Toe" und "Marker"
[~, baseName, ~] = fileparts(filename);
outName = [baseName '_Toe_MarkerEvents.txt'];
outPath = fullfile(pathname, outName);

% Als tab-separierte TXT speichern
writetable(ToeEvents_Marker, outPath, 'Delimiter', '\t');

fprintf('\n--- TOE MARKER EVENTS exportiert ---\n');
fprintf('Gesamt: %d Events (R:%d, L:%d)\n', height(ToeEvents_Marker), ...
        nTS_R+nTO_R, nTS_L+nTO_L);
fprintf('Datei gespeichert unter:\n  %s\n\n', outPath);