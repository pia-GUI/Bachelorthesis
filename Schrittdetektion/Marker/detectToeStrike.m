function [TS_idx, TS_t] = detectToeStrike(time, posY, vy, ay, TO_idx)
% TS wird vor dem jeweiligen TO gesucht:
% - Vorphase: Fall (posY & vy eher abwärts / vy negativ)
% - TS-Kandidat: |vy| ~ 0
% - Danach (bis kurz vor TO): kurzes Plateau (vy~0 und ay~0)
% 
% Hreljac & Marshall (2000), Journal of Biomechanics
% O'Connor et al. (2007), Gait & Posture
% Ghoussayni et al. (2004), Gait & Posture
% Salminen et al. (2024), Heliyon

time = time(:); posY = posY(:); vy = vy(:); ay = ay(:);
TO_idx = TO_idx(:);

dt = median(diff(time)); fs = 1/dt; N = numel(time);
assert(all([numel(posY), numel(vy), numel(ay)] == N), 'time/posY/vy/ay müssen gleich lang sein.');

madfun = @(x) 1.4826*median(abs(x - median(x)));

% --- Parameter ---
LOOKBACK_S     = 0.80;   % Rückwärtsfenster vor TO
GUARD_BEFORE_TO_S = 0.03; % Ende des TS-Fensters: TO - Guard
LOOKBACK_FALL_S = 0.10;  % Vorfenster für "Fall"-Check
ALIGN_WIN_S    = 0.04;   % im Fenster: wie weit wir TS um k0 herum suchen
PLAT_DUR_S     = 0.08;   % Plateau-Dauer nach TS
PLAT_HIT_FRAC  = 0.60;   % Anteil ruhiger Samples im Plateau
REFRACT_S      = 0.10;   % Minimum TS-Abstand (falls TOs nahe sind)

LB      = max(3, round(LOOKBACK_S*fs));
guardB  = max(1, round(GUARD_BEFORE_TO_S*fs));
fallLB  = max(3, round(LOOKBACK_FALL_S*fs));
alignF  = max(2, round(ALIGN_WIN_S*fs));
platF   = max(3, round(PLAT_DUR_S*fs));
refrF   = max(1, round(REFRACT_S*fs));

TS_idx = NaN(size(TO_idx));
lastTS = -inf;

for h = 1:numel(TO_idx)
    to = TO_idx(h);
    if isempty(to) || ~isfinite(to) || to <= 2
        continue
    end

    % Suchfenster: [to-LB, to-guardB]
    i1 = max(2, to - guardB);
    i0 = max(2, to - LB);
    if i1 - i0 + 1 < (fallLB + platF + 2)
        continue
    end

    % lokale robuste Skalen (im ganzen Rückwärtsfenster)
    w0 = i0:i1;
    vy_mad = max(1e-12, madfun(vy(w0)));
    ay_mad = max(1e-12, madfun(ay(w0)));
    pos_mad= max(1e-12, madfun(posY(w0)));

    % adaptive Schwellen (mit Untergrenzen)
    VY_NEG_MIN    = max(0.008, 1.4*vy_mad);    % klar negativer vy in Fallphase
    VY_ZERO_AT    = max(0.003, 1.1*vy_mad);    % Eventbed.: |vy(k)| klein
    VY_ZERO_PLAT  = max(0.004, 1.2*vy_mad);    % Plateau: vy~0
    AY_ZERO_PLAT  = max(0.06,  1.4*ay_mad);    % Plateau: ay~0 (relativ)
    FALL_FRAC_MIN = 0.50;                      % ≥50% diff(posY) <= 0
    POS_SLOPE_MIN = max(0.0005, 0.8*pos_mad / max(fallLB*dt, eps)); % optional (mild)

    found = [];

    % Wir laufen im Fenster von "spät" nach "früh", weil TS typischerweise kurz vor TO liegt.
    for k0 = (i1 - platF) : -1 : (i0 + fallLB)
        % (1) Vorphase-Fallcheck im Lookback vor k0
        pre = (k0-fallLB):(k0-1);
        if numel(pre) < 3, continue; end

        py_fall = mean(diff(posY(pre)) <= 0) >= FALL_FRAC_MIN;
        vy_fall = min(vy(pre)) <= -VY_NEG_MIN;

        % optional: posY soll insgesamt eher fallend/ruhig sein
        ttpre = time(pre);
        bpos = ([ttpre-ttpre(1), ones(numel(pre),1)] \ posY(pre));
        pos_slope_pre = bpos(1);

        if ~(py_fall && vy_fall) || pos_slope_pre > POS_SLOPE_MIN
            continue
        end

        % (2) Align: ab k0 rückwärts/umgebung suche ersten Index mit |vy| <= VY_ZERO_AT
        k_start = max(i0+1, k0 - alignF);
        segAlign = k_start:k0;
        kk = find(abs(vy(segAlign)) <= VY_ZERO_AT, 1, 'last');
        if isempty(kk), continue; end
        k = segAlign(kk);

        % (3) Plateau nach TS bis k+platF-1 (muss noch vor i1 liegen)
        if k + platF - 1 > i1
            continue
        end
        seg = k:(k+platF-1);

        vy_ok = mean(abs(vy(seg)) <= VY_ZERO_PLAT) >= PLAT_HIT_FRAC;
        ay0 = median(ay(max(i0,k-platF):min(i1,k+platF)));
        ay_ok = mean(abs(ay(seg) - ay0) <= AY_ZERO_PLAT) >= PLAT_HIT_FRAC;
        if ~(vy_ok && ay_ok)
            continue
        end

        found = k;
        break
    end

    if isempty(found)
        % Fallback: nimm Minimum von |vy| im letzten Drittel des Fensters
        tail0 = max(i0, i0 + round(0.65*(i1-i0)));
        [~, jj] = min(abs(vy(tail0:i1)));
        found = tail0 + jj - 1;
    end

    % Refraktär
    if found - lastTS < refrF
        continue
    end

    TS_idx(h) = found;
    lastTS = found;
end

% --- TS nur behalten, wenn gefunden ---
TS_idx = TS_idx(:);

% Nur gültige TS-Indizes behalten (NaNs raus)
TS_idx = TS_idx(isfinite(TS_idx));

% Rundung + Range-Check
TS_idx = round(TS_idx);
TS_idx = TS_idx(TS_idx >= 1 & TS_idx <= numel(time));

% Duplikate entfernen (stabil) und sortieren (optional)
TS_idx = unique(TS_idx,'stable');

% Zeiten
TS_t = time(TS_idx);

end
