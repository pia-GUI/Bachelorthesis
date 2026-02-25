function removeZeroColumns(filePath)
    % removeZeroColumns_onlyZero
    % Liest eine TXT-Datei ein, entfernt Spalten, die ausschließlich Nullen enthalten,
    % und speichert eine neue TXT-Datei.

    %% 1) Datei wählen
    if nargin < 1 || isempty(filePath)
        [file, path] = uigetfile('*.txt', 'Wähle eine TXT-Datei aus');
        if isequal(file, 0)
            error('Keine Datei ausgewählt!');
        end
        filePath = fullfile(path, file);
    end

    %% 2) Header einlesen
    fid = fopen(filePath, 'r');
    headerLine = fgetl(fid);
    fclose(fid);
    headers = strsplit(strtrim(headerLine), '\t');

    %% 3) Daten einlesen
    data = dlmread(filePath, '\t', 1, 0);

    %% 4) Spalten entfernen, die nur Nullen enthalten
    keepCols = true(1, size(data, 2));
    for c = 1:size(data, 2)
        if all(data(:, c) == 0) % nur echte Null-Spalten
            keepCols(c) = false;
        end
    end

    dataClean = data(:, keepCols);
    headersClean = headers(keepCols);

    %% 5) Neue Datei speichern
    [folder, name, ~] = fileparts(filePath);
    newFile = fullfile(folder, [name '_removeZero.txt']);

    T = array2table(dataClean, 'VariableNames', headersClean);
    writetable(T, newFile, 'Delimiter', '\t');

    disp(['Bereinigte Datei gespeichert: ' newFile]);
end

