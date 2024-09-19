

pIDs = [12, 14:17, 19:23] ; %1:10;

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

    % EEG = pop_loadset(fullfile(bemobil_config.study_folder, bemobil_config.EEG_preprocessing_data_folder, ...
    %     ['sub-' sprintf('%02d', pID)], ['sub-' sprintf('%02d', pID) '_' bemobil_config.preprocessed_filename]));

    EEG = pop_loadset(fullfile(bemobil_config.study_folder, bemobil_config.single_subject_analysis_folder, ...
        ['sub-' sprintf('%02d', pID)], ['sub-' sprintf('%02d', pID) '_' bemobil_config.single_subject_cleaned_ICA_filename]));

    EEG = pi_parse_events(EEG);
    EEG = pop_eegfiltnew(EEG, .1, 15);

    if pID == 15
        EEG.event(304) = [];
    end

    %% get EMG delay
    EMG = pop_loadxdf(fullfile(bemobil_config.study_folder, bemobil_config.source_data_folder, ...
        ['sub-' sprintf('%03d', pID)], 'Baseline.xdf'), ...
        'streamtype', 'EEG', 'exclude_markerstreams', {});
    EMG = pi_parse_events(EMG);
    EMG = pop_eegfiltnew(EMG, 20, 100); % only filter EMG channel
    
    % determine delay from EMG onset to button press
    pre_move_event_ixs = find(contains({EMG.event.type}, 'reach_end'));
    pre_move_events = EMG.event(pre_move_event_ixs);
    pre_move_data = EMG;
    pre_move_data.event = pre_move_events;
    [pre_move_data.event.type] = deal('reach');
    pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1, 0]);
    % reject noisy trials
    amplitude_means = squeeze(mean(pre_move_erp.data(end,:,:),2));
    amp_outliers = find(isoutlier(amplitude_means,'mean'));
    pre_move_erp_data = squeeze(pre_move_erp.data(end,:,:));
    pre_move_erp_data(:,amp_outliers) = []; 
    pre_move_erp = mean(pre_move_erp_data,2);
    pre_move_erp = movmean(pre_move_erp, 10);
    emg_onset_raw = min(find(pre_move_erp > prctile(pre_move_erp, 95)));
    emg_onset_fine = max(find(diff(pre_move_erp(1:emg_onset_raw)) < 0));
    
    delay = (emg_onset_fine - EMG.srate) / EMG.srate;
    
    if isempty(delay) || delay > .2
        delay = -.08;
    end

    %% epoch fix delays

    pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
    EEG.event = EEG.event(pre_move_event_ixs);
    [EEG.event.type] = deal('reach');

    % load design matrix
    design = readtable(fullfile(bemobil_config.study_folder, 'eeglab2python', ...
        ['sub-' sprintf('%03d', pID)], 'design.csv'));

    % add column with reach_end latencies to design
    design.lats = [EEG.event.latency]';

    % rows where control is muscle
    muscle_ixs = contains(design.control, 'muscle');
    % add delay*EEG.srate to lats where control is muscle
    design.lats(muscle_ixs) = design.lats(muscle_ixs) + delay * EEG.srate;

    % rows where control is ems
    ems_ixs = contains(design.control, 'ems');
    % add design.delta_tap_ems*EEG.srate to lats where control is ems
    design.lats(ems_ixs) = design.lats(ems_ixs) - design.delta_tap_ems(ems_ixs) * EEG.srate;
    
    %% save tap

    TAP = pop_epoch(EEG, {'reach'}, [-2, 2]);
    eeg_tap = TAP.data;
    save(fullfile(path, 'data', 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'eeg_tap'), 'eeg_tap');

    %% save movement start

    % set design.lats as EEG.event.latency
    tmp = num2cell(design.lats);
    [EEG.event.latency] = tmp{:};
    START = pop_epoch(EEG, {'reach'}, [-2, 2]);
    eeg_move = START.data;

    save(fullfile(path, 'data', 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'eeg_move'), 'eeg_move');

end
