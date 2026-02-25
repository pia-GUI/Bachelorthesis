function detect_forceplate_HS_LRP_HO_TO()
%  - HS/TO via 10N-Schwelle aus ForY
%  - HO via Caderby (segmentiert nach HS/TO) -> benötigt detect_Caderby_HO_segmented.m
%  - LRP = erster Peak in Standphase -> benötigt detect_LRP_firstPeak.m
%  - Zusätzliche Kennwerte (Stride/Step Zeiten + optional Längen) kompakt wie in deinem Beispiel
%
% Zahradka et al. (2020), Sensors
% Zeni et al. (2008), Gait & Posture
% Ghoussayni et al. (2004), Gait & Posture
% Ben-Gal et al. (2020), Journal of Biomechanics

    %% === Parameter ===
    thresh = 10;       % N
    window = 10;       % Sekunden pro Ansicht im Plot

    % Gehgeschwindigkeit (m/s) für Längen
    v = 0.8;            % <- hier anpassen (oder später aus Datei/GUI)
    % Wenn du KEINE Längen willst: v = NaN;

    %% === Datei wählen ===
    [file, path] = uigetfile('*.txt', 'Wähle Kraftplatten-Datei');
    if isequal(file,0)
        disp('Abbruch durch Benutzer.');
        return;
    end
    filepath = fullfile(path, file);
    fprintf('\nLese Datei: %s\n', file);

    %% === Daten einlesen ===
    T = readtable(filepath);
    vars = T.Properties.VariableNames;

    time_col = find(contains(vars, 'Time', 'IgnoreCase', true), 1);
    Fy_cols  = find(contains(vars, 'ForY', 'IgnoreCase', true));
    Fz_cols  = find(contains(vars, 'ForZ', 'IgnoreCase', true));

    if isempty(time_col) || numel(Fy_cols) < 2
        error('Es müssen mindestens zwei ForY-Spalten und eine Time-Spalte enthalten sein!');
    end
    if numel(Fz_cols) < 2
        error('Es müssen mindestens zwei ForZ-Spalten vorhanden sein!');
    end

    t  = T{:, time_col};
    y1 = T{:, Fy_cols(1)}; % links (FP1)
    y2 = T{:, Fy_cols(2)}; % rechts (FP2)

    Fz1 = T{:, Fz_cols(1)}; % links
    Fz2 = T{:, Fz_cols(2)}; % rechts

    %% === Events bestimmen (HS & TO) ===
    events = cell(1,2);
    for s = 1:2
        Fy = (s == 1) * y1 + (s == 2) * y2;

        contact = Fy > thresh;

        HS_idx = find(diff(contact) == 1) + 1;  % HS
        TO_idx = find(diff(contact) == -1);     % TO

        % Falls TO vor HS auftritt → löschen
        if ~isempty(TO_idx) && ~isempty(HS_idx) && TO_idx(1) < HS_idx(1)
            TO_idx(1) = [];
        end

        % auf gleiche Anzahl kürzen
        n = min(numel(HS_idx), numel(TO_idx));
        HS_idx = HS_idx(1:n);
        TO_idx = TO_idx(1:n);

        events{s}.Fy = Fy;
        events{s}.HS_idx = HS_idx; events{s}.HS_time = t(HS_idx);
        events{s}.TO_idx = TO_idx; events{s}.TO_time = t(TO_idx);
    end

    %% === HO bestimmen (Caderby, segmentiert nach HS/TO) ===
    fs = 1/mean(diff(t));

    t_rel0 = t - t(1);
    baseMask = t_rel0 < 1; % anpassen falls nötig
    BW1 = mean(Fz1(baseMask));
    BW2 = mean(Fz2(baseMask));

    evL = events{1};
    evR = events{2};

    HO_L = detect_Caderby_HO_segmented(t, Fz1, BW1, fs, evL.HS_idx, evL.TO_idx);
    HO_R = detect_Caderby_HO_segmented(t, Fz2, BW2, fs, evR.HS_idx, evR.TO_idx);

    evL.HO_idx = HO_L.idx; evL.HO_time = HO_L.time;
    evR.HO_idx = HO_R.idx; evR.HO_time = HO_R.time;

    events{1} = evL;
    events{2} = evR;

    %% === LRP (Loading Response Peak) pro Seite bestimmen ===
    evL = events{1};
    evR = events{2};

    LRP_L = detect_LRP(t, y1, evL.HS_idx, evL.TO_idx);
    LRP_R = detect_LRP(t, y2, evR.HS_idx, evR.TO_idx);

    evL.LRP_idx  = LRP_L.idx;  evL.LRP_time = LRP_L.time;
    evR.LRP_idx  = LRP_R.idx;  evR.LRP_time = LRP_R.time;

    events{1} = evL;
    events{2} = evR;

    %% =========================================================
    %% === GAIT-STATS (kompakt, ohne Hilfsfunktionen) ==========
    % Rechts = R, Links = L
    HS_t   = events{2}.HS_time(:);   % R
    HS_t_L = events{1}.HS_time(:);   % L

    m = @(x) mean(x,'omitnan');
    s = @(x) std(x,'omitnan');

    fprintf('\n--- GAIT STATS (aus HS) ---\n');
    fprintf('Gefundene Heel Strikes (R/L): %d / %d\n', numel(HS_t), numel(HS_t_L));
    fprintf('Gefundene Heel Offs   (R/L): %d / %d\n', numel(events{2}.HO_time), numel(events{1}.HO_time));

    % --------- ZEITEN zuerst berechnen ---------
    % Stride-Zeiten (HS -> HS)
    if numel(HS_t)   >= 2, strideTimes_R = diff(HS_t);   else, strideTimes_R = []; end
    if numel(HS_t_L) >= 2, strideTimes_L = diff(HS_t_L); else, strideTimes_L = []; end
    allStrideTimes = [strideTimes_R; strideTimes_L];

    % Step-Zeiten (R -> L)
    stepTimes_RL = [];
    if ~isempty(HS_t) && ~isempty(HS_t_L)
        j = 1;
        for i = 1:numel(HS_t)
            while j <= numel(HS_t_L) && HS_t_L(j) <= HS_t(i), j = j + 1; end
            if j <= numel(HS_t_L), stepTimes_RL(end+1,1) = HS_t_L(j) - HS_t(i); end %#ok<SAGROW>
        end
    end

    % Step-Zeiten (L -> R)
    stepTimes_LR = [];
    if ~isempty(HS_t) && ~isempty(HS_t_L)
        j = 1;
        for i = 1:numel(HS_t_L)
            while j <= numel(HS_t) && HS_t(j) <= HS_t_L(i), j = j + 1; end
            if j <= numel(HS_t), stepTimes_LR(end+1,1) = HS_t(j) - HS_t_L(i); end %#ok<SAGROW>
        end
    end
    allStepTimes = [stepTimes_RL; stepTimes_LR];

    % --------- AUSGABEN: Schrittdauern ---------
    if ~isempty(strideTimes_R)
        fprintf('Stridedauer (R→R): Mittel = %.3f s, SD = %.3f s, n = %d\n', m(strideTimes_R), s(strideTimes_R), numel(strideTimes_R));
    else
        fprintf('Stridedauer (R→R): zu wenige HS (n<2)\n');
    end
    if ~isempty(strideTimes_L)
        fprintf('Stridedauer (L→L): Mittel = %.3f s, SD = %.3f s, n = %d\n', m(strideTimes_L), s(strideTimes_L), numel(strideTimes_L));
    else
        fprintf('Stridedauer (L→L): zu wenige HS (n<2)\n');
    end
    if ~isempty(allStrideTimes)
        fprintf('Stridedauer gesamt (Strides): Mittel = %.3f s, SD = %.3f s, n = %d\n', m(allStrideTimes), s(allStrideTimes), numel(allStrideTimes));
    end

    if ~isempty(stepTimes_RL)
        fprintf('Schrittdauer R→L: Mittel = %.3f s, SD = %.3f s, n = %d\n', m(stepTimes_RL), s(stepTimes_RL), numel(stepTimes_RL));
    else
        fprintf('Schrittdauer R→L: keine Paare gefunden\n');
    end
    if ~isempty(stepTimes_LR)
        fprintf('Schrittdauer L→R: Mittel = %.3f s, SD = %.3f s, n = %d\n', m(stepTimes_LR), s(stepTimes_LR), numel(stepTimes_LR));
    else
        fprintf('Schrittdauer L→R: keine Paare gefunden\n');
    end
    if ~isempty(allStepTimes)
        fprintf('Schrittdauer gesamt (Steps): Mittel = %.3f s, SD = %.3f s, n = %d\n', m(allStepTimes), s(allStepTimes), numel(allStepTimes));
        fprintf('Kadenz: %.1f Schritte/min\n', 60/m(allStepTimes));
    end

    % --------- LÄNGEN aus ZEITEN berechnen & ausgeben ---------
    if ~isnan(v)
        % Stride-Längen
        strideLen_R = v * strideTimes_R;
        strideLen_L = v * strideTimes_L;
        allStrideLen = [strideLen_R; strideLen_L];

        if ~isempty(strideLen_R)
            fprintf('Stridelänge R→R: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(strideLen_R), s(strideLen_R), numel(strideLen_R));
        else
            fprintf('Stridelänge R→R: zu wenige HS (n<2)\n');
        end
        if ~isempty(strideLen_L)
            fprintf('Stridelänge L→L: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(strideLen_L), s(strideLen_L), numel(strideLen_L));
        else
            fprintf('Stridelänge L→L: zu wenige HS (n<2)\n');
        end
        if ~isempty(allStrideLen)
            fprintf('Stridelänge gesamt: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(allStrideLen), s(allStrideLen), numel(allStrideLen));
        end

        % Step-Längen
        stepLen_RL = v * stepTimes_RL;
        stepLen_LR = v * stepTimes_LR;
        allStepLen = [stepLen_RL; stepLen_LR];

        if ~isempty(stepLen_RL)
            fprintf('Schrittlänge R→L: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(stepLen_RL), s(stepLen_RL), numel(stepLen_RL));
        else
            fprintf('Schrittlänge R→L: keine Paare gefunden\n');
        end
        if ~isempty(stepLen_LR)
            fprintf('Schrittlänge L→R: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(stepLen_LR), s(stepLen_LR), numel(stepLen_LR));
        else
            fprintf('Schrittlänge L→R: keine Paare gefunden\n');
        end
        if ~isempty(allStepLen)
            fprintf('Schrittlänge gesamt: Mittel = %.3f m, SD = %.3f m, n = %d\n', m(allStepLen), s(allStepLen), numel(allStepLen));
        end
    else
        % falls v = NaN
        strideLen_R = []; strideLen_L = []; allStrideLen = [];
        stepLen_RL  = []; stepLen_LR  = []; allStepLen  = [];
        fprintf('Schritt-/Stridelängen: übersprungen (v = NaN)\n');
    end

    %% === Aggregierte Kennwerte in den Workspace (ohne Rohzeitpunkte) ===
    % Sicherstellen, dass Kombi-Arrays existieren
    if ~exist('allStrideTimes','var'), allStrideTimes = [strideTimes_R; strideTimes_L]; end
    if ~exist('allStepTimes','var'),   allStepTimes   = [stepTimes_RL;  stepTimes_LR];  end
    if ~exist('allStrideLen','var'),   allStrideLen   = [strideLen_R;    strideLen_L];   end
    if ~exist('allStepLen','var'),     allStepLen     = [stepLen_RL;     stepLen_LR];    end

    pairs = {
      'strideTime_R',           strideTimes_R;
      'strideTime_L',           strideTimes_L;
      'strideTime_all_strides', allStrideTimes;

      'stepTime_RL',            stepTimes_RL;
      'stepTime_LR',            stepTimes_LR;
      'stepTime_all',           allStepTimes;

      'strideLen_R',            strideLen_R;
      'strideLen_L',            strideLen_L;
      'strideLen_all',          allStrideLen;

      'stepLen_RL',             stepLen_RL;
      'stepLen_LR',             stepLen_LR;
      'stepLen_all',            allStepLen
    };

    for i = 1:size(pairs,1)
        name = pairs{i,1};
        x    = pairs{i,2};
        if isempty(x)
            mu = NaN; sdv = NaN; n = 0;
        else
            mu = m(x); sdv = s(x); n = numel(x);
        end
        assignin('base', [name '_mean'], mu);
        assignin('base', [name '_sd'],   sdv);
        assignin('base', [name '_n'],    n);
    end

    if ~isempty(allStepTimes)
        assignin('base','cadence_spm', 60/m(allStepTimes));
    else
        assignin('base','cadence_spm', NaN);
    end

    %% =========================================================
    %% === Plot ===
    t_rel = t - t(1);

    f = figure('Name', 'Forceplate Y-Kräfte + HO (Caderby) + LRP (scrollbar)', ...
               'NumberTitle', 'off');
    hold on; grid on;

    plot(t_rel, y1, 'b', 'DisplayName','FP1_ForY (links)');
    plot(t_rel, y2, 'r', 'DisplayName','FP2_ForY (rechts)');

    lbl = {'links','rechts'};
    col = {'b','r'};

 mHS  = '^';   % HS: Dreieck nach oben
mTO  = 'v';   % TO: Dreieck nach unten
mHO  = 'o';   % HO: Kreis
mLRP = 's';   % LRP: Kästchen


    for k = 1:2
        ev = events{k};
        c  = col{k};

        if ~isempty(ev.HS_idx)
            plot(t_rel(ev.HS_idx), ev.Fy(ev.HS_idx), mHS, ...
                'Color', c, 'MarkerFaceColor', c, ...
                'DisplayName', ['HS ' lbl{k}]);
        end

        if ~isempty(ev.TO_idx)
            plot(t_rel(ev.TO_idx), ev.Fy(ev.TO_idx), mTO, ...
                'Color', c, 'MarkerFaceColor', c, ...
                'DisplayName', ['TO ' lbl{k}]);
        end
    end

    if ~isempty(HO_L.idx)
        plot(t_rel(HO_L.idx), y1(HO_L.idx), mHO, ...
            'Color','b', 'MarkerFaceColor','b', 'MarkerSize',8, ...
            'DisplayName','HO links (Caderby)');
    end
    if ~isempty(HO_R.idx)
        plot(t_rel(HO_R.idx), y2(HO_R.idx), mHO, ...
            'Color','r', 'MarkerFaceColor','r', 'MarkerSize',8, ...
            'DisplayName','HO rechts (Caderby)');
    end

    evL = events{1};
    evR = events{2};

    if ~isempty(evL.LRP_idx)
        plot(t_rel(evL.LRP_idx), y1(evL.LRP_idx), mLRP, ...
            'Color','b','MarkerFaceColor','b','DisplayName','LRP links');
    end
    if ~isempty(evR.LRP_idx)
        plot(t_rel(evR.LRP_idx), y2(evR.LRP_idx), mLRP, ...
            'Color','r','MarkerFaceColor','r','DisplayName','LRP rechts');
    end

    xlabel('Time [s]');
    ylabel('Force Y [N]');
    title('Forceplate Y-Kräfte mit HS/TO/HO und LRP, 10s scrollbar');
    % --- Handles sammeln ---
h = findobj(gca,'Type','line');
h = flipud(h); % Reihenfolge korrigieren

legend(h, ...
    {'FP1 ForY (links)','FP2 ForY (rechts)' ...
    'HS links','HS rechts', ...
     'TO links','TO rechts', ...
     'HO links','HO rechts', ...
     'LRP links','LRP rechts'}, ...
     'Location','best');

    legend('Location','best');
    xlim([t_rel(1) min(t_rel(1)+window, t_rel(end))]);

    ax = gca;

    sld = uicontrol('Parent', f, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.08 0.05 0.9 0.05], ...
        'Min', t_rel(1), ...
        'Max', max(t_rel(end)-window, t_rel(1)), ...
        'Value', t_rel(1));

    txt = uicontrol('Parent', f, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.08 0.11 0.25 0.04], ...
        'String', sprintf('t = %.2f s', t_rel(1)), ...
        'HorizontalAlignment','left');

    sld.Callback = @(src,evt) slider_cb(src, ax, txt, window);

    %% === Events speichern (HS/HO/LRP/TO) ===
    evL = events{1}; evR = events{2};

    if ~isfield(evL,'LRP_idx'), evL.LRP_idx=[]; evL.LRP_time=[]; end
    if ~isfield(evR,'LRP_idx'), evR.LRP_idx=[]; evR.LRP_time=[]; end

    Side = [repmat({'L'}, numel(evL.HS_idx)+numel(evL.HO_idx)+numel(evL.LRP_idx)+numel(evL.TO_idx),1); ...
            repmat({'R'}, numel(evR.HS_idx)+numel(evR.HO_idx)+numel(evR.LRP_idx)+numel(evR.TO_idx),1)];

    Event = [repmat({'HS'},  numel(evL.HS_idx),1); ...
             repmat({'HO'},  numel(evL.HO_idx),1); ...
             repmat({'LRP'}, numel(evL.LRP_idx),1); ...
             repmat({'TO'},  numel(evL.TO_idx),1); ...
             repmat({'HS'},  numel(evR.HS_idx),1); ...
             repmat({'HO'},  numel(evR.HO_idx),1); ...
             repmat({'LRP'}, numel(evR.LRP_idx),1); ...
             repmat({'TO'},  numel(evR.TO_idx),1)];

    SampleIdx = [evL.HS_idx(:); evL.HO_idx(:); evL.LRP_idx(:); evL.TO_idx(:); ...
                 evR.HS_idx(:); evR.HO_idx(:); evR.LRP_idx(:); evR.TO_idx(:)];

    Time_s = [evL.HS_time(:); evL.HO_time(:); evL.LRP_time(:); evL.TO_time(:); ...
              evR.HS_time(:); evR.HO_time(:); evR.LRP_time(:); evR.TO_time(:)];

    Source = repmat({'Forceplate'}, numel(Time_s),1);

    ForceplateEvents = table(Side, Event, SampleIdx, Time_s, Source);
    ForceplateEvents = sortrows(ForceplateEvents, 'Time_s');

    [~, baseName, ~] = fileparts(file);
    outName = [baseName '_ForceplateEvents_HS_HO_LRP_TO.txt'];
    outPath = fullfile(path, outName);

    writetable(ForceplateEvents, outPath, 'Delimiter','\t');

    fprintf('\n--- FORCEPLATE HS/HO/LRP/TO exportiert ---\n');
    fprintf('Gesamt Events: %d\n', height(ForceplateEvents));
    fprintf('Gespeichert unter:\n  %s\n\n', outPath);

end

function slider_cb(src, ax, txt, window)
    t0 = src.Value;
    set(ax, 'XLim', [t0 t0+window]);
    txt.String = sprintf('t = %.2f s', t0);
end
