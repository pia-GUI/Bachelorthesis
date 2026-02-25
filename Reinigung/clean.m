function grailData = cleanGrailTxt(filePath)
    % cleanGrailTxt
    % Lädt und bereinigt Marker- und Forceplate-Daten aus einer D-Flow TXT-Datei
    % Entfernt Spalten, die nur Nullen enthalten (Marker & Forceplate)
    % Behält TimeStamp und FrameNumber


    %% 1) Dateiauswahl
    if nargin < 1 || isempty(filePath)
        [file, path] = uigetfile('*.txt', 'Wähle eine D-Flow TXT-Datei aus');
        if isequal(file,0)
            error('Keine Datei ausgewählt!');
        end
        filePath = fullfile(path, file);
    end

    if exist(filePath, 'file') ~= 2
        error('Die Datei "%s" wurde nicht gefunden.', filePath);
    end

    %% 2) Header auslesen
    fid = fopen(filePath,'r');
    headerLine = fgetl(fid);
    fclose(fid);
    headers = strsplit(headerLine,'\t');
    headers = strtrim(headers);

    %% 3) Datenmatrix einlesen
    rawData = dlmread(filePath,'\t',1,0);
    time = rawData(:,1);             % TimeStamp
    frameNumber = rawData(:,2);      % FrameNumber
    data = rawData(:,3:end);         % Rest: Marker + Forceplate

    %% 4) Marker-Spalten finden
    markerIdx = find(~cellfun('isempty', regexp(headers, '.*\.Pos[XYZ]$')));
    markerLabels = headers(markerIdx);
    markerData = data(:, markerIdx - 2);  % -2 wegen TimeStamp & FrameNumber

    % % --- Nullspalten entfernen ---
    % nonZeroCols = any(markerData ~= 0, 1);
    % markerData = markerData(:, nonZeroCols);
    % markerLabels = markerLabels(nonZeroCols);

    %% 5) Forceplate-Spalten finden
    fpIdx = find(~cellfun('isempty', regexp(headers, '^FP[12]\..*')));
    fpLabels = headers(fpIdx);
    fpData = data(:, fpIdx - 2);  % -2 wegen TimeStamp & FrameNumber

    % % --- Nullspalten entfernen ---
    % nonZeroColsFP = any(fpData ~= 0, 1);
    % fpData = fpData(:, nonZeroColsFP);
    % fpLabels = fpLabels(nonZeroColsFP);

    %% 6) Marker-Daten bereinigen
    markerDataClean = cleanMarkersWithPredict(markerData);

    %% 7) Forceplate-Daten bereinigen
    fpDataClean = fillmissing(fpData,'linear');  
    fpDataClean = movmean(fpDataClean,5);        

    %% 8) Struktur erstellen
    grailData.time = time;
    grailData.frameNumber = frameNumber;
    grailData.marker.labels = markerLabels;
    grailData.marker.data = markerDataClean;
    grailData.force.labels = fpLabels;
    grailData.force.data = fpDataClean;
    
    %% 10) Speichern
    assignin('base', 'grailData', grailData);
    T = array2table([time, frameNumber, grailData.marker.data, grailData.force.data], ...
        'VariableNames', ['TimeStamp', 'FrameNumber', grailData.marker.labels, grailData.force.labels]);

    [folder, name, ~] = fileparts(filePath);
    cleanFile = fullfile(folder, [name '_clean.txt']);
    writetable(T, cleanFile, 'Delimiter', '\t'); 

    disp(['Bereinigte Daten wurden als TXT gespeichert: ' cleanFile]);
end
