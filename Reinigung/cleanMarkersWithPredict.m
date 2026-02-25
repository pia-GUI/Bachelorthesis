function markersClean = cleanMarkersWithPredict(markerData)
    % cleanMarkersWithPredict
    % Bereinigt Motion-Capture-Markerdaten von Nullwerten und Ausreißern.
    % Anschließend werden fehlende Werte (NaNs) mit PredictMissingMarkers
    % oder linearer Interpolation (Fallback) aufgefüllt.
    %
    % Eingabe:
    %   markerData – Matrix [Frames x Koordinaten] (z. B. Marker1X, Marker1Y, Marker1Z, ...)
    %
    % Ausgabe:
    %   markersClean – bereinigte und vervollständigte Markerdaten

    markers = markerData;
    nMarkers = size(markers, 2); % Anzahl der Spalten (Koordinaten)

    % --- 1) Nullwerte in NaN umwandeln ---
    % Für jede Marker-Gruppe (X,Y,Z) prüfen, ob alle 3 Werte = 0 sind.
    % Wenn ja, wird der gesamte Frame für diesen Marker auf NaN gesetzt.
    for i = 1:3:nMarkers-2
        zeroIdx = all(markers(:, i:i+2) == 0, 2);
        markers(zeroIdx, i:i+2) = NaN;
    end

    % --- 2) Ausreißer/Sprünge erkennen und auf NaN setzen ---
    % Wir nutzen eine robuste Outlier-Erkennung basierend auf movmedian.
    nullIdx2 = zeros(size(markers));
    for c = 1:3:nMarkers-2 % c = Startspalte des aktuellen Markers
        % NaNs beibehalten
        mocapDataOutl = markers;

        % Outlier-Detection mit gleitendem Median & ThresholdFactor
        outlierMask = isoutlier(mocapDataOutl(:, c:c+2), ...
                                'movmedian', size(mocapDataOutl, 1)/100, ...
                                1, "ThresholdFactor", 20);

        % Falls in einem Frame ein Outlier in X/Y/Z vorkommt, alle drei Achsen markieren
        for row = 1:size(outlierMask, 1)
            if any(outlierMask(row, :))
                outlierMask(row, :) = 1;
            end
        end
        nullIdx2(:, c:c+2) = outlierMask;
    end

    % Setze alle erkannten Ausreißer auf NaN
    markers(nullIdx2 == 1) = NaN;

    % --- 3) Interpolation fehlender Werte ---
    % PredictMissingMarkers, mit Fallback auf lineare Interpolation
    if any(isnan(markers(:)))
        try
            markersClean = PredictMissingMarkers(markers, 'Algorithm', 2);
        catch ME
            warning(['PredictMissingMarkers Fehler: ' ME.message]);
            markersClean = fillmissing(markers, 'linear'); % Fallback
        end
    else
        markersClean = markers; % Keine NaNs -> keine Interpolation notwendig
    end
end
