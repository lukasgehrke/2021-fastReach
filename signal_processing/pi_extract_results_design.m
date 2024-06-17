
%% config
current_sys = "mac";
eeglab_ver(current_sys);

pi_bemobil_config;

%% load data and parse events

pIDs = [12, 14:17, 19:23] ; %1:10;
conds = {'Baseline', 'passive', 'agency1'}; %
design = [];

for pID = pIDs

    design_this_pID = [];

    for cond = conds

        %% load
        EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, bemobil_config.source_data_folder, ...
            ['sub-' sprintf('%03d', pID)], [cond{1} '.xdf']), ...
            'streamname', 'BrainVision RDA', 'exclude_markerstreams', {});
        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
        EEG = pi_parse_events(EEG);

        % delete all events before and after condition
        block_start_ix = find(strcmp({EEG.event.block}, 'start'));
        block_end_ix = find(strcmp({EEG.event.block}, 'end'));
        EEG.event = EEG.event(block_start_ix:block_end_ix);

        %% behavior
        rt = {EEG.event.rt};
        rt = rt(~cellfun('isempty', rt));
        rt = cellfun(@str2double, rt)';
        
        rd = {EEG.event.real_delay};
        estimation_task_ix = ~cellfun('isempty', rd);
        rd = rd(~cellfun('isempty', rd))';

        ed = {EEG.event.estimated_delay};
        ed = ed(estimation_task_ix);
        % ed = ed(~cellfun('isempty', ed));
        fx = @(x)any(isempty(x));
        ind = cellfun(fx, ed);
        ed(ind) = {nan};

        if pID == 16 && strcmp(cond, 'Baseline')
            ed(38) = {'150'};
        end

        ed = cellfun(@str2double, ed)';
        
        condition = {EEG.event.condition};
        condition = condition(1:size(ed))';
        
        tr_nr = [1:size(rt,1)]';

        if strcmp(cond, 'agency2')
            tr_nr = tr_nr + size(rt,1);
        end
        
        id = repelem(pID, numel(tr_nr))';

        delta_tap_ems = repelem(NaN, numel(tr_nr))';

        delta_idle_ems = repelem(NaN, numel(tr_nr))';

        control = repelem({'muscle'},size(rt,1))';
        if isfield(EEG.event, 'ems')
            control(str2double({EEG.event(find(strcmp({EEG.event.ems}, 'on'))).trial_nr})) = {'ems'};
            
            % delta ems trigger - screen tap
            ems_trials = str2double({EEG.event(find(strcmp({EEG.event.ems}, 'on'))).trial_nr});
            tap_latency = [EEG.event(find(strcmp({EEG.event.class}, 'reach_end'))).latency];
            tap_latency = tap_latency(ems_trials);
            idle_latency = [EEG.event(find(strcmp({EEG.event.class}, 'idle_start'))).latency];
            idle_latency = idle_latency(ems_trials);

            ems_latency = [EEG.event(find(strcmp({EEG.event.ems}, 'on'))).latency];
            
            delta_tap_ems_values = (tap_latency - ems_latency) / EEG.srate;
            delta_tap_ems(ems_trials) = delta_tap_ems_values;

            delta_idle_ems_values = (ems_latency - idle_latency) / EEG.srate;
            delta_idle_ems(ems_trials) = delta_idle_ems_values;
        end

        % incomplete trial
        if pID == 3 && strcmp(cond, 'EMS1')
            rd(1) = [];
            ed(1) = [];
            condition(1) = [];
            control(1) = [];
        end

        design_tmp = table(id, condition, tr_nr, rd, ed, rt, control, delta_tap_ems, delta_idle_ems);
        design_this_pID = [design_this_pID; design_tmp];

    end

    path = fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)]);
    if ~exist(path, 'dir')
        mkdir(path);
    end
    writetable(design_this_pID, fullfile(path, 'design.csv'));

    design = [design; design_this_pID];

end

writetable(design, fullfile(bemobil_config.study_folder, 'PI_results_design.csv'));