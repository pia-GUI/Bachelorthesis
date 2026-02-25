%% === 1. Heel- und Toe-Dateien auswählen ===
[heelFile, heelPath] = uigetfile('*.txt', 'Wähle HEEL-MarkerEvents-Datei');
if isequal(heelFile,0)
    error('Keine Heel-Datei gewählt!');
end

[toeFile, toePath] = uigetfile('*.txt', 'Wähle TOE-MarkerEvents-Datei');
if isequal(toeFile,0)
    error('Keine Toe-Datei gewählt!');
end

heel = readtable(fullfile(heelPath, heelFile));
toe  = readtable(fullfile(toePath, toeFile));

%%% === 2. Marker-Typ als zusätzliche Spalte ergänzen ===
% (damit du später siehst, ob das Event vom Heel oder Toe kommt)
% 
% heel.Marker = repmat("Heel", height(heel), 1);
% toe.Marker  = repmat("Toe",  height(toe),  1);
% 
% Marker-Spalte ganz nach vorne schieben
% heel = movevars(heel, 'Marker', 'Before', 'Side');
% toe  = movevars(toe,  'Marker', 'Before', 'Side');

%% === 3. Beide Tabellen UNTEREINANDER hängen ===
allEvents = [heel; toe];

%% === 4. Nach Zeit sortieren (optional, aber sinnvoll) ===
if any(strcmp(allEvents.Properties.VariableNames, 'Time_s'))
    allEvents = sortrows(allEvents, 'Time_s');
elseif any(strcmp(allEvents.Properties.VariableNames, 'SampleIdx'))
    allEvents = sortrows(allEvents, 'SampleIdx');
end

%% === 5. Neue gemeinsame Datei speichern ===
[saveFile, savePath] = uiputfile('merged_HeelToe_MarkerEvents.txt', ...
    'Speichere zusammengeführte Heel+Toe-MarkerEvents');
if isequal(saveFile,0)
    disp('Abbruch – nichts gespeichert.');
else
    writetable(allEvents, fullfile(savePath, saveFile), 'Delimiter', '\t');
    fprintf('✅ Zusammengeführte Datei gespeichert:\n%s\n', ...
        fullfile(savePath, saveFile));
end
