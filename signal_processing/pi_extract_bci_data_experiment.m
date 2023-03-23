
pIDs = 2:3;

%% config
current_sys = "mac";
eeglab_ver(current_sys);

pi_bemobil_config;

%% load data and parse events

for pID = pIDs
    
    for i = 1:2
        EEG = pop_loadset(fullfile(bemobil_config.study_folder, bemobil_config.raw_EEGLAB_data_folder, ...
            ['sub-' sprintf('%01d', pID)], ['sub-' sprintf('%01d', pID) '_EMS' num2str(i) '_EEG.set']));
        
        %% determine delay from EMG onset to button press
        
        pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
        pre_move_events = EEG.event(pre_move_event_ixs);
        pre_move_data = EEG;
        pre_move_data.event = pre_move_events;
        [pre_move_data.event.type] = deal('reach');
        pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1, 0]);
        
        %% Extract EEG data for 2 classes: idle and pre-move
        
        idle_event_ixs = find(contains({EEG.event.type}, 'idle_start'));
        idle_events = EEG.event(idle_event_ixs);
        idle_data = EEG;
        idle_data.event = idle_events;
        [idle_data.event.type] = deal('idle_start');
        idle_erp = pop_epoch(idle_data, {'idle_start'}, [-1, 0]);
        
        %% save
        
        path = fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)]);
        if ~exist(path, 'dir')
            mkdir(path);
        end
        
        idle = idle_erp.data;
        pre_move = pre_move_erp.data;
        
        save(fullfile(path, ['pre_move_EMS' num2str(i)]), 'pre_move');
        save(fullfile(path, ['idle_EMS' num2str(i)]), 'idle');
    end
end