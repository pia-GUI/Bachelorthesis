function plot_heelstrike_events()
% plot_heel_events
% Liest 3 TXT-Dateien per uigetfile ein und plottet Heel-Strike (HS):
% - Positionsdaten als Linien (LeftHeel_PosY / RightHeel_PosY)
% - Marker-HS als Punkte auf der Linie
% - Forceplate-HS als vertikale Linien
%
% Robust gegen den typischen Fall:
%   Positions-Time_s relativ (ab 0), Event-Time_s absolut (~10440 s).
% Dann wird standardmäßig gegen SampleIdx geplottet.
% Optional wird versucht, eine absolute Zeitachse zu rekonstruieren.

%% === 1) Positionsdaten wählen & laden ===
[fnPos, pnPos] = uigetfile('*.txt', 'Wähle Positionsdaten (PosY)');
if isequal(fnPos,0), disp('Abbruch (Positionsdaten).'); return; end
pos = readtable(fullfile(pnPos, fnPos), ...
    'FileType','text','Delimiter','\t','PreserveVariableNames',true);

%% === 2) Marker-Events wählen & laden ===
[fnMarker, pnMarker] = uigetfile('*.txt', 'Wähle Marker-Events');
if isequal(fnMarker,0), disp('Abbruch (Marker-Events).'); return; end
marker = readtable(fullfile(pnMarker, fnMarker), ...
    'FileType','text','Delimiter','\t','PreserveVariableNames',true);

%% === 3) Forceplate-Events wählen & laden ===
[fnForce, pnForce] = uigetfile('*.txt', 'Wähle Forceplate-Events');
if isequal(fnForce,0), disp('Abbruch (Forceplate-Events).'); return; end
force = readtable(fullfile(pnForce, fnForce), ...
    'FileType','text','Delimiter','\t','PreserveVariableNames',true);

%% === 4) Pflichtspalten prüfen ===
reqPos = ["SampleIdx","Time_s","LeftHeel_PosY","RightHeel_PosY"];
reqEvt = ["Side","Event","SampleIdx","Time_s","Source"];

assert(all(ismember(reqPos, string(pos.Properties.VariableNames))), ...
    "Positionsdatei fehlt Spalten: %s", join(reqPos(~ismember(reqPos,string(pos.Properties.VariableNames))), ", "));

assert(all(ismember(reqEvt, string(marker.Properties.VariableNames))), ...
    "Markerdatei fehlt Spalten: %s", join(reqEvt(~ismember(reqEvt,string(marker.Properties.VariableNames))), ", "));

assert(all(ismember(reqEvt, string(force.Properties.VariableNames))), ...
    "Forceplate-Datei fehlt Spalten: %s", join(reqEvt(~ismember(reqEvt,string(force.Properties.VariableNames))), ", "));

marker.Side  = string(marker.Side);  marker.Event = string(marker.Event);
force.Side   = string(force.Side);   force.Event  = string(force.Event);

%% === 5) Nur HS filtern ===
markerHS = marker(marker.Event == "HS", :);
forceHS  = force(force.Event  == "HS", :);

%% === 6) X-Achse wählen: SampleIdx vs. absolute Zeit rekonstruieren ===
useAbsTime = false;

% Heuristik: wenn Positionszeit im Bereich < 1e3 s ist, Events aber > 1e3 s,
% dann sind Events "absolut" und Positionen "relativ".
posTimeSpan = max(pos.Time_s) - min(pos.Time_s);
evtTimeMed  = median([markerHS.Time_s; forceHS.Time_s], 'omitnan');

if posTimeSpan > 1 && evtTimeMed < 1e3
    % selten: Events relativ -> direkt Time_s plotten
    useAbsTime = false; % trotzdem SampleIdx ok
elseif evtTimeMed > 1e3 && max(pos.Time_s) < 1e3
    % typisch: Events absolut, Pos relativ -> Offset berechnen
    % Offset via Marker-HS (oder ForceHS, falls Marker leer)
    if ~isempty(markerHS)
        offs = markerHS.Time_s - pos.Time_s(markerHS.SampleIdx);
    elseif ~isempty(forceHS)
        offs = forceHS.Time_s - pos.Time_s(forceHS.SampleIdx);
    else
        offs = NaN;
    end
    offs = offs(isfinite(offs));
    if ~isempty(offs)
        offset = median(offs);
        posAbsTime = pos.Time_s + offset;
        useAbsTime = true;
    end
end

% Fallback: SampleIdx
xPos_idx = pos.SampleIdx;

%% === 7) Plot ===
figure('Name','Heel Strike (HS): Marker vs Forceplate'); hold on; grid on;

if useAbsTime
    xPos = posAbsTime;
    xlabel('Time [s] (rekonstruiert absolut)');
else
    xPos = xPos_idx;
    xlabel('SampleIdx');
end
ylabel('Heel PosY');
title('HS: Marker (Punkt) auf PosY + Forceplate (xline)');

% Linien
hL = plot(xPos, pos.LeftHeel_PosY,  'b', 'LineWidth',1.5);
hR = plot(xPos, pos.RightHeel_PosY, 'r', 'LineWidth',1.5);

% Marker-Punkte (direkt über SampleIdx -> kein Time-Mismatch)
hMarkerL = gobjects(0); hMarkerR = gobjects(0);
for i = 1:height(markerHS)
    s = markerHS.SampleIdx(i);
    if s < 1 || s > height(pos), continue; end

    if useAbsTime
        x = posAbsTime(s);
    else
        x = pos.SampleIdx(s);
    end

    if markerHS.Side(i) == "L"
        y = pos.LeftHeel_PosY(s);
        hMarkerL(end+1) = plot(x, y, 'bo', 'MarkerFaceColor','b'); %#ok<AGROW>
    elseif markerHS.Side(i) == "R"
        y = pos.RightHeel_PosY(s);
        hMarkerR(end+1) = plot(x, y, 'ro', 'MarkerFaceColor','r'); %#ok<AGROW>
    end
end

% Forceplate-Linien (über SampleIdx-position auf die gleiche X-Achse)
yl = ylim;
hForceL = gobjects(0); hForceR = gobjects(0);
for i = 1:height(forceHS)
    s = forceHS.SampleIdx(i);
    if s < 1 || s > height(pos), continue; end

    if useAbsTime
        x = posAbsTime(s);
    else
        x = pos.SampleIdx(s);
    end

    if forceHS.Side(i) == "L"
        hForceL(end+1) = xline(x, '--b', 'LineWidth',1.2); %#ok<AGROW>
    elseif forceHS.Side(i) == "R"
        hForceR(end+1) = xline(x, '--r', 'LineWidth',1.2); %#ok<AGROW>
    end
end
ylim(yl);

% Legende (nur je 1 Eintrag pro Kategorie)
legendHandles = [hL, hR];
legendNames   = {'LeftHeel_PosY','RightHeel_PosY'};
if ~isempty(hMarkerL), legendHandles(end+1) = hMarkerL(1); legendNames{end+1} = 'Marker HS (L)'; end %#ok<AGROW>
if ~isempty(hMarkerR), legendHandles(end+1) = hMarkerR(1); legendNames{end+1} = 'Marker HS (R)'; end %#ok<AGROW>
if ~isempty(hForceL),  legendHandles(end+1) = hForceL(1);  legendNames{end+1} = 'Force HS (L)';  end %#ok<AGROW>
if ~isempty(hForceR),  legendHandles(end+1) = hForceR(1);  legendNames{end+1} = 'Force HS (R)';  end %#ok<AGROW>
legend(legendHandles, legendNames, 'Location','best');

hold off;
end
