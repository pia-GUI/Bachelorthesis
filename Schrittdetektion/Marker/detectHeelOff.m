function [HO_idx, HO_t] = detectHeelOff(time, posY, vy, ay, HS_idx)
% Heel Off: nach HS mit Mindestverzögerung; erster starker vy-Anstieg + ay-Impuls.
% 
% Hreljac & Marshall (2000), Journal of Biomechanics
% O'Connor et al. (2007), Gait & Posture
% Ghoussayni et al. (2004), Gait & Posture
% Hansen et al. (2002), Journal of Biomechanics
% Salminen et al. (2024), Heliyon


time = time(:); posY = posY(:); vy = vy(:); ay = ay(:);
dt = median(diff(time)); fs = 1/max(dt, eps); N = numel(time);

% --- Parameter ---
MIN_DELAY_S  = 0.20;       % muss etwas nach HS liegen (zu früh vermeiden)
SEARCH_MAX_S = 0.70;       % max. Suchfenster nach HS
RISE_WIN_S   = 0.05;       % Fenster für Steigungsprüfung (~50 ms)
REFRACT_S    = 0.30;       % Mindestabstand HO↔HO

winF   = max(2, round(RISE_WIN_S*fs));
delayF = max(1, round(MIN_DELAY_S*fs));
searchF= max(5, round(SEARCH_MAX_S*fs));
refrF  = max(1, round(REFRACT_S*fs));

madfun = @(x) 1.4826*median(abs(x - median(x)));

HO_idx = []; lastHO = -inf;

for h = 1:numel(HS_idx)
    hs = HS_idx(h);
    if h < numel(HS_idx), nextHS = HS_idx(h+1); else, nextHS = inf; end

    k1 = min(N, hs + delayF);                 % Mindestverzögerung nach HS
    k2 = min([N, hs + searchF, nextHS - 1]);  % harte Kappung vor dem nächsten HS
    if k2 <= k1, continue; end

    % Lokale adaptive Schwellen um hs
    w0  = max(1, hs - round(0.15*fs)) : min(N, hs + round(0.30*fs));
    vy_base  = median(vy(w0));
    ay_base  = median(ay(w0));
    vy_mad   = max(madfun(vy(w0)), 1e-12);
    ay_mad   = max(madfun(ay(w0)), 1e-12);

    VY_SLOPE_MIN = max(0.30, 2.0*vy_mad) / max(winF*dt, eps);  % m/s^2
    AY_PEAK_MIN  = max(0.12, 2.0*ay_mad);                      % m/s^2
    VY_LEVEL_MIN = max(0.015,1.5*vy_mad);                      % m/s über Basis

    ho = [];

    % --- Hauptsuche: gleitendes Fenster [k .. k+winF-1] mit starker Steigung/Impuls
    k = k1;
    while k <= k2 - winF + 1
        ii = k : k + winF - 1;             % absolute Indizes
        tt = time(ii); vv = vy(ii); aa = ay(ii);

        % vy-Steigung via Regression (robuster als einfache Diff)
        X = [tt - tt(1), ones(numel(tt),1)];
        b = X\vv; vy_slope = b(1);

        vy_level = median(vv) - vy_base;   % vy über Basis
        ay_peak  = max(aa) - ay_base;      % positiver Beschl.-Impuls

        if (vy_slope >= VY_SLOPE_MIN) && (vy_level >= VY_LEVEL_MIN) && (ay_peak >= AY_PEAK_MIN)
            ho = k;                         % frühestes starkes Anstiegsfenster
            break
        end
        k = k + 1;
    end

    % --- Fallback: größter positiver vy-Anstieg (falls oben nichts gefunden)
    if isempty(ho)
        if k2 - k1 + 1 >= 2 && winF <= (k2 - k1 + 1)
            sMax = -inf; sIdx = [];
            for kk = k1 : (k2 - winF + 1)
                ii = kk : kk + winF - 1;
                tt = time(ii); vv = vy(ii);
                X = [tt - tt(1), ones(numel(tt),1)];
                b = X\vv;
                if b(1) > sMax
                    sMax = b(1); sIdx = kk;
                end
            end
            if ~isempty(sIdx) && sMax > 0
                ho = sIdx;
            end
        end
    end
    
    % --- Notfall-Fallback: wenn immer noch kein ho gefunden wurde ---
    if isempty(ho)
        % Fenster [k1..k2] existiert ja (sonst wären wir oben "continue" gegangen)
        idxWin = k1:k2;

        % 1) bevorzugt: erste Stelle mit klar positivem vy über Basis
        vy_over = vy(idxWin) - vy_base;
        candPos = idxWin(vy_over > VY_LEVEL_MIN/2);   % etwas entspannter als Hauptkriterium

        if ~isempty(candPos)
            ho = candPos(1);      % frühester brauchbarer Kandidat
        else
            % 2) falls selbst das nichts liefert: "Mitte" des Fensters
            ho = round((k1 + k2)/2);
        end
    end

    % Sequenzschutz & Refractory
    if ~isempty(ho)
        if ho >= nextHS, ho = []; end
        if ~isempty(ho) && (ho - lastHO) < refrF, ho = []; end
    end

    if ~isempty(ho)
        HO_idx(end+1) = ho; %#ok<AGROW>
        lastHO = ho;
    end
end

HO_idx = unique(HO_idx);
HO_t   = time(HO_idx);
end