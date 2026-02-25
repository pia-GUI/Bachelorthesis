%% === 1. Datei laden ===
[filename, pathname] = uigetfile('*.txt', 'Wähle ReStoWa-Datei');
if isequal(filename, 0)
    disp('Abbruch durch Benutzer.');
    return;  % Falls kein File gewählt wurde → Abbruch
end
filepath = fullfile(pathname, filename);
data = readtable(filepath);  % Einlesen der TXT-Datei als Tabelle

%% === 2. Wichtige Spalten extrahieren ===
time   = data.TimeStamp;             % Zeit in Sekunden
posY   = data.RightHeel_PosY;        % Vertikale Position rechter Heel
posY_L = data.LeftHeel_PosY;         % Vertikale Position linker Heel
vy     = data.RightHeel_PosY_vy;     % Geschwindigkeit rechts
vy_L   = data.LeftHeel_PosY_vy;      % Geschwindigkeit links
ay     = data.RightHeel_PosY_ay;     % Beschleunigung rechts
ay_L   = data.LeftHeel_PosY_ay;      % Beschleunigung links

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


%% === 3. Heel Strike & Heel Off erkennen (Events) ===
% Aufruf externer Funktionen zur Event-Erkennung (rechte und linke Seite)
[HS_idx,   HS_t]   = detectHeelStrike(time, posY, vy, ay);        % Heel Strikes rechts
[HO_idx, HO_t] = detectHeelOff(time, posY, vy, ay, HS_idx);       % Heel Off rechts
[HS_idx_L, HS_t_L] = detectHeelStrike(time, posY_L, vy_L, ay_L);  % Heel Strikes links
[HO_idx_L, HO_t_L] = detectHeelOff(time, posY_L, vy_L, ay_L, HS_idx_L);   % Heel Off links


fprintf("Nach Refinement Heel Strikes (R/L): %d / %d\n", numel(HS_idx), numel(HS_idx_L));

% Ausgabe der Anzahl erkannter Events in der Konsole
fprintf("Gefundene Heel Strikes (R/L): %d / %d\n", numel(HS_idx), numel(HS_idx_L));
fprintf("Gefundene Heel Offs   (R/L): %d / %d\n", numel(HO_idx), numel(HO_idx_L));

%% === 4. Einzelplots für rechts und links ===
% --- Rechts ---
figure('Color','w','Name','Rechtes Bein'); hold on; grid on
plot(time, posY, 'LineWidth', 1.2, 'DisplayName','PosY rechts');
if ~isempty(HS_idx)
    scatter(HS_t, posY(HS_idx), 36, 'v', 'filled', 'DisplayName','HS rechts'); % Heel Strike Marker
end
if ~isempty(HO_idx)
    scatter(HO_t, posY(HO_idx), 36, '^', 'filled', 'DisplayName','HO rechts'); % Heel Off Marker
end
xlabel('Zeit [s]'); ylabel('RightHeel PosY');
title(sprintf('Rechtes Bein — HS: %d, HO: %d', numel(HS_idx), numel(HO_idx)));
legend('Location','best');
xlim([t0 t1]);

% --- Links ---
figure('Color','w','Name','Linkes Bein'); hold on; grid on
plot(time, posY_L, 'LineWidth', 1.2, 'DisplayName','PosY links');
if ~isempty(HS_idx_L)
    scatter(HS_t_L, posY_L(HS_idx_L), 40, 'v', 'MarkerFaceColor','none', ...
            'LineWidth',1.0, 'DisplayName','HS links'); % Heel Strike Marker
end
if ~isempty(HO_idx_L)
    scatter(HO_t_L, posY_L(HO_idx_L), 40, '^', 'MarkerFaceColor','none', ...
            'LineWidth',1.0, 'DisplayName','HO links'); % Heel Off Marker
end
xlabel('Zeit [s]'); ylabel('LeftHeel PosY');
title(sprintf('Linkes Bein — HS: %d, HO: %d', numel(HS_idx_L), numel(HO_idx_L)));
legend('Location','best');
xlim([t0 t1]);

