

% pID = 18;
pIDs = [12, 14:17, 19:21] ; %1:10;

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

%% load data and parse events

for pID = pIDs

    EEG = pop_loadset(fullfile(bemobil_config.study_folder, bemobil_config.EEG_preprocessing_data_folder, ...
        ['sub-' sprintf('%02d', pID)], ['sub-' sprintf('%02d', pID) '_' bemobil_config.preprocessed_filename]));
    EEG = pi_parse_events(EEG);
    
    %% filter

    EEG = pop_eegfiltnew(EEG, .1, 15); % only filter EMG channel
    
    delay = -.08; % EMG approximate delay
    
    %% Extract EEG data for 2 classes: idle and pre-move
    
    eeg_delay = 0; % - .06;
    
    pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
    pre_move_events = EEG.event(pre_move_event_ixs);
    pre_move_data = EEG;
    pre_move_data.event = pre_move_events;
    [pre_move_data.event.type] = deal('reach');
    pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1 + delay + eeg_delay, 0 + delay + eeg_delay]);
    
    disp([-1 + delay + eeg_delay, 0 + delay + eeg_delay]);
    
    idle_event_ixs = find(contains({EEG.event.type}, 'idle_start'));
    idle_events = EEG.event(idle_event_ixs);
    idle_data = EEG;
    idle_data = pop_select(idle_data, 'nochannel',{'EMG', 'VEOG'});
    idle_data.event = idle_events;
    [idle_data.event.type] = deal('idle_start');
    idle_erp = pop_epoch(idle_data, {'idle_start'}, [0 + eeg_delay, 1 + eeg_delay]);
    
    disp([1 + eeg_delay, 2 + eeg_delay])
    
    %% reject noisy epochs
    
    % TODO pool the noisy trials and reject for both idle and movement segment
    
    % compute mean and sd and remove outliers
    idle_epoch_mean = squeeze(mean(idle_erp.data,2));
    mean_outlier = find(isoutlier(mean(idle_epoch_mean,1)));
    idle_epoch_std = squeeze(std(idle_erp.data,0,2));
    std_outlier = find(isoutlier(mean(idle_epoch_std)));
    noisy_trials_idle = union(mean_outlier, std_outlier);
    idle_erp = pop_rejepoch(idle_erp, noisy_trials_idle, 0); % actually reject high prob epochs
    
    pre_move_epoch_mean = squeeze(mean(pre_move_erp.data,2));
    mean_outlier = find(isoutlier(mean(pre_move_epoch_mean,1)));
    pre_move_epoch_std = squeeze(std(pre_move_erp.data,0,2));
    std_outlier = find(isoutlier(mean(pre_move_epoch_std)));
    noisy_trials_pre_move = union(mean_outlier, std_outlier);
    pre_move_erp = pop_rejepoch(pre_move_erp, noisy_trials_pre_move, 0); % actually reject high prob epochs
    
    %% save
    
    path = fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)]);
    if ~exist(path, 'dir')
        mkdir(path);
    end
    
    idle = idle_erp.data;
    pre_move = pre_move_erp.data;
    
    save(fullfile(path, 'pre_move_processed'), 'pre_move');
    save(fullfile(path, 'idle_processed'), 'idle');
    
end
