
%% config
current_sys = "mac";
eeglab_ver(current_sys);
% eeglab

% addpath(genpath('D:\Lukas\signal-processing-motor-intent'));
% addpath('D:\Lukas\2021-fastReach\signal_processing');
addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');

pi_bemobil_config;

%% load data and parse events

pID = 5;

EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, bemobil_config.source_data_folder, ...
    ['sub-' sprintf('%03d', pID)], 'agency1.xdf'), ...
    'streamtype', 'Classifier', 'exclude_markerstreams', {});
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
EEG = pi_parse_events(EEG);

%
pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
pre_move_events = EEG.event(pre_move_event_ixs);
pre_move_data = EEG;
pre_move_data.event = pre_move_events;
[pre_move_data.event.type] = deal('reach');
pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-2, 0]);

for i = 1:100
    signal = squeeze(pre_move_erp.data(2,:));
    minValue = min(signal);
    signal(signal < (100-i)/100) = minValue;
    [PKS,LOCS] = findpeaks(signal);
    if length(PKS) >= 60
        disp(i)
        break;
    end
end

threshold = (100-i)/100
minValue = min(signal);
signal(signal < threshold) = minValue;
findpeaks(signal)


%%

(57+72+87)/3

% for i = 1:10
%     figure;
%     plot(squeeze(pre_move_erp.data(2,:,i)));
% end


%% 