%% === 5. Plot: Beschleunigung rechts + Events ===
figR = figure('Color','w','Name','Beschleunigung — rechtes Bein');
axR = axes('Parent',figR); hold(axR,'on'); grid(axR,'on')
plot(axR, time, ay, 'LineWidth', 1.3, 'DisplayName','a_y rechts');
if ~isempty(HS_idx)
    scatter(axR, time(HS_idx), ay(HS_idx), 36, 'v', 'filled', 'DisplayName','Heel Strike (R)');
end
if ~isempty(HO_idx)
    scatter(axR, time(HO_idx), ay(HO_idx), 36, '^', 'filled', 'DisplayName','Heel Off (R)');
end
xlabel(axR,'Zeit [s]'); ylabel(axR,'z-transformierte a_y (standardisiert)');
title(axR, sprintf('Rechtes Bein — a_y mit Events (HS=%d, HO=%d)', numel(HS_idx), numel(HO_idx)));
legend(axR, 'Location','best');
xlim([t0 t1]);

%% === 6. Plot: Beschleunigung links + Events ===
figL = figure('Color','w','Name','Beschleunigung — linkes Bein');
axL = axes('Parent',figL); hold(axL,'on'); grid(axL,'on')
plot(axL, time, ay_L, 'LineWidth', 1.3, 'DisplayName','a_y links');
if ~isempty(HS_idx_L)
    scatter(axL, time(HS_idx_L), ay_L(HS_idx_L), 40, 'v', 'MarkerFaceColor','none', 'LineWidth',1.0, 'DisplayName','Heel Strike (L)');
end
if ~isempty(HO_idx_L)
    scatter(axL, time(HO_idx_L), ay_L(HO_idx_L), 40, '^', 'MarkerFaceColor','none', 'LineWidth',1.0, 'DisplayName','Heel Off (L)');
end
xlabel(axL,'Zeit [s]'); ylabel(axL,'z-transformierte a_y (standardisiert)');
title(axL, sprintf('Linkes Bein — a_y mit Events (HS=%d, HO=%d)', numel(HS_idx_L), numel(HO_idx_L)));
legend(axL, 'Location','best');
xlim([t0 t1]);

%% === 7. Gemeinsame y-Achsenlimits ===
yl_all = [min([ay; ay_L],[],'omitnan'), max([ay; ay_L],[],'omitnan')];
pad = 0.05 * max(eps, yl_all(2)-yl_all(1));
ylim(axR, [yl_all(1)-pad, yl_all(2)+pad]);
ylim(axL, [yl_all(1)-pad, yl_all(2)+pad]);
%% === 8. Plot: Geschwindigkeit rechts + Events ===
figVyR = figure('Color','w','Name','Geschwindigkeit — rechtes Bein'); 
axVyR = axes('Parent',figVyR); hold(axVyR,'on'); grid(axVyR,'on')
plot(axVyR, time, vy, 'LineWidth', 1.3, 'DisplayName','v_y rechts');
yline(axVyR, 0, ':', 'DisplayName','v_y = 0');
if ~isempty(HS_idx)
    scatter(axVyR, HS_t, vy(HS_idx), 36, 'v', 'filled', 'DisplayName','Heel Strike (R)');
end
if ~isempty(HO_idx)
    scatter(axVyR, HO_t, vy(HO_idx), 36, '^', 'filled', 'DisplayName','Heel Off (R)');
end
xlabel(axVyR,'Zeit [s]'); ylabel(axVyR,'z-transformierte v_y (standardisiert)');
title(axVyR, sprintf('Rechtes Bein — v_y mit Events (HS=%d, HO=%d)', numel(HS_idx), numel(HO_idx)));
legend(axVyR, 'Location','best');
xlim([t0 t1]);

