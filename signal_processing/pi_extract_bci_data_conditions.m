

pID = 6;

% %% config
% current_sys = "mac";
% eeglab_ver(current_sys);
% % eeglab
% 
% % addpath(genpath('D:\Lukas\signal-processing-motor-intent'));
% % addpath('D:\Lukas\2021-fastReach\signal_processing');
% addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');
% 
% pi_bemobil_config;

%% load data and parse events

condition = 'passive';
EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, bemobil_config.source_data_folder, ...
    ['sub-' sprintf('%03d', pID)], [condition, '.xdf']), ...
    'streamtype', 'EEG', 'exclude_markerstreams', {});
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
EEG = pi_parse_events(EEG);

%% filter EMG

EEG = pop_eegfiltnew(EEG, .1, 15); % only filter EMG channel

%% determine delay from EMG onset to button press

pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
pre_move_events = EEG.event(pre_move_event_ixs);
pre_move_data = EEG;
pre_move_data.event = pre_move_events;
[pre_move_data.event.type] = deal('reach');
pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1, 0]);

%% Extract EEG data for 2 classes: idle and pre-move

eeg_delay = 0; % - .06;

pre_move_data = pop_select(pre_move_data, 'nochannel',{'EMG', 'VEOG'});
pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-.9 + eeg_delay, .1 + eeg_delay]);

idle_event_ixs = find(contains({EEG.event.type}, 'idle_start'));
idle_events = EEG.event(idle_event_ixs);
idle_data = EEG;
idle_data = pop_select(idle_data, 'nochannel',{'EMG', 'VEOG'});
idle_data.event = idle_events;
[idle_data.event.type] = deal('idle_start');
idle_erp = pop_epoch(idle_data, {'idle_start'}, [0 + eeg_delay, 1 + eeg_delay]);

%% save long epochs for testing class probas

long_pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-2 + eeg_delay, 1 + eeg_delay]);
long_idle_erp = pop_epoch(idle_data, {'idle_start'}, [0 + eeg_delay, 3 + eeg_delay]);

long_idle = long_idle_erp.data;
long_pre_move = long_pre_move_erp.data;

%% save

path = fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)]);
if ~exist(path, 'dir')
    mkdir(path);
end

save(fullfile(path, ['long_pre_move_' condition]), 'long_pre_move');
save(fullfile(path, ['long_idle_' condition]), 'long_idle');

% idle = idle_erp.data;
% pre_move = pre_move_erp.data;
% 
% writetable(table({pre_move_erp.chanlocs.labels}'), fullfile(path, 'sel_chans_names.csv'));
% writematrix(sel_chans, fullfile(path, 'sel_chans.csv'));
% save(fullfile(path, 'pre_move_Baseline'), 'pre_move');
% save(fullfile(path, 'idle_Baseline'), 'idle');
