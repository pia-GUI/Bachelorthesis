function HO = detect_Caderby_HO_segmented(t, Fz, bodyWeight, fs, HS_idx, TO_idx)
% Caderby et al. (2013), Gait & Posture
% CADERBY METHOD (Iz downward peak nach max Fz-Peak) + ZWANG: IMMER HO ZWISCHEN HS/TO
    t  = t(:); Fz = Fz(:);

    %% 1) 10 Hz Butterworth lowpass
    fc = 10; [b,a] = butter(4, fc/(fs/2), 'low');
    Fz_f = filtfilt(b,a,Fz);

    %% 2) Gewichtskorrektur
    Fz_wc = Fz_f - bodyWeight;

    %% 3) Iz Trapez-Integration
    dt = 1/fs;
    Iz = cumtrapz(Fz_wc) * dt;

    %% 4) HS/TO paaren und Limits setzen
    n = min(numel(HS_idx), numel(TO_idx));
    HS_idx = HS_idx(1:n); TO_idx = TO_idx(1:n);
    HO_idx = [];

    for k = 1:n
        s = HS_idx(k);
        e = TO_idx(k);
        if e <= s, continue; end

        Iz_seg = Iz(s:e);
        Fz_seg = Fz_f(s:e);  % Gefiltertes Fz im Segment

        %% 5) Max Fz-Peak nach HS finden (typisch mid-stance)
        [~, maxFz_loc] = findpeaks(Fz_seg, 'SortStr', 'descend', 'NPeaks', 1);
        if isempty(maxFz_loc), maxFz_loc = round((s + e)/2) - s + 1; end  % Fallback: Mitte

        %% 6) Caderby: Iz downward peak NACH max Fz-Peak (2. letztes Min bevor TO)
        Iz_post = Iz_seg(maxFz_loc:end);
        [pks_neg_post, locs_neg_post] = findpeaks(-Iz_post, 'MinPeakProminence', std(Iz_post)*0.1);

        if length(locs_neg_post) >= 1
            HO_local = locs_neg_post(end);  % Letztes relevantes Min nach Peak
        else
            % Fallback: 2. letztes Min im gesamten Segment (orig. Logik)
            [pks_neg, locs_neg] = findpeaks(-Iz_seg, 'MinPeakProminence', std(Iz_seg)*0.1);
            if length(locs_neg) >= 2
                HO_local = locs_neg(end-1);
            else
                HO_local = round(length(Iz_seg)/2);  % Letzter Ausweg: Mitte Segment
            end
        end

        %% 7) ZWANG: INNERHALB HS-TO UND > maxFz
        if HO_local > maxFz_loc && HO_local >= 1 && HO_local <= length(Iz_seg)
            HO_idx(end+1,1) = s + HO_local - 1;
        end
    end

    HO.idx  = HO_idx;
    HO.time = t(HO_idx);
end