%% === 9. Plot: Geschwindigkeit links + Events ===
figVyL = figure('Color','w','Name','Geschwindigkeit — linkes Bein'); 
axVyL = axes('Parent',figVyL); hold(axVyL,'on'); grid(axVyL,'on')
plot(axVyL, time, vy_L, 'LineWidth', 1.3, 'DisplayName','v_y links');
yline(axVyL, 0, ':', 'DisplayName','v_y = 0');
if ~isempty(HS_idx_L)
    scatter(axVyL, HS_t_L, vy_L(HS_idx_L), 40, 'v', 'MarkerFaceColor','none', 'LineWidth',1.0, 'DisplayName','Heel Strike (L)');
end
if ~isempty(HO_idx_L)
    scatter(axVyL, HO_t_L, vy_L(HO_idx_L), 40, '^', 'MarkerFaceColor','none', 'LineWidth',1.0, 'DisplayName','Heel Off (L)');
end
xlabel(axVyL,'Zeit [s]'); ylabel(axVyL,'z-transformierte v_y (standardisiert)');
title(axVyL, sprintf('Linkes Bein — v_y mit Events (HS=%d, HO=%d)', numel(HS_idx_L), numel(HO_idx_L)));
legend(axVyL, 'Location','best');
xlim([t0 t1]);

%% === 10. Gemeinsame y-Achsenlimits für v_y (optional) ===
yl_vy = [min([vy; vy_L],[],'omitnan'), max([vy; vy_L],[],'omitnan')];
pad_vy = 0.05 * max(eps, yl_vy(2)-yl_vy(1));
ylim(axVyR, [yl_vy(1)-pad_vy, yl_vy(2)+pad_vy]);
ylim(axVyL, [yl_vy(1)-pad_vy, yl_vy(2)+pad_vy]);

%% === 11. Schrittdauer & -weiten (kompakt, korrekte Reihenfolge) ===
% Gehgeschwindigkeit v in m/s 
v = 0.8;   

m = @(x) mean(x,'omitnan'); 
s = @(x) std(x,'omitnan');

% --------- ZEITEN zuerst berechnen ---------
% Stride-Zeiten (HS -> HS)
if numel(HS_t)   >= 2, strideTimes_R = diff(HS_t);   else, strideTimes_R = []; end
if numel(HS_t_L) >= 2, strideTimes_L = diff(HS_t_L); else, strideTimes_L = []; end
allStrideTimes = [strideTimes_R; strideTimes_L];

% Step-Zeiten (R -> L)
stepTimes_RL = [];
if ~isempty(HS_t) && ~isempty(HS_t_L)
    j = 1;
    for i = 1:numel(HS_t)
        while j <= numel(HS_t_L) && HS_t_L(j) <= HS_t(i), j = j + 1; end
        if j <= numel(HS_t_L), stepTimes_RL(end+1,1) = HS_t_L(j) - HS_t(i); end %#ok<SAGROW>
    end
end

% Step-Zeiten (L -> R)
stepTimes_LR = [];
if ~isempty(HS_t) && ~isempty(HS_t_L)
    j = 1;
    for i = 1:numel(HS_t_L)
        while j <= numel(HS_t) && HS_t(j) <= HS_t_L(i), j = j + 1; end
        if j <= numel(HS_t), stepTimes_LR(end+1,1) = HS_t(j) - HS_t_L(i); end %#ok<SAGROW>
    end
end
allStepTimes = [stepTimes_RL; stepTimes_LR];

% --------- AUSGABEN: Schrittdauern ---------
if ~isempty(strideTimes_R)
    fprintf('Stridedauer (R→R): Mittel = %.3f s, SD = %.3f s, n = %d\n', m(strideTimes_R), s(strideTimes_R), numel(strideTimes_R));
else
    fprintf('Stridedauer (R→R): zu wenige HS (n<2)\n');
end
if ~isempty(strideTimes_L)
    fprintf('Stridedauer (L→L): Mittel = %.3f s, SD = %.3f s, n = %d\n', m(strideTimes_L), s(strideTimes_L), numel(strideTimes_L));
