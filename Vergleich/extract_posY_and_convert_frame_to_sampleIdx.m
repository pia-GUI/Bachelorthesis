function export_PosY_with_SampleIdx_100Hz()
%% === 1) Datei wählen & laden ===
[filename, pathname] = uigetfile('*.txt', 'Wähle ReStoWa-Datei');
if isequal(filename, 0)
    disp('Abbruch durch Benutzer.');
    return;
end
filepath = fullfile(pathname, filename);
data = readtable(filepath);

%% === 2) Prüfen: benötigte Spalten vorhanden? ===
requiredCols = {'TimeStamp','LeftToe_PosY','LeftHeel_PosY','RightToe_PosY','RightHeel_PosY'};
for i = 1:numel(requiredCols)
    if ~ismember(requiredCols{i}, data.Properties.VariableNames)
        error('Spalte "%s" fehlt in der Datei.', requiredCols{i});
    end
end

%% === 3) Extrahieren ===
timeRaw = data.TimeStamp;
LTy     = data.LeftToe_PosY;
LHy     = data.LeftHeel_PosY;
RTy     = data.RightToe_PosY;
RHy     = data.RightHeel_PosY;

%% === 4) TimeStamp → Time_s (Sekunden ab Start) ===
if isdatetime(timeRaw)
    Time_s = seconds(timeRaw - timeRaw(1));
elseif isduration(timeRaw)
    Time_s = seconds(timeRaw - timeRaw(1));
else
    Time_s = double(timeRaw);
    Time_s = Time_s - Time_s(1);
end
Time_s = double(Time_s(:));

%% === 5) SampleIdx aus Time_s berechnen (fs = 100 Hz) ===
fs = 100; % Hz
SampleIdx = round(Time_s * fs) + 1;   % MATLAB-Indexierung

%% === 6) Neue Tabelle bauen ===
PosY_100Hz = table( ...
    SampleIdx, Time_s, LTy, LHy, RTy, RHy, ...
    'VariableNames', { ...
        'SampleIdx','Time_s', ...
        'LeftToe_PosY','LeftHeel_PosY', ...
        'RightToe_PosY','RightHeel_PosY'});

%% === 7) Speichern als TXT ===
[~, baseName, ~] = fileparts(filename);
outName = [baseName '_PosY_100Hz.txt'];
outPath = fullfile(pathname, outName);

writetable(PosY_100Hz, outPath, 'Delimiter', '\t');

fprintf('\n--- PosY + SampleIdx + Time_s (100 Hz) exportiert ---\n');
fprintf('Zeilen: %d\n', height(PosY_100Hz));
fprintf('Datei gespeichert unter:\n  %s\n\n', outPath);
end
