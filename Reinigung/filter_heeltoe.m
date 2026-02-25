function heeltoe_filtered = process_heeltoe_like_steps(filePath, fs, doplot)
    % Filtert Heel/Toe-Daten, berechnet Geschwindigkeit & Beschleunigung,
    % optional z-Transformation, danach Outlier-Korrektur.
    %
    % INPUT:
    %   filePath - Pfad zur TXT-Datei
    %   fs       - Abtastrate (Hz), Standard = 100
    %   doplot   - 1 = Plotten, 0 = Kein Plot
    %
    % OUTPUT:
    %   heeltoe_filtered - Tabelle mit pos, vy, ay (optional z-transformiert)

    %% --- 0) Argumente prüfen ---
    if nargin < 1 || isempty(filePath)
        [file, path] = uigetfile('*.txt', 'Wähle eine TXT-Datei aus');
        if isequal(file,0), error('Keine Datei ausgewählt!'); end
        filePath = fullfile(path, file);
    end
    if nargin < 2, fs = 100; end
    if nargin < 3, doplot = 0; end
    dt = 1/fs;

    apply_zscore = true;  % <== hier z-Transformation aktivieren/deaktivieren

    %% --- 1) Daten einlesen ---
    T = readtable(filePath);
    vars = T.Properties.VariableNames;
    time = []; if ismember('TimeStamp', vars), time = T.TimeStamp; else, time = (0:height(T)-1)'/fs; end
    heeltoe_filtered = table();
    heeltoe_filtered.TimeStamp = time;

    if ismember('FrameNumber', vars)
        heeltoe_filtered.FrameNumber = T.FrameNumber;
    end

    % Marker-Spalten finden
    markers = {'RightHeel','RightToe','LeftHeel','LeftToe'};
    components = {'PosX','PosY','PosZ'};
    selectedCols = {};
    for m = 1:length(markers)
        for c = 1:length(components)
            colName = [markers{m} '_' components{c}];
            if ismember(colName, vars)
                selectedCols{end+1} = colName; %#ok<AGROW>
            else
                warning('Spalte %s nicht gefunden!', colName);
            end
        end
    end

    %% --- 2) Tiefpass-Filter (z.B. 4 Hz) ---
    [b, a] = butter(4, 5/(fs/2), 'low');

    %% --- 3) Verarbeitung jeder Spur: Filter + Ableitungen + zscore ---
    for i = 1:length(selectedCols)
        col = selectedCols{i};
        sig_raw = T.(col);
        sig_filt = filtfilt(b, a, sig_raw);    % gefiltert

        vy = gradient(sig_filt, dt);           % 1. Ableitung
        ay = gradient(vy, dt);                 % 2. Ableitung

        % Spaltennamen
        baseName = erase(col, {'Right','Left'});  % z.B. Heel_PosY
        heeltoe_filtered.([col])     = sig_filt;
        heeltoe_filtered.([col '_vy']) = vy;
        heeltoe_filtered.([col '_ay']) = ay;
    end

   %% --- 4) Z-Transformation (nur PosY, vy und ay) ---
if apply_zscore
    colNames = heeltoe_filtered.Properties.VariableNames;

    for i = 1:length(colNames)
        col = colNames{i};
        if ismember(col, {'TimeStamp','FrameNumber'}), continue; end

        % Nur PosY, PosY_vy, PosY_ay z-transformieren
        if contains(col, 'PosY')
            sig = heeltoe_filtered.(col);
            mu = mean(sig, 'omitnan');
            sd = std(sig, 0, 'omitnan');
            if sd == 0 || isnan(sd)
                sig_z = zeros(size(sig));
            else
                sig_z = (sig - mu) / sd;
            end
            heeltoe_filtered.(col) = sig_z;
        end
    end
end

    %% --- 5) Outlier-Korrektur (nach zscore, falls aktiviert) ---
    colNames = heeltoe_filtered.Properties.VariableNames;
    for i = 1:length(colNames)
        if ismember(colNames{i}, {'TimeStamp','FrameNumber'}), continue; end
        sig = heeltoe_filtered.(colNames{i});
        [sig_out, TF] = filloutliers(sig,'linear','percentiles',[1 99]);
        if any(TF)
            heeltoe_filtered.(colNames{i}) = sig_out;
        end
    end

    %% --- 6) Datei speichern ---
    [folder, name] = fileparts(filePath);
    outname = fullfile(folder, [name '_Marker_filter.txt']);
    writetable(heeltoe_filtered, outname, 'Delimiter', '\t');
    fprintf('Gefilterte Datei gespeichert unter: %s\n', outname);
end