else
    fprintf('Stridedauer (L→L): zu wenige HS (n<2)\n');
end
if ~isempty(allStrideTimes)
    fprintf('Stridedauer gesamt (Strides): Mittel = %.3f s, SD = %.3f s, n = %d\n', m(allStrideTimes), s(allStrideTimes), numel(allStrideTimes));
end

if ~isempty(stepTimes_RL)
    fprintf('Schrittdauer R→L: Mittel = %.3f s, SD = %.3f s, n = %d\n', m(stepTimes_RL), s(stepTimes_RL), numel(stepTimes_RL));
else
    fprintf('Schrittdauer R→L: keine Paare gefunden\n');
end
if ~isempty(stepTimes_LR)
    fprintf('Schrittdauer L→R: Mittel = %.3f s, SD = %.3f s, n = %d\n', m(stepTimes_LR), s(stepTimes_LR), numel(stepTimes_LR));
else
    fprintf('Schrittdauer L→R: keine Paare gefunden\n');
end
if ~isempty(allStepTimes)
    fprintf('Schrittdauer gesamt (Steps): Mittel = %.3f s, SD = %.3f s, n = %d\n', m(allStepTimes), s(allStepTimes), numel(allStepTimes));
    fprintf('Kadenz: %.1f Schritte/min\n', 60/m(allStepTimes));
end

% --------- LÄNGEN aus ZEITEN berechnen & ausgeben ---------
% Stride-Längen
strideLen_R = v * strideTimes_R;
strideLen_L = v * strideTimes_L;
allStrideLen = [strideLen_R; strideLen_L];

