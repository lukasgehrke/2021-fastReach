

pIDs = [12, 14] %[12, 14:17, 19:23] ; %1:10;

% %% config
current_sys = "mac";
eeglab_ver(current_sys);
% % eeglab
% 
% % addpath(genpath('D:\Lukas\signal-processing-motor-intent'));
% % addpath('D:\Lukas\2021-fastReach\signal_processing');
addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');
% 
pi_bemobil_config;

%% export ERPs

for pID = pIDs

    % EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, bemobil_config.source_data_folder, ...
    %     ['sub-' sprintf('%03d', pID)], 'Baseline.xdf'), ...
    %     'streamtype', 'EEG', 'exclude_markerstreams', {});
    % [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
    % EEG = pi_parse_events(EEG);
    % 
    % %% filter EMG
    % 
    % EEG = pop_eegfiltnew(EEG, .1, 15); % only filter EMG channel
    % 
    % %% epoch and save
    % 
    % pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
    % EEG.event = EEG.event(pre_move_event_ixs);
    % [EEG.event.type] = deal('reach');
    % EEG = pop_epoch(EEG, {'reach'}, [-2, 2]);
    % emg_tap = EEG.data(end,:,:);
    % 
    % save(fullfile(path, 'data', 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'emg_tap'), 'emg_tap');

    %% EEG

    EEG = pop_loadset(fullfile(bemobil_config.study_folder, bemobil_config.EEG_preprocessing_data_folder, ...
        ['sub-' sprintf('%02d', pID)], ['sub-' sprintf('%02d', pID) '_' bemobil_config.preprocessed_filename]));

    % EEG = pop_loadset(fullfile(bemobil_config.study_folder, bemobil_config.single_subject_analysis_folder, ...
    %     ['sub-' sprintf('%02d', pID)], ['sub-' sprintf('%02d', pID) '_' bemobil_config.single_subject_cleaned_ICA_filename]));

    EEG = pi_parse_events(EEG);

    EEG = pop_eegfiltnew(EEG, .1, 15);

    %% epoch and save

    pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
    EEG.event = EEG.event(pre_move_event_ixs);
    [EEG.event.type] = deal('reach');
    EEG = pop_epoch(EEG, {'reach'}, [-2, 2]);
    eeg_tap = EEG.data;

    save(fullfile(path, 'data', 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'eeg_tap'), 'eeg_tap');
end
