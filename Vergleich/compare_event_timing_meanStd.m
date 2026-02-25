function results = compare_event_timing_meanStd(markerFile, forceplateFile)
% Vergleicht Marker- vs Forceplate-Events (zeitlich):
% - gleiche Seite (R/L getrennt)
% - alle Marker-Events werden berücksichtigt (Nearest Neighbor in Forceplate)
% - diff = Marker - Forceplate
% - Ausgabe: MeanDiff_s, StdDiff_s
%
% Vergleichspaare:
%   HS (Marker) -> HS (Forceplate)
%   TS (Marker) -> LRP (Forceplate)   % WICHTIG: TS mit LRP
%   HO (Marker) -> HO (Forceplate)
%   TO (Marker) -> TO (Forceplate)

    if nargin < 2 || isempty(markerFile) || isempty(forceplateFile)
        [mf, p1] = uigetfile('*.txt', 'Wähle Marker-Event-Datei');
        if isequal(mf,0), results = table(); return; end
        [ff, p2] = uigetfile('*.txt', 'Wähle Forceplate-Event-Datei');
        if isequal(ff,0), results = table(); return; end
        markerFile     = fullfile(p1, mf);
        forceplateFile = fullfile(p2, ff);
    end

    M = readtable(markerFile,     'FileType','text','Delimiter','\t');
    F = readtable(forceplateFile, 'FileType','text','Delimiter','\t');

    req = {'Side','Event','Time_s'};
    assert(all(ismember(req, M.Properties.VariableNames)), 'Marker-Datei braucht Side, Event, Time_s');
    assert(all(ismember(req, F.Properties.VariableNames)), 'Forceplate-Datei braucht Side, Event, Time_s');

    % --- Clean strings ---
    M.Side  = upper(strtrim(string(M.Side)));
    M.Event = upper(strtrim(string(M.Event)));
    F.Side  = upper(strtrim(string(F.Side)));
    F.Event = upper(strtrim(string(F.Event)));

    % --- Time numeric ---
    M.Time_s = makeNumericTime(M.Time_s, 'Marker');
    F.Time_s = makeNumericTime(F.Time_s, 'Forceplate');

    sides = {'R','L'};

    % MarkerEvent -> ForceplateEvent
    comparePairs = {
        "HS", "HS"
        "TS", "LRP"  % TS wird mit LRP verglichen
        "HO", "HO"
        "TO", "TO"   % TO bleibt TO
    };

    results = table();

    for s = 1:numel(sides)
        side = sides{s};

        for k = 1:size(comparePairs,1)
            evM = comparePairs{k,1};
            evF = comparePairs{k,2};

            m_times = M.Time_s(M.Side==side & M.Event==evM);
            f_times = F.Time_s(F.Side==side & F.Event==evF);

            if isempty(m_times) || isempty(f_times)
                meanDiff = NaN;
                stdDiff  = NaN;
            else
                % --- Nearest-Neighbor-Matching: alle Marker-Events zählen ---
                diffs = zeros(numel(m_times),1);
                for i = 1:numel(m_times)
                    [~, idx] = min(abs(f_times - m_times(i)));
                    diffs(i) = m_times(i) - f_times(idx);
                end

                meanDiff = mean(diffs);
                stdDiff  = std(diffs);
            end

            results = [results; table( ...
                string(side), string(evM), string(evF), ...
                meanDiff, stdDiff, ...
                'VariableNames', {'Side','MarkerEvent','ForceEvent','MeanDiff_s','StdDiff_s'})]; %#ok<AGROW>
        end
    end
end

% ================= helper =================

function t = makeNumericTime(tcol, label)
    if isnumeric(tcol)
        t = double(tcol);
        return;
    end
    if iscell(tcol), tcol = string(tcol); end
    if isstring(tcol) || ischar(tcol)
        t = str2double(strtrim(string(tcol)));
    else
        t = double(tcol);
    end
    assert(all(isfinite(t)), '%s: Time_s konnte nicht sauber in Zahlen umgewandelt werden.', label);
end