if ~isempty(strideLen_R)
    fprintf('Stridelänge R→R: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(strideLen_R), s(strideLen_R), numel(strideLen_R));
else
    fprintf('Stridelänge R→R: zu wenige HS (n<2)\n');
end
if ~isempty(strideLen_L)
    fprintf('Stridelänge L→L: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(strideLen_L), s(strideLen_L), numel(strideLen_L));
else
    fprintf('Stridelänge L→L: zu wenige HS (n<2)\n');
end
if ~isempty(allStrideLen)
    fprintf('Stridelänge gesamt: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(allStrideLen), s(allStrideLen), numel(allStrideLen));
end

% Step-Längen
stepLen_RL = v * stepTimes_RL;
stepLen_LR = v * stepTimes_LR;
allStepLen = [stepLen_RL; stepLen_LR];

if ~isempty(stepLen_RL)
    fprintf('Schrittlänge R→L: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(stepLen_RL), s(stepLen_RL), numel(stepLen_RL));
else
    fprintf('Schrittlänge R→L: keine Paare gefunden\n');
end
if ~isempty(stepLen_LR)
    fprintf('Schrittlänge L→R: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(stepLen_LR), s(stepLen_LR), numel(stepLen_LR));
else
    fprintf('Schrittlänge L→R: keine Paare gefunden\n');
end
if ~isempty(allStepLen)
    fprintf('Schrittlänge gesamt: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(allStepLen), s(allStepLen), numel(allStepLen));
end
%% === Aggregierte Kennwerte in den Workspace (ohne Rohzeitpunkte) ===
% Voraussetzung: strideTimes_*, stepTimes_*, strideLen_*, stepLen_* sind bereits berechnet
m = @(x) mean(x,'omitnan');
s = @(x) std(x,'omitnan');

% Sicherstellen, dass Kombi-Arrays existieren
if ~exist('allStrideTimes','var'), allStrideTimes = [strideTimes_R; strideTimes_L]; end
if ~exist('allStepTimes','var'),   allStepTimes   = [stepTimes_RL;  stepTimes_LR];  end
if ~exist('allStrideLen','var'),   allStrideLen   = [strideLen_R;    strideLen_L];   end
if ~exist('allStepLen','var'),     allStepLen     = [stepLen_RL;     stepLen_LR];    end

% Tabelle der Kennwerte: {Basisname, Array}
pairs = {
  'strideTime_R',          strideTimes_R;
  'strideTime_L',          strideTimes_L;
  'strideTime_all_strides',allStrideTimes;

  'stepTime_RL',           stepTimes_RL;
  'stepTime_LR',           stepTimes_LR;
  'stepTime_all',          allStepTimes;

  'strideLen_R',           strideLen_R;
  'strideLen_L',           strideLen_L;
  'strideLen_all',         allStrideLen;

  'stepLen_RL',            stepLen_RL;
  'stepLen_LR',            stepLen_LR;
  'stepLen_all',           allStepLen
};

for i = 1:size(pairs,1)
    name = pairs{i,1};
    x    = pairs{i,2};
    if ~exist('x','var') || isempty(x)
        mu = NaN; sd = NaN; n = 0;
    else
        mu = m(x); sd = s(x); n = numel(x);
    end
    assignin('base', [name '_mean'], mu);
    assignin('base', [name '_sd'],   sd);
    assignin('base', [name '_n'],    n);
end

% Kadenz aus allen Step-Zeiten
if ~isempty(allStepTimes)
    assignin('base','cadence_spm', 60/m(allStepTimes));
else
    assignin('base','cadence_spm', NaN);
end
%% === Events + Zeiten in TXT speichern (MARKER EVENTS) ===
% Speichert erkannte Heel Strike / Heel Off Ereignisse aus Markeranalyse.
% Format: Side | Event | SampleIdx | Time_s | Source
%
% Hinweis:
%   Diese Datei enthält MARKER-basierte Events (nicht Forceplate).
%   Für die Validierung mit Forceplate-Ereignissen separat vergleichen.

% Sicherstellen, dass alle Variablen existieren
varsToCheck = {'HS_idx','HS_t','HO_idx','HO_t','HS_idx_L','HS_t_L','HO_idx_L','HO_t_L'};
for v = varsToCheck
    if ~exist(v{1}, 'var')
        eval([v{1} ' = [];']);
    end
end

% Seitenzuordnung
nHS_R = numel(HS_idx);
nHO_R = numel(HO_idx);
nHS_L = numel(HS_idx_L);
nHO_L = numel(HO_idx_L);

Side = [ ...
    repmat({'R'}, nHS_R, 1); ...
    repmat({'R'}, nHO_R, 1); ...
    repmat({'L'}, nHS_L, 1); ...
    repmat({'L'}, nHO_L, 1) ...
];

Event = [ ...
    repmat({'HS'}, nHS_R, 1); ...
    repmat({'HO'}, nHO_R, 1); ...
    repmat({'HS'}, nHS_L, 1); ...
    repmat({'HO'}, nHO_L, 1) ...
];

SampleIdx = [ ...
    HS_idx(:); ...
    HO_idx(:); ...
    HS_idx_L(:); ...
    HO_idx_L(:) ...
];

Time_s = [ ...
    HS_t(:); ...
    HO_t(:); ...
    HS_t_L(:); ...
    HO_t_L(:) ...
];

Source = repmat({'Marker'}, numel(Time_s), 1);

% Tabelle erstellen
MarkerEvents = table(Side, Event, SampleIdx, Time_s, Source, ...
    'VariableNames', {'Side','Event','SampleIdx','Time_s','Source'});

% Dateiname mit Marker-Hinweis
[~, baseName, ~] = fileparts(filename);
outName = [baseName '_Heel_MarkerEvents.txt'];
outPath = fullfile(pathname, outName);

% Als tab-separierte TXT-Datei speichern
writetable(MarkerEvents, outPath, 'Delimiter', '\t');

fprintf('\n--- MARKER EVENTS exportiert ---\n');
fprintf('Gesamt: %d Events (R:%d, L:%d)\n', height(MarkerEvents), ...
        nHS_R+nHO_R, nHS_L+nHO_L);
fprintf('Datei gespeichert unter:\n  %s\n\n', outPath);

