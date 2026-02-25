function [TO_idx, TO_t] = detectToeOff(time, posY, vy, ay)
% Toe-Off (TO) = Ereignis NACH einem lokalen posY-Minimum.
% posY-Minimum ist das führende Kriterium.
% vy/ay bestätigen das Abheben 
%
% Hreljac & Marshall (2000), Journal of Biomechanics
% O'Connor et al. (2007), Gait & Posture
% Ghoussayni et al. (2004), Gait & Posture
% Hansen et al. (2002), Journal of Biomechanics

time = time(:); posY = posY(:); vy = vy(:); ay = ay(:);
dt = median(diff(time)); fs = 1/dt; N = numel(time);
assert(all([numel(posY),numel(vy),numel(ay)]==N), ...
    'time/posY/vy/ay müssen gleich lang sein.');

madfun = @(x) 1.4826*median(abs(x - median(x)));

% ---------- Parameter ----------
GUARD_AFTER_MIN_S = 0.05;   % Start nach Minimum
SEARCH_AFTER_MIN_S= 0.30;   % Suchfenster nach Minimum
ONSET_WIN_S       = 0.05;   % Trendfenster
REFRACT_S         = 0.4;   % min. Abstand zwischen TOs

guardF  = max(1, round(GUARD_AFTER_MIN_S*fs));
searchF = max(5, round(SEARCH_AFTER_MIN_S*fs));
winF    = max(3, round(ONSET_WIN_S*fs));
refrF   = max(1, round(REFRACT_S*fs));

% ---------- 1) posY-Minima ----------
isMin = false(N,1);
for i = 2:N-1
    isMin(i) = posY(i) < posY(i-1) && posY(i) <= posY(i+1);
end
idxMin = find(isMin);

if isempty(idxMin)
    TO_idx = [];
    TO_t   = [];
    return;
end

% robuste globale Skalen
vy_mad  = max(1e-12, madfun(vy));
pos_mad = max(1e-12, madfun(posY));

% Schwellen
VY_POS_MIN     = max(0.015, 1.3*vy_mad);
POS_SLOPE_MIN  = max(0.001, 1.0*pos_mad) / max(winF*dt, eps);

TO_idx = [];
last = -inf;

% ---------- 2) Für jedes posY-Minimum: TO danach suchen ----------
for m = 1:numel(idxMin)
    imin = idxMin(m);

    % Suchfenster NACH dem Minimum
    i0 = imin + guardF;
    i1 = min(N - winF + 1, imin + searchF);
    if i0 >= i1
        continue
    end

    to = [];

    for k = i0 : i1
        ii = k:(k+winF-1);
        tt = time(ii); t0 = tt(1);

        % vy muss positiv sein
        if median(vy(ii)) < VY_POS_MIN
            continue
        end

        % posY muss steigen (Trend!)
        X  = [tt-t0, ones(numel(tt),1)];
        by = X \ posY(ii);
        if by(1) < POS_SLOPE_MIN
            continue
        end

        % erster gültiger Zeitpunkt nach dem Minimum = TO
        to = k;
        break
    end

    if isempty(to)
        continue
    end

    % Refraktär
    if to - last < refrF
        continue
    end

    TO_idx(end+1,1) = to; %#ok<AGROW>
    last = to;
end

TO_t = time(TO_idx);
end
