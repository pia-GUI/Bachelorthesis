function process_grail_data(fs_marker, fs_forceplate)
    % PROCESS_GRAIL_DATA
    % Pipeline:
    %   1. removeZero
    %   2. clean        -> bereinigte Datei (Marker + Forceplate)
    %   3. filter_heeltoe                (Marker bei fs_marker, z.B. 100 Hz)
    %  (4. filter_forceplate_from_clean  (Forceplate bei fs_forceplate,
    %   z.B. 1000 Hz))
    %   5. FINAL: letzter Stand aller Daten in eine TXT
    
    %% --- 1) Datei wählen ---
    [file, path] = uigetfile('*.txt', 'Wähle eine D-Flow TXT-Datei aus');
    if isequal(file,0)
        error('Keine Datei ausgewählt!');
    end
    filePath = fullfile(path, file);

    % Default-Samplingraten
    if nargin < 1 || isempty(fs_marker)
        fs_marker = 100;    % Marker
    end
    if nargin < 2 || isempty(fs_forceplate)
        fs_forceplate = 1000; % Forceplate
    end

    [folder, name, ~] = fileparts(filePath);
    fprintf('--- Starte Verarbeitung von: %s ---\n', filePath);

    %% --- 2) removeZeroColumns ---
    fprintf('Schritt 1: Entferne Null-Spalten...\n');
    removeZero(filePath);  % Speichert automatisch "_removeZero.txt"
    step1File = fullfile(folder, [name '_removeZero.txt']);
    if ~isfile(step1File)
        error('Datei %s wurde nicht gefunden!', step1File);
    end
    fprintf('Datei nach Schritt 1: %s\n', step1File);

    %% --- 3) cleanGrailTxt / clean ---
    fprintf('Schritt 2: Bereinige Marker- und Forceplate-Daten...\n');
    clean(step1File);  % Speichert automatisch "_removeZero_clean.txt" (oder *_clean.txt)
    step2File = fullfile(folder, [name '_removeZero_clean.txt']);
    if ~isfile(step2File)
        % Falls ein anderer Name gespeichert wurde
        allTxt = dir(fullfile(folder, '*_clean.txt'));
        if ~isempty(allTxt)
            step2File = fullfile(allTxt(1).folder, allTxt(1).name);
        else
            error('Bereinigte Datei wurde nicht gefunden!');
        end
    end
    fprintf('Datei nach Schritt 2 (bereinigt): %s\n', step2File);

    %% --- 4) Marker filtern (100 Hz) ---
    fprintf('Schritt 3: Filtere Heel/Toe-Daten (Marker) bei %.1f Hz...\n', fs_marker);
    % Wichtig: filter_heeltoe schreibt selbst eine *_filter.txt
    filter_heeltoe(step2File, fs_marker);

    % %% --- 5) Forceplate separat filtern (1000 Hz) ---
    % fprintf('Schritt 4: Filtere Forceplate-Daten bei %.1f Hz...\n', fs_forceplate);
    % % Wichtig: filter_forceplate_from_clean schreibt *_Forceplate_4cols_filtered.txt
    % filter_forceplate_from_clean(step2File, fs_forceplate);

    %% --- 6) FINAL: letzter Stand aller Daten in eine Datei schreiben ---
    fprintf('Schritt 5: Erstelle finale Datei mit letztem Stand aller Daten...\n');

    % Basis: bereinigte Datei (clean)
    T_final = readtable(step2File, 'FileType', 'text', 'Delimiter', '\t');

    % Dateinamen der Filter-Dateien bestimmen
    [cleanFolder, cleanName, ~] = fileparts(step2File);
    markerFilterFile = fullfile(cleanFolder, [cleanName '_Marker_filter.txt']);
    fpFilterFile     = fullfile(cleanFolder, [cleanName '_Forceplate_4cols_filtered.txt']);

    %% 6a) Marker-Filterdaten einbauen (Spalten 3..end ersetzen/ergänzen)
    if isfile(markerFilterFile)
        T_marker    = readtable(markerFilterFile, 'FileType', 'text', 'Delimiter', '\t');
        vars_marker = T_marker.Properties.VariableNames;

        if height(T_marker) ~= height(T_final)
            warning('Marker-Filterdatei hat %d Zeilen, clean-Datei %d. Marker werden NICHT gemerged.', ...
                height(T_marker), height(T_final));
        else
            for k = 3:numel(vars_marker)
                v = vars_marker{k};
                % einfach zuweisen: überschreibt vorhandene Spalten oder fügt neue hinzu
                T_final.(v) = T_marker.(v);
            end
        end
    else
        warning('Marker-Filterdatei nicht gefunden: %s', markerFilterFile);
    end

    % %% 6b) Forceplate-Filterdaten einbauen (Spalten 3..end ersetzen/ergänzen)
    % if isfile(fpFilterFile)
    %     T_fp     = readtable(fpFilterFile, 'FileType', 'text', 'Delimiter', '\t');
    %     vars_fp  = T_fp.Properties.VariableNames;
    % 
    %     if height(T_fp) ~= height(T_final)
    %         warning('Forceplate-Filterdatei hat %d Zeilen, clean-Datei %d. Forceplate wird NICHT gemerged.', ...
    %             height(T_fp), height(T_final));
    %     else
    %         for k = 3:numel(vars_fp)
    %             v = vars_fp{k};
    %             T_final.(v) = T_fp.(v);
    %         end
    %     end
    % else
    %     warning('Forceplate-Filterdatei nicht gefunden: %s', fpFilterFile);
    % end

    %% Finale Datei schreiben (auf Basis des ursprünglichen Namens)
    finalFile = fullfile(folder, [name '_FINAL_allData.txt']);
    writetable(T_final, finalFile, 'Delimiter', '\t');

    fprintf('--- Verarbeitung abgeschlossen! ---\n');
    fprintf('Finale Datei (letzter Stand) gespeichert unter:\n%s\n', finalFile);
end
