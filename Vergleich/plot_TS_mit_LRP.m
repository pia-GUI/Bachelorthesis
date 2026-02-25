function plot_TS_LRP_on_PosY_oneAxes(posYFile, markerFile, forceplateFile)
% Plot: Left/Right PosY in EINEM Diagramm
%   - LINKS = blau, RECHTS = rot
%   - Marker-TS als Punkte AUF den jeweiligen Linien
%   - Forceplate-Event "LRP" als vertikale Linien (links/ rechts getrennt)
%
% Erwartete Event-Dateien (Marker & Forceplate) Spalten:
%   Side | Event | SampleIdx | Time_s | Source
% PosY-Datei enthält:
%   RightToe_PosY, LeftToe_PosY (+ optional SampleIdx, Time_s/Time)

    %% === Dateien wählen, falls nicht übergeben ===
    if nargin < 1 || isempty(posYFile)
        [f,p] = uigetfile({'*.txt;*.csv','PosY Datei (*.txt,*.csv)'}, 'Wähle PosY-Datei');
        if isequal(f,0), disp('Abbruch (PosY).'); return; end
        posYFile = fullfile(p,f);
    end
    if nargin < 2 || isempty(markerFile)
        [f,p] = uigetfile({'*.txt;*.csv','Marker Events (*.txt,*.csv)'}, 'Wähle Marker-Event-Datei');
        if isequal(f,0), disp('Abbruch (Marker).'); return; end
        markerFile = fullfile(p,f);
    end
    if nargin < 3 || isempty(forceplateFile)
        [f,p] = uigetfile({'*.txt;*.csv','Forceplate Events (*.txt,*.csv)'}, 'Wähle Forceplate-Event-Datei');
        if isequal(f,0), disp('Abbruch (Forceplate).'); return; end
        forceplateFile = fullfile(p,f);
    end

    %% === PosY einlesen ===
    Tpos = readtable(posYFile);

    mustHave = {'RightToe_PosY','LeftToe_PosY'};
    for k = 1:numel(mustHave)
        if ~ismember(mustHave{k}, Tpos.Properties.VariableNames)
            error("PosY-Datei: Spalte '%s' nicht gefunden.", mustHave{k});
        end
    end

    posY_R = Tpos.RightToe_PosY;
    posY_L = Tpos.LeftToe_PosY;

    n = height(Tpos);
    if ismember('SampleIdx', Tpos.Properties.VariableNames)
        x = Tpos.SampleIdx;
    else
        x = (1:n)';  % fallback
    end

    % Zeitvektor optional (für Mapping Time_s -> SampleIdx)
    tpos = [];
    if ismember('Time_s', Tpos.Properties.VariableNames)
        tpos = Tpos.Time_s;
    elseif ismember('Time', Tpos.Properties.VariableNames)
        tpos = Tpos.Time;
    end

    %% === Events einlesen ===
    Tm = readtable(markerFile);
    Tf = readtable(forceplateFile);

    for req = ["Side","Event"]
        if ~ismember(req, string(Tm.Properties.VariableNames))
            error("Marker-Datei: Spalte '%s' fehlt.", req);
        end
        if ~ismember(req, string(Tf.Properties.VariableNames))
            error("Forceplate-Datei: Spalte '%s' fehlt.", req);
        end
    end

    %% === TS (Marker) + LRP (Forceplate) filtern ===
    Tm_TS  = Tm(strcmpi(string(Tm.Event), "TS"), :);
    Tf_LRP = Tf(strcmpi(string(Tf.Event), "LRP"), :);

    if ~ismember('SampleIdx', Tm_TS.Properties.VariableNames)
        error("Marker-Datei: Für TS wird 'SampleIdx' benötigt.");
    end

    % Marker TS getrennt
    mR_idx = Tm_TS.SampleIdx(strcmpi(string(Tm_TS.Side),"R"));
    mL_idx = Tm_TS.SampleIdx(strcmpi(string(Tm_TS.Side),"L"));

    % Forceplate LRP -> SampleIdx
    fR_idx = []; fL_idx = [];
    if ismember('SampleIdx', Tf_LRP.Properties.VariableNames)
        fR_idx = Tf_LRP.SampleIdx(strcmpi(string(Tf_LRP.Side),"R"));
        fL_idx = Tf_LRP.SampleIdx(strcmpi(string(Tf_LRP.Side),"L"));
    else
        if ~ismember('Time_s', Tf_LRP.Properties.VariableNames)
            error("Forceplate-Datei: Weder 'SampleIdx' noch 'Time_s' vorhanden (LRP).");
        end
        if isempty(tpos)
            error("PosY-Datei: Kein Zeitvektor (Time_s/Time) vorhanden, um Forceplate-Time_s -> SampleIdx zu mappen.");
        end

        tf = Tf_LRP.Time_s;
        f_idx_all = interp1(tpos, x, tf, 'nearest', 'extrap');

        fR_idx = f_idx_all(strcmpi(string(Tf_LRP.Side),"R"));
        fL_idx = f_idx_all(strcmpi(string(Tf_LRP.Side),"L"));
    end

    %% === Hilfsfunktion: PosY am SampleIdx (x) holen ===
    getYatX = @(xx, yy, qx) arrayfun(@(v) yy(find(abs(xx - v)==min(abs(xx - v)), 1, 'first')), qx);

    mR_y = []; mL_y = [];
    if ~isempty(mR_idx), mR_y = getYatX(x, posY_R, mR_idx); end
    if ~isempty(mL_idx), mL_y = getYatX(x, posY_L, mL_idx); end

    %% === Farben fest definieren (Links blau, Rechts rot) ===
    cL = 'b';  % Left
    cR = 'r';  % Right

    %% === Plot (EIN Diagramm) ===
    figure('Name','TS (Marker) & LRP (Forceplate) auf PosY','Color','w');
    ax = axes; %#ok<LAXES>
    hold(ax,'on'); grid(ax,'on');

    % Linien: Rechts rot, Links blau
    hR = plot(ax, x, posY_R, cR, 'LineWidth', 1.2, 'DisplayName', 'RightToe\_PosY');
    hL = plot(ax, x, posY_L, cL, 'LineWidth', 1.2, 'DisplayName', 'LeftToe\_PosY');

    % Forceplate LRP als vertikale Linien (nur 1x in Legende)
    hLRP_R = gobjects(0); hLRP_L = gobjects(0);

    for i = 1:numel(fR_idx)
        hh = xline(ax, fR_idx(i), ['--' cR], 'LineWidth', 1.0);
        if i == 1, hh.DisplayName = 'LRP (Forceplate) R'; end
        hLRP_R(end+1) = hh; %#ok<AGROW>
        if i > 1, hh.HandleVisibility = 'off'; end
    end

    for i = 1:numel(fL_idx)
        hh = xline(ax, fL_idx(i), ['--' cL], 'LineWidth', 1.0);
        if i == 1, hh.DisplayName = 'LRP (Forceplate) L'; end
        hLRP_L(end+1) = hh; %#ok<AGROW>
        if i > 1, hh.HandleVisibility = 'off'; end
    end

    % Marker TS als Punkte AUF den Linien (nur 1x in Legende)
    hTS_R = gobjects(0); hTS_L = gobjects(0);

    if ~isempty(mR_idx)
        hTS_R = plot(ax, mR_idx, mR_y, ['o' cR], 'MarkerSize', 7, 'MarkerFaceColor','w', ...
            'LineWidth', 1.5, 'DisplayName', 'TS (Marker) R');
    end

    if ~isempty(mL_idx)
        hTS_L = plot(ax, mL_idx, mL_y, ['o' cL], 'MarkerSize', 7, 'MarkerFaceColor','w', ...
            'LineWidth', 1.5, 'DisplayName', 'TS (Marker) L');
    end

    title(ax, 'Toe Strike (Marker) & LRP (Forceplate) auf PosY (L=blau, R=rot)');
    xlabel('Time [s] (rekonstruiert absolut)');
    ylabel(ax, 'PosY');

    
    handles = [hR, hL];
    if ~isempty(hLRP_R), handles(end+1) = hLRP_R(1); end 
    if ~isempty(hLRP_L), handles(end+1) = hLRP_L(1); end 
    if ~isempty(hTS_R),  handles(end+1) = hTS_R;  end 
    if ~isempty(hTS_L),  handles(end+1) = hTS_L;  end 
    legend(ax, handles, 'Location','best');
end
