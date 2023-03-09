
%% config
current_sys = "mac";
eeglab_ver(current_sys);

addpath('/Users/lukasgehrke/Documents/publications/2021-fastReach/signal_processing');
addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');

pi_bemobil_config;

%% load data and parse events

pIDs = 2; %1:10;
conds = {'Baseline', 'EMS1', 'EMS2'};
results = [];

for pID = pIDs

    for cond = conds

        EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, 'study', bemobil_config.source_data_folder, ...
            ['sub-' sprintf('%03d', pID)], [cond{1} '.xdf']), ...
            'streamtype', 'EEG', 'exclude_markerstreams', {});
        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
        EEG = pi_parse_events(EEG);
        cz_ix = find(contains({EEG.chanlocs.labels},'Cz'));

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
        
        tr_nr = [1:size(rd)]';
        
        id = repelem(pID, numel(tr_nr))';
    
        design_tmp = table(id, condition, tr_nr, rd, ed, rt);
    
        %% add erp pre-move class

        erp = nan(size(design_tmp,1),250);

        if strcmp(cond{1}, 'Baseline') % consider delay from EMG onset to button press
            
            EMG = pop_eegfiltnew(EEG, 20, 100);
            EEG.data(end,:) = EMG.data(end,:).^2;
            
            pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
            pre_move_events = EEG.event(pre_move_event_ixs);
            valid_trials = str2double({pre_move_events.trial_nr});

            pre_move_data = EEG;
            pre_move_data.event = pre_move_events;
            [pre_move_data.event.type] = deal('reach');
            pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1, 0]);
            
            pre_move_erp = mean(pre_move_erp.data(end,:,:),3);
            pre_move_erp = movmean(pre_move_erp, 10);
            
            emg_onset_raw = min(find(pre_move_erp > prctile(pre_move_erp, 95)));
            emg_onset_fine = max(find(diff(pre_move_erp(1:emg_onset_raw)) < 0));
            
            if ~isempty(emg_onset_fine)
                delay = (emg_onset_fine - EEG.srate) / EEG.srate;
            else
                delay = .08;
            end

            pre_move_data = pop_select(pre_move_data, 'nochannel',{'EMG'});
            pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1.1 + delay, 0 + delay]);

        else

            if isfield(EEG.event, 'ems')
                
                pre_move_event_ixs = find(strcmp({EEG.event.ems}, 'on'));
                pre_move_events = EEG.event(pre_move_event_ixs);
                valid_trials = str2double({pre_move_events.trial_nr});

                pre_move_data = EEG;
                pre_move_data.event = pre_move_events;
                [pre_move_data.event.type] = deal('reach');
                pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1.1, 0]);

            else
                pre_move_erp.data = nan(size(pre_move_erp.data));
                pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
                pre_move_events = EEG.event(pre_move_event_ixs);
                valid_trials = str2double({pre_move_events.trial_nr});

            end
        end

        thresh = max(abs(pre_move_erp.data(:))) / 2;
        [~, bad_trials_ixs] = pop_eegthresh(pre_move_erp,1,[1:size(pre_move_erp.data,1)],-thresh,thresh,pre_move_erp.xmin,pre_move_erp.xmax,0,0);
%         pre_move_erp = pop_rejepoch(pre_move_erp, pre_move_erp.reject.rejthresh,0); % actually reject high prob epochs
        valid_trials(bad_trials_ixs) = [];
        
        cz_erp = pre_move_erp.data(cz_ix,26:end,:);
        cz_baseline = mean(pre_move_erp.data(cz_ix,1:25,:));
        cz_erp = squeeze(cz_erp - cz_baseline);
        cz_erp(:,bad_trials_ixs) = [];

        erp(valid_trials,:) = cz_erp';
        
        %% fuse data

        results_tmp = [design_tmp, array2table(erp)];
        results_tmp = results_tmp(valid_trials,:);
        results = [results; results_tmp];
    end
end

writetable(results, fullfile(bemobil_config.study_folder, 'study', 'PI_results.csv'));