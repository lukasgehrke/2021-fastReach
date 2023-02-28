
pID = 1;

%% config
current_sys = "mac";
eeglab_ver(current_sys);

addpath('/Users/lukasgehrke/Documents/publications/2021-fastReach/signal_processing');
addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');

pi_bemobil_config;

%% load data and parse events

EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, 'study', bemobil_config.source_data_folder, ...
    ['sub-' sprintf('%03d', pID)], 'Baseline.xdf'), ...
    'streamtype', 'EEG', 'exclude_markerstreams', {});
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
EEG = pi_parse_events(EEG);

%% filter EMG

EMG = pop_eegfiltnew(EEG, 20, 100); % only filter EMG channel
EEG.data(end,:) = abs(EMG.data(end,:));

%% determine delay from EMG onset to button press

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
disp(delay);

%% Extract EEG data for 2 classes: idle and pre-move

pre_move_data = pop_select(pre_move_data, 'nochannel',{'EMG'});
pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-1.1 + delay, 0 + delay]);

idle_event_ixs = find(contains({EEG.event.type}, 'idle_start'));
idle_events = EEG.event(idle_event_ixs);
idle_data = EEG;
idle_data = pop_select(idle_data, 'nochannel',{'EMG'});
idle_data.event = idle_events;
[idle_data.event.type] = deal('idle_start');
idle_erp = pop_epoch(idle_data, {'idle_start'}, [-1.1, 0]);

%% reject noisy epochs

[idle_erp, idle_noisy_epochs] = pop_autorej(idle_erp, 'nogui','on','eegplot','off');
[pre_move_erp, pre_move_noisy_epochs] = pop_autorej(pre_move_erp, 'nogui','on','eegplot','off');

%% select best channels

n_wins = 10;
n_best_chans = 20;

[best_chans_ixs, crit1, crit2] = rp_ERP_select_channels(pre_move_erp.data, idle_erp.data, EEG.srate/n_wins, 1); % extract informative channels
sel_chans = best_chans_ixs(1:n_best_chans);

cz_ix = find(contains({EEG.chanlocs.labels},'Cz'));

if sum(ismember(sel_chans, cz_ix)) < 1
    sel_chans(end) = cz_ix;
end

%% save

path = fullfile(bemobil_config.study_folder, 'study', 'eeglab2python', ['sub-' sprintf('%03d', pID)]);
if ~exist(path, 'dir')
    mkdir(path);
end

idle = idle_erp.data;
pre_move = pre_move_erp.data;

writematrix(sel_chans, fullfile(path, 'sel_chans.csv'));
save(fullfile(path, 'pre_move'), 'pre_move');
save(fullfile(path, 'idle'), 'idle');

%% reaction time

rt = {EEG.event.rt};
rt = rt(~cellfun('isempty', rt));
rt = cellfun(@str2num, rt);
disp(['min rt: ', num2str(round(min(rt),2)), '; max rt: ', num2str(round(max(rt),2))])

delay(1) = prctile(rt,5);
delay(2) = prctile(rt,95);

writematrix(delay, fullfile(path, 'delay.csv'));

%% save Cz ERP for plotting

pre_move_cz = squeeze(pre_move_erp.data(cz_ix,:,:));
writematrix(pre_move_cz, fullfile(path, 'pre_move_cz.csv'));

idle_cz = squeeze(idle_erp.data(cz_ix,:,:));
writematrix(idle_cz, fullfile(path, 'idle_cz.csv'));

%% 

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

behavior = table(id, cond, tr_nr, rd, ed);

writetable(behavior, fullfile(path, 'behavior.csv'));
