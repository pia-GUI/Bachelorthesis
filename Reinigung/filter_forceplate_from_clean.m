function fp_filtered = filter_forceplate_from_clean(filePath, fs, doplot)
    % Liest eine bereinigte D-Flow TXT-Datei (nach removeZero + clean) ein
    % und filtert NUR Forceplate-Signale (FP1_ForY, FP2_ForY) mit fs.
    %
    % INPUT:
    %   filePath - Pfad zur TXT-Datei (clean). Wenn leer -> uigetfile
    %   fs       - Abtastrate (Hz), Standard = 1000
    %   doplot   - 1 = Plotten, 0 = kein Plot (Standard)
    %
    % OUTPUT:
    %   fp_filtered - Tabelle mit TimeStamp, FrameNumber, FP1_filt, FP2_filt
    %
    % Speichert: *_Forceplate_4cols_filtered.txt im selben Ordner.

    %% --- 0) Argumente prüfen ---
    if nargin < 1 || isempty(filePath)
        [file, path] = uigetfile('*.txt', 'Wähle bereinigte TXT-Datei (clean)');
        if isequal(file,0), error('Keine Datei ausgewählt!'); end
        filePath = fullfile(path, file);
    end
    if nargin < 2 || isempty(fs),     fs     = 1000; end
    if nargin < 3 || isempty(doplot), doplot = 1;    end

    fprintf('   [FP] Lese bereinigte Datei: %s\n', filePath);

    %% --- 1) Daten einlesen ---
    T    = readtable(filePath, 'FileType', 'text', 'Delimiter', '\t');
    vars = T.Properties.VariableNames;

    %% --- 2) Zeit- und Frame-Spalten finden ---
    timeCandidates  = vars(contains(vars, 'TimeStamp'));
    frameCandidates = vars(contains(vars, 'FrameNumber'));

    if isempty(timeCandidates)
        error('[FP] Keine TimeStamp-Spalte gefunden in %s!', filePath);
    end
    if isempty(frameCandidates)
        error('[FP] Keine FrameNumber-Spalte gefunden in %s!', filePath);
    end

    timeCol  = timeCandidates{1};
    frameCol = frameCandidates{1};

    %% --- 3) Forceplate-Spalten automatisch finden ---
    % Annahme: Namen enthalten "FP1"/"FP2" und "ForY"
    fp1Candidates = vars(contains(vars, 'FP1') & contains(vars, 'ForY'));
    fp2Candidates = vars(contains(vars, 'FP2') & contains(vars, 'ForY'));

    if isempty(fp1Candidates) || isempty(fp2Candidates)
        error(['[FP] Konnte Forceplate-Spalten nicht finden.\n', ...
               'Verfügbare Spalten sind:\n%s'], strjoin(vars, ', '));
    end

    fp1Col = fp1Candidates{1};
    fp2Col = fp2Candidates{1};

    fprintf('   [FP] Verwende Spalten: %s (FP1), %s (FP2)\n', fp1Col, fp2Col);

    %% --- 4) Rohdaten holen ---
    t       = T.(timeCol);
    frame   = T.(frameCol);
    FP1_raw = T.(fp1Col);
    FP2_raw = T.(fp2Col);

    %% --- 5) Tiefpass-Filter (20 Hz, 4. Ordnung) ---
    fc    = 20;   % Grenzfrequenz (Hz)
    order = 4;    % Filterordnung
    [b, a] = butter(order, fc/(fs/2), 'low');

    FP1_filt = filtfilt(b, a, FP1_raw);
    FP2_filt = filtfilt(b, a, FP2_raw);

    %% --- 6) Output-Tabelle bauen ---
    fp_filtered = table(t, frame, FP1_filt, FP2_filt, ...
        'VariableNames', {timeCol, frameCol, fp1Col, fp2Col});

    %% --- 7) Datei speichern ---
    [folder, name] = fileparts(filePath);
    outname = fullfile(folder, [name '_Forceplate_4cols_filtered.txt']);
    writetable(fp_filtered, outname, 'Delimiter', '\t');
    fprintf('   [FP] Gefilterte Forceplate-Datei gespeichert unter: %s\n', outname);

    %% --- 8) Optional: Plot ---
    if doplot
        figure;
        subplot(2,1,1);
        plot(t, FP1_raw); hold on;
        plot(t, FP1_filt);
        xlabel('Zeit [s]'); ylabel(fp1Col);
        legend('roh','gefiltert');
        title('FP1 ForY');

        subplot(2,1,2);
        plot(t, FP2_raw); hold on;
        plot(t, FP2_filt);
        xlabel('Zeit [s]'); ylabel(fp2Col);
        legend('roh','gefiltert');
        title('FP2 ForY');
    end
end
