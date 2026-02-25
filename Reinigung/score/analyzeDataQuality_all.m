function stats = analyzeDataQuality_all(data, varargin)
% analyzeDataQuality_all.m  (eine Datei, eine Funktion)
% Aufruf:
%   stats = analyzeDataQuality_all();            % öffnet Dialog, liest TXT (Tab) und analysiert
%   stats = analyzeDataQuality_all(T);           % analysiert vorhandene Tabelle/Matrix T
%   stats = analyzeDataQuality_all(T, 'ShowWorst', 10, 'OutlierThreshold', 20);

% ---------- Modus: ohne Input -> Datei wählen & einlesen ----------
if nargin == 0 || isempty(data)
    [file, path] = uigetfile('*.txt', 'Wähle eine TXT-Datei aus');
    if isequal(file, 0)
        error('Keine Datei ausgewählt!');
    end
    filePath = fullfile(path, file);

    % Robust einlesen (Tab-Delimiter) und Strings -> numerisch (Dezimalkomma)
    try
        opts = detectImportOptions(filePath, 'FileType', 'text', 'Delimiter', '\t');
        opts = setvaropts(opts, opts.VariableNames, ...
            'TreatAsMissing', {'NA','NaN','nan',''}, ...
            'WhitespaceRule', 'preserve', ...
            'EmptyFieldRule', 'auto');
        opts = setvartype(opts, opts.VariableNames, 'string');
        Traw = readtable(filePath, opts);
    catch ME
        warning('Lesen mit ImportOptions fehlgeschlagen (%s). Fallback ...', ME.message);
        Traw = readtable(filePath, 'Delimiter', '\t', 'TextType', 'string');
    end

    % Strings -> Zahlen (Komma zu Punkt)
    T = Traw;
    vn = T.Properties.VariableNames;
    for i = 1:numel(vn)
        col = T.(vn{i});
        if isstring(col) || iscellstr(col) || ischar(col)
            s = string(col);
            s = replace(s, ",", ".");
            s = strtrim(s);
            s(s=="") = missing;
            x = str2double(s);
            if any(~isnan(x)) && ~all(isnan(x))
                T.(vn{i}) = x;
            end
        end
    end

    data = T;  % ab hier weiter wie mit Input
end

% ---------- Parameter ----------
p = inputParser;
addParameter(p, 'ShowWorst', 8, @(x) isnumeric(x) && isscalar(x) && x>=0);
addParameter(p, 'OutlierWindow', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x>=3));
addParameter(p, 'OutlierThreshold', 20, @(x) isnumeric(x) && isscalar(x) && x>0);
parse(p, varargin{:});
ShowWorst        = p.Results.ShowWorst;
OutlierThreshold = p.Results.OutlierThreshold;

% ---------- Daten vorbereiten ----------
if istable(data) || istimetable(data)
    varNames = data.Properties.VariableNames;
    probeN = min(5, height(data));
    isNum = varfun(@(x) isnumeric(x) || islogical(x), data(1:max(probeN,1),:), 'OutputFormat','uniform');
    numVars = varNames(isNum);
    if isempty(numVars)
        error('Keine numerischen Spalten gefunden.');
    end
    Dmat = data{:, numVars};
    colNames = numVars;
else
    if ~isnumeric(data)
        error('Wenn keine Tabelle: erwarte numerische Matrix.');
    end
    Dmat = data;
    colNames = arrayfun(@(i) sprintf('Var%d', i), 1:size(Dmat,2), 'UniformOutput', false);
end

N = size(Dmat,1);
M = size(Dmat,2);
if N < 3
    error('Zu wenige Zeilen (N<3).');
end
win = p.Results.OutlierWindow;
if isempty(win)
    win = max(5, floor(N/100));
end

% ---------- 1) NaN-Frames ----------
nan_rows = any(isnan(Dmat), 2);
anz_nan_frames = sum(nan_rows);

% ---------- 2) Nullwerte ----------
zero_mask = (Dmat == 0);
anz_zero_total = sum(zero_mask(:));

% ---------- 3) Ausreißer/Sprünge ----------
DTmp = Dmat;
DTmp(DTmp == 0) = NaN;                      % 0 als fehlend behandeln
outlier_mask = false(size(DTmp));
for j = 1:M
    x = DTmp(:,j);
    if all(isnan(x)), continue; end
    try
        outj = isoutlier(x, 'movmedian', win, 'ThresholdFactor', OutlierThreshold);
    catch
        outj = isoutlier(x, 'median', 'ThresholdFactor', OutlierThreshold);
    end
    outlier_mask(:,j) = outj;
end
anz_outlier_total = sum(outlier_mask(:));

% ---------- 4) Raten + Score ----------
nan_rate_frames = anz_nan_frames / N;
zero_rate_vals  = anz_zero_total / numel(Dmat);
out_rate_vals   = anz_outlier_total / numel(Dmat);

raw_score = 100 - (0.4*nan_rate_frames + 0.3*out_rate_vals + 0.3*zero_rate_vals)*100;
score = max(min(raw_score, 100), 0);

% ---------- 5) Pro-Spalte ----------
perVar.nan_count   = sum(isnan(Dmat), 1);
perVar.zero_count  = sum(Dmat == 0, 1);
perVar.out_count   = sum(outlier_mask, 1);
perVar.total       = N;
perVar.nan_rate    = perVar.nan_count / N;
perVar.zero_rate   = perVar.zero_count / N;
perVar.out_rate    = perVar.out_count / N;
perVar.badness     = 0.4*perVar.nan_rate + 0.3*perVar.out_rate + 0.3*perVar.zero_rate;

[bad_sorted, idx_sorted] = sort(perVar.badness, 'descend');

% ---------- 6) Ausgabe ----------
fprintf('\n📊 Zusammenfassung (gesamt, %d Zeilen × %d Spalten):\n', N, M);
fprintf('🔷 Frames mit fehlenden Werten (NaN in mind. einer Spalte): %d (%.2f %%)\n', ...
        anz_nan_frames, 100*nan_rate_frames);
fprintf('🔵 Ausreißer/Sprünge (gesamt über alle Werte):              %d (%.4f %%)\n', ...
        anz_outlier_total, 100*out_rate_vals);
fprintf('🔹 Exakt 0-Werte (gesamt über alle Werte):                  %d (%.4f %%)\n', ...
        anz_zero_total, 100*zero_rate_vals);

fprintf('\n📈 Datenqualitäts-Score: %.2f %%\n', score);
if score > 85
    disp('🟢 Sehr gute Datenqualität!');
elseif score > 60
    disp('🟡 Mittlere Qualität – kleinere Probleme vorhanden.');
else
    disp('🔴 Schlechte Datenqualität – bitte überprüfen!');
end

end
