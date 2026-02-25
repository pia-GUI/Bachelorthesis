function plot_heeloff_events()
% plot_heel_events_HO
% Liest 3 TXT-Dateien per uigetfile ein und plottet Heel-Off (HO):
% - Positionsdaten als Linien (LeftHeel_PosY / RightHeel_PosY)
% - Marker-HO als Punkte auf der Linie
% - Forceplate-HO als vertikale Linien
%
% Robust gegen den typischen Fall:
%   Positions-Time_s relativ (ab 0), Event-Time_s absolut (~10440 s).
% Dann wird standardmäßig gegen SampleIdx geplottet.
% Optional wird versucht, eine absolute Zeitachse zu rekonstruieren.

eventName = "HO";  % <<< NUR HIER ändern (HO)

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

%% === 5) Nur HO filtern ===
markerEV = marker(marker.Event == eventName, :);
forceEV  = force(force.Event  == eventName, :);

%% === 6) X-Achse wählen: SampleIdx vs. absolute Zeit rekonstruieren ===
useAbsTime = false;

posTimeSpan = max(pos.Time_s) - min(pos.Time_s);
evtTimeMed  = median([markerEV.Time_s; forceEV.Time_s], 'omitnan');

if posTimeSpan > 1 && evtTimeMed < 1e3
    useAbsTime = false;
elseif evtTimeMed > 1e3 && max(pos.Time_s) < 1e3
    if ~isempty(markerEV)
        offs = markerEV.Time_s - pos.Time_s(markerEV.SampleIdx);
    elseif ~isempty(forceEV)
        offs = forceEV.Time_s - pos.Time_s(forceEV.SampleIdx);
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

xPos_idx = pos.SampleIdx;

%% === 7) Plot ===
figure('Name',sprintf('%s: Marker vs Forceplate', eventName)); hold on; grid on;

if useAbsTime
    xPos = posAbsTime;
    xlabel('Time [s] (rekonstruiert absolut)');
else
    xPos = xPos_idx;
    xlabel('SampleIdx');
end
ylabel('Heel PosY');
title(sprintf('%s: Marker (Punkt) auf PosY + Forceplate (xline)', eventName));

% Linien
hL = plot(xPos, pos.LeftHeel_PosY,  'b', 'LineWidth',1.5);
hR = plot(xPos, pos.RightHeel_PosY, 'r', 'LineWidth',1.5);

% Marker-Punkte
hMarkerL = gobjects(0); hMarkerR = gobjects(0);
for i = 1:height(markerEV)
    s = markerEV.SampleIdx(i);
    if s < 1 || s > height(pos), continue; end

    if useAbsTime, x = posAbsTime(s); else, x = pos.SampleIdx(s); end

    if markerEV.Side(i) == "L"
        y = pos.LeftHeel_PosY(s);
        hMarkerL(end+1) = plot(x, y, 'bo', 'MarkerFaceColor','b'); %#ok<AGROW>
    elseif markerEV.Side(i) == "R"
        y = pos.RightHeel_PosY(s);
        hMarkerR(end+1) = plot(x, y, 'ro', 'MarkerFaceColor','r'); %#ok<AGROW>
    end
end

% Forceplate-Linien
yl = ylim;
hForceL = gobjects(0); hForceR = gobjects(0);
for i = 1:height(forceEV)
    s = forceEV.SampleIdx(i);
    if s < 1 || s > height(pos), continue; end

    if useAbsTime, x = posAbsTime(s); else, x = pos.SampleIdx(s); end

    if forceEV.Side(i) == "L"
        hForceL(end+1) = xline(x, '--b', 'LineWidth',1.2); %#ok<AGROW>
    elseif forceEV.Side(i) == "R"
        hForceR(end+1) = xline(x, '--r', 'LineWidth',1.2); %#ok<AGROW>
    end
end
ylim(yl);

% Legende
legendHandles = [hL, hR];
legendNames   = {'LeftHeel_PosY','RightHeel_PosY'};
if ~isempty(hMarkerL), legendHandles(end+1) = hMarkerL(1); legendNames{end+1} = sprintf('Marker %s (L)',eventName); end %#ok<AGROW>
if ~isempty(hMarkerR), legendHandles(end+1) = hMarkerR(1); legendNames{end+1} = sprintf('Marker %s (R)',eventName); end %#ok<AGROW>
if ~isempty(hForceL),  legendHandles(end+1) = hForceL(1);  legendNames{end+1} = sprintf('Force %s (L)',eventName);  end %#ok<AGROW>
if ~isempty(hForceR),  legendHandles(end+1) = hForceR(1);  legendNames{end+1} = sprintf('Force %s (R)',eventName);  end %#ok<AGROW>
legend(legendHandles, legendNames, 'Location','best');

hold off;
end
