
%% config
current_sys = "mac";
eeglab_ver(current_sys);

pi_bemobil_config;

%% load data and parse events

pIDs = 2:3; %1:10;
conds = {'Baseline', 'EMS1', 'EMS2'};
chan_for_grand_mean = 'C4';
results = [];

for pID = pIDs

    design = [];
    move = [];
    idle = [];

    for cond = conds

        %% load
        EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, bemobil_config.source_data_folder, ...
            ['sub-' sprintf('%03d', pID)], [cond{1} '.xdf']), ...
            'streamtype', 'EEG', 'exclude_markerstreams', {});
        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
% 	    EEG_single_subject_final = pop_loadset('filename', [ bemobil_config.filename_prefix num2str(subject)...
% 		    '_' bemobil_config.single_subject_cleaned_ICA_filename], 'filepath', output_filepath);
        EEG = pi_parse_events(EEG);

        %% behavior
        rt = {EEG.event.rt};
        rt = rt(~cellfun('isempty', rt));
        rt = cellfun(@str2num, rt)';
        
        rd = {EEG.event.real_delay};
        rd = rd(~cellfun('isempty', rd));
        rd = cellfun(@str2num, rd)';
        
        ed = {EEG.event.estimated_delay};
        ed = ed(~cellfun('isempty', ed));
        ed = cellfun(@str2num, ed)';
        
        condition = {EEG.event.condition};
        condition = condition(1:size(ed))';
        
        tr_nr = [1:size(rt,1)]';
        
        id = repelem(pID, numel(tr_nr))';

        control = repelem({'muscle'},size(rt,1))';
        if isfield(EEG.event, 'ems')
            control(str2double({EEG.event(find(strcmp({EEG.event.ems}, 'on'))).trial_nr})) = {'ems'};
        end

        % incomplete trial
        if pID == 3 && strcmp(cond, 'EMS1')
            rd(1) = [];
            ed(1) = [];
            condition(1) = [];
            control(1) = [];
        end
    
        %% Extract EEG data for 2 classes: pre-move
        
        if strcmp(cond{1}, 'Baseline') % consider delay from EMG onset to button press
            
            EMG = pop_eegfiltnew(EEG, 20, 100);
            EEG.data(end,:) = EMG.data(end,:).^2;
            
            pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
            pre_move_events = EEG.event(pre_move_event_ixs);
            pre_move_data = EEG;
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
            
            delay = (emg_onset_fine - EEG.srate) / EEG.srate;
            disp(delay);
            
            if isempty(delay) 
                delay = -.08;
            end

            pre_move_data = pop_select(pre_move_data, 'nochannel',{'EMG', 'VEOG'});
            pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1 + delay, 0 + delay]);

        else

            pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
            pre_move_events = EEG.event(pre_move_event_ixs);
            pre_move_data = EEG;
            pre_move_data.event = pre_move_events;
            [pre_move_data.event.type] = deal('reach');
            pre_move_data = pop_select(pre_move_data, 'nochannel',{'EMG', 'VEOG'});
            pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1, 0]);

            if isfield(EEG.event, 'ems')
                % take data preceeding ems trigger if it happened,
                % otherwise take data preceeding reach

                pre_move_event_ixs = find(strcmp({EEG.event.ems}, 'on'));
                pre_move_events = EEG.event(pre_move_event_ixs);
                pre_move_data = EEG;
                pre_move_data.event = pre_move_events;
                [pre_move_data.event.type] = deal('reach');
                pre_move_data = pop_select(pre_move_data, 'nochannel',{'EMG', 'VEOG'});
                pre_ems_erp = pop_epoch(pre_move_data, {'reach'}, [-1, 0]);
                pre_move_erp.data(:,:,find(strcmp(control, 'ems'))) = pre_ems_erp.data; % overwrite trials with pre ems data

            end

        end

        pre_move_epoch_mean = squeeze(mean(pre_move_erp.data,2));
        mean_outlier = find(isoutlier(mean(pre_move_epoch_mean,1)));
        pre_move_epoch_std = squeeze(std(pre_move_erp.data,0,2));
        std_outlier = find(isoutlier(mean(pre_move_epoch_std)));
        noisy_trials_pre_move = union(mean_outlier, std_outlier)';
        noisy_erp = repelem({'no'},size(rt,1))';
        noisy_erp(noisy_trials_pre_move) = {'yes'};

        %% idle
        
        idle_event_ixs = find(contains({EEG.event.type}, 'idle_start'));
        idle_events = EEG.event(idle_event_ixs);
        idle_data = EEG;
        idle_data.event = idle_events;
        [idle_data.event.type] = deal('idle_start');
        idle_data = pop_select(idle_data, 'nochannel',{'EMG','VEOG'});
        idle_erp = pop_epoch(idle_data, {'idle_start'}, [0, 1]);
        
        %% save
        
        idle = cat(3, idle, idle_erp.data);
        move = cat(3, move, pre_move_erp.data);

        %% save one filtered channel for plotting
        
        c_ix = find(strcmp({EEG.chanlocs.labels},chan_for_grand_mean));
        pre_move_erp = pop_eegfiltnew(pre_move_erp, .1, 15);
        c_erp = pre_move_erp.data(c_ix,:,:);
        c_baseline = mean(pre_move_erp.data(c_ix,1:25,:));
        c_erp = squeeze(c_erp - c_baseline)';
        
        %% fuse data

        design_tmp = table(id, condition, tr_nr, rd, ed, rt, control, noisy_erp);
        design = [design; design_tmp];
        results_tmp = [design_tmp, array2table(c_erp)];
        results = [results; results_tmp];

    end

    assert(size(design_tmp,1), size(idle,3))
    assert(size(design_tmp,1), size(move,3))

    path = fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)]);
    if ~exist(path, 'dir')
        mkdir(path);
    end
    
    writetable(design, fullfile(path, 'design.csv'));
    save(fullfile(path, 'pre_move'), 'move');
    save(fullfile(path, 'idle'), 'idle');

end

writetable(results, fullfile(bemobil_config.study_folder, 'PI_results.csv'));