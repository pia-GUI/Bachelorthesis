function LRP = detect_LRP(t, Fy, HS_idx, TO_idx)
% Detektion des Loading-Response-Peaks (LRP) nach Ben-Gal et al. (2020)
%
% Der LRP ist definiert als das erste lokale Maximum der vertikalen
% Bodenreaktionskraft (vGRF) nach dem Heel Strike (Fersenaufsatz)
% innerhalb der Standphase.
%
% Ben-Gal et al. (2020), Journal of Biomechanics


    n = min(numel(HS_idx), numel(TO_idx));
    idx_out  = nan(n,1);
    time_out = nan(n,1);
    val_out  = nan(n,1);

    Fy_use = abs(Fy);   % robust gegen Vorzeichenkonvention

    for i = 1:n
        iHS = HS_idx(i);
        iTO = TO_idx(i);

        if isempty(iHS) || isempty(iTO) || iTO <= iHS + 5
            continue;
        end

        seg = Fy_use(iHS:iTO);

        % 1) erstes lokales Minimum (Tal, Mid Stance) finden
        d = diff(seg);
        minRel = find(d(1:end-1) < 0 & d(2:end) >= 0, 1, 'first');

        if ~isempty(minRel)
            searchEnd = minRel + 1;
        else
            searchEnd = numel(seg);
        end

        % 2) LRP = Maximum bis zu diesem Tal
        [mx, r] = max(seg(1:searchEnd));
        idx = iHS + r - 1;

        idx_out(i)  = idx;
        time_out(i) = t(idx);
        val_out(i)  = mx;
    end

    good = ~isnan(idx_out);
    LRP.idx  = idx_out(good);
    LRP.time = time_out(good);
    LRP.val  = val_out(good);
end
