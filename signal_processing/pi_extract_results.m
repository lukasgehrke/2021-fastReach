
%% config
current_sys = "mac";
eeglab_ver(current_sys);

addpath('/Users/lukasgehrke/Documents/publications/2021-fastReach/signal_processing');
addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');

pi_bemobil_config;

%% load data and parse events

pIDs = 1:10;
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
    
        %% add erp pre-move class
        if strcmp(cond{1}, 'Baseline') % consider delay from EMG onset to button press
            
            EMG = pop_eegfiltnew(EEG, 20, 100);
            EEG.data(end,:) = EMG.data(end,:).^2;
            
            pre_move_event_ixs = find(contains({EEG.event.type}, 'reach_end'));
            pre_move_events = EEG.event(pre_move_event_ixs);
            pre_move_data = EEG;
            pre_move_data.event = pre_move_events;
            [pre_move_data.event.type] = deal('reach');
            pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1, 0]);
            
            pre_move_erp = mean(pre_move_erp.data(end,:,:),3);
            pre_move_erp = movmean(pre_move_erp, 10);
            
            emg_onset_raw = min(find(pre_move_erp > prctile(pre_move_erp, 95)));
            emg_onset_fine = max(find(diff(pre_move_erp(1:emg_onset_raw)) < 0));
            
            delay = (emg_onset_fine - EEG.srate) / EEG.srate;

            pre_move_data = pop_select(pre_move_data, 'nochannel',{'EMG'});
            pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1.1 + delay, 0 + delay]);
            
            [pre_move_erp, pre_move_noisy_epochs] = pop_autorej(pre_move_erp, 'nogui','on','eegplot','off');
                
            erp = array2table(squeeze(pre_move_erp.data(cz_ix,26:end,:) - mean(pre_move_erp.data(cz_ix,1:25,:)))');
        else
            % TODO add the erp of second preceeding the ems trigger
            % for trials where there was no ems trigger save an nan row.
%             erp = 
        end
        
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
        
        cond = {EEG.event.condition};
        cond = cond(1:size(ed))';
        
        tr_nr = [1:size(rd)]';
        
        id = repelem(pID, numel(tr_nr))';
    
        design_tmp = table(id, cond, tr_nr, rd, ed, rt);
        
        %% fuse data
        results = [results, design_tmp, erp];
    end
end

writetable(results, fullfile(path, 'PI_results.csv'));