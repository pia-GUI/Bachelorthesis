function [HS_idx, HS_t] = detectHeelStrike(time, posY, vy, ay)
% Robuste Erkennung von Heel Strikes:
% - 1. Loop: "normale" Erkennung (vy-Kriterium + ay-Plateau + Snap auf posY-Min)
% - 2. Loop: Lückenfüllung
%     Für jeden HS(i) wird ein erwarteter nächster HS bei
%     HS_t(i) + meanISI gesucht.
%     Wenn in diesem Zeitfenster [t_pred ± stdISI] kein HS liegt,
%     wird dort ein neuer Kandidat gesucht (posY-Minimum + einfache Checks).
%
% Hreljac & Marshall (2000), Journal of Biomechanics
% O'Connor et al. (2007), Gait & Posture
% Ghoussayni et al. (2004), Gait & Posture
% Hansen et al. (2002), Journal of Biomechanics



time = time(:); posY = posY(:); vy = vy(:); ay = ay(:);
dt = median(diff(time));
fs = 1/dt;
N  = numel(time);

% --- Tuning für 1. Loop ---
VY_EPS        = 0.0010;              % Zero-Crossing Toleranz (kleiner = sensibler)
LOOKBACK_S    = 0.17;                % Zeitraum für "starker Fall" vor HS
NEG_DROP_K    = 0.15;                % std-basierte Schwelle für starken neg. vy
NEG_DROP_ABS  = 0.013;               % absolute Untergrenze für neg. vy
AY_ZERO_ABS   = 0.08;                % ay ~ 0 am HS (mild)
AY_PLAT_K     = 1.8;                 % Toleranz*lokale MAD fürs Plateau
PLAT_DUR_S    = 0.06;                % Dauer Plateau nach HS
REFRACT_S     = 0.50;                % Mindestabstand HS↔HS (in s)
SNAP_WIN_S    = 0.08;                % Snap auf posY-Min innerhalb ±80 ms

LB     = max(3, round(LOOKBACK_S*fs));
platF  = max(3, round(PLAT_DUR_S*fs));
refr   = max(1, round(REFRACT_S*fs));
snapF  = max(1, round(SNAP_WIN_S*fs));
negThr = -max(NEG_DROP_ABS, NEG_DROP_K * std(vy));

HS_idx = [];
last   = -inf;

%% === 1) Erster Durchlauf: "normale" Erkennung ===
for k = 2:N-2
    % ------- Kandidat: vy −→ + (robust) ODER nahe Null mit Trend nach oben -------
    vL = median(vy(max(1,k-2):k-1));
    vR = median(vy(k+1:min(N,k+2)));
    zero_cross = (vL < -VY_EPS && vR >= VY_EPS);
    near_zero  = (abs(median(vy(max(1,k-1):min(N,k+1)))) < 2*VY_EPS) && (vR > vL); % "klemmt" um 0

    if ~(zero_cross || near_zero)
        continue;
    end

    % ------- Starker Abfall im Lookback? -------
    pre = max(1,k-LB):k-1;
    if isempty(pre) || min(vy(pre)) > negThr
        continue;
    end

    % ------- Validierung: ay ~ 0 + kurzes Plateau danach -------
    k1 = k;
    k2 = min(N, k + platF - 1);
    w0 = max(1, k - platF) : min(N, k + platF);
    loc_med = median(ay(w0));
    loc_mad = 1.4826 * median(abs(ay(w0) - loc_med));
    zero_lim = max(AY_ZERO_ABS, AY_PLAT_K * max(loc_mad, 1e-9));

    if abs(ay(k) - loc_med) > zero_lim
        continue;
    end
    if max(abs(ay(k1:k2) - loc_med)) > zero_lim
        continue;
    end

    % ------- Refractory: nicht zu dicht an vorherigem HS -------
    if k - last < refr
        continue;
    end

    % ------- Snap: posY-Minimum um k -------
    win = max(1, k - snapF) : min(N, k + snapF);
    [~, r] = min(posY(win));
    hs = win(r);

    HS_idx(end+1) = hs; %#ok<AGROW>
    last = hs;
end

HS_idx = unique(HS_idx(:));   % sortiert, ohne Duplikate
HS_t   = time(HS_idx);

%% === 2) Zweiter Durchlauf: fehlende HS mit meanISI ± stdISI ergänzen ===
if numel(HS_idx) >= 2
    isi    = diff(HS_t);      % Intervallzeiten
    meanISI = mean(isi);
    stdISI  = std(isi);

    if isnan(stdISI)
        stdISI = 0;
    end

    % Wenn die Standardabweichung sehr klein ist → Mindestfenster
    if stdISI < 0.05
        stdISI = max(0.05, 0.25 * meanISI);
    end

    if meanISI > 0
        newHS = [];

        for i = 1:numel(HS_idx)-1
            % erwarteter Zeitpunkt des nächsten HS
            t_pred = HS_t(i) + meanISI;

            % Nur sinnvoll, wenn der erwartete Zeitpunkt noch VOR dem
            % nächsten bereits erkannten HS liegt (mit etwas Sicherheitsabstand)
            if t_pred >= (HS_t(i+1) - 0.2*meanISI)
                continue;
            end

            % Liegt bereits ein HS in [t_pred ± stdISI]?
            if any(abs(HS_t - t_pred) <= stdISI)
                continue;   % in diesem Fenster ist schon ein Event
            end

            % Suchfenster um den erwarteten Zeitpunkt
            t_min = t_pred - stdISI;
            t_max = t_pred + stdISI;

            % in die Signalgrenzen beschneiden
            t_min = max(t_min, time(1));
            t_max = min(t_max, time(end));

            win = find(time >= t_min & time <= t_max);
            if numel(win) < 3
                continue;
            end

            % --- Kandidat: posY-Minimum im Fenster ---
            [~, r_local] = min(posY(win));
            k_cand = win(r_local);

            % --- Grobe Checks für den Kandidaten ---

            % 1) Starker Fall in vy vorher (wie im 1. Loop)
            pre = max(1, k_cand-LB):k_cand-1;
            if isempty(pre) || min(vy(pre)) > negThr
                continue;
            end

            % 2) ay soll nicht extrem sein (aber weicher als im 1. Loop)
            w0 = max(1, k_cand - platF) : min(N, k_cand + platF);
            loc_med = median(ay(w0));
            loc_mad = 1.4826 * median(abs(ay(w0) - loc_med));
            zero_lim_soft = max(2*AY_ZERO_ABS, 2.5 * max(loc_mad, 1e-9)); % weicher

            if abs(ay(k_cand) - loc_med) > zero_lim_soft
                continue;
            end

            % 3) Nicht zu dicht an bestehenden HS
            minTimeDist = 0.3 * meanISI;   % Mindestabstand in s
            if ~isempty(HS_idx)
                if min(abs(time(HS_idx) - time(k_cand))) < minTimeDist
                    continue;
                end
            end

            % Kandidaten übernehmen
            newHS(end+1) = k_cand; %#ok<AGROW>
        end

        if ~isempty(newHS)
            HS_idx = unique([HS_idx; newHS(:)]);
            HS_t   = time(HS_idx);
        end
    end
end

end
