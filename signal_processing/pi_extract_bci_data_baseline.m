

pID = 6;

% %% config
% current_sys = "mac";
% % eeglab_ver(current_sys);
% % eeglab
% 
% % addpath(genpath('D:\Lukas\signal-processing-motor-intent'));
% % addpath('D:\Lukas\2021-fastReach\signal_processing');
% addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');
% 
% pi_bemobil_config;

%% load data and parse events

EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, bemobil_config.source_data_folder, ...
    ['sub-' sprintf('%03d', pID)], 'baseline.xdf'), ...
    'streamtype', 'EEG', 'exclude_markerstreams', {});
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off');
EEG = pi_parse_events(EEG);

%% filter EMG

EMG = pop_eegfiltnew(EEG, 20, 100); % only filter EMG channel
EEG = pop_eegfiltnew(EEG, .1, 15); % only filter EMG channel

EEG.data(end,:) = EMG.data(end,:).^2;

%% determine delay from EMG onset to button press

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

figure;plot(pre_move_erp);
if isempty(delay) || delay > .2
    delay = -.08;
else
    xline(emg_onset_fine);
end
disp(delay);

%% Extract EEG data for 2 classes: idle and pre-move

eeg_delay = 0; % - .06;

pre_move_data = pop_select(pre_move_data, 'nochannel',{'EMG', 'VEOG'});
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

% thresh = max(abs(idle_erp.data(:))) / 2;
% idle_erp = pop_eegthresh(idle_erp,1,[1:size(idle_erp.data,1)],-thresh,thresh,idle_erp.xmin,idle_erp.xmax,0,0);
% idle_erp = pop_rejepoch(idle_erp, idle_erp.reject.rejthresh,0); % actually reject high prob epochs
% 
% %[pre_move_erp, pre_move_noisy_epochs] = pop_autorej(pre_move_erp, 'nogui','on','eegplot','off');
% thresh = max(abs(pre_move_erp.data(:))) / 2;
% pre_move_erp = pop_eegthresh(pre_move_erp,1,[1:size(pre_move_erp.data,1)],-thresh,thresh,pre_move_erp.xmin,pre_move_erp.xmax,0,0);
% pre_move_erp = pop_rejepoch(pre_move_erp, pre_move_erp.reject.rejthresh,0); % actually reject high prob epochs

% %% data exploration 21.03.2023
% % 
% c = 24;
% p = mean(squeeze(pre_move_erp.data(c,:,:)),2);
% i = mean(squeeze(idle_erp.data(c,:,:)),2);
% 
% p = p-mean(p(1:25,:),1);
% i = i-mean(i(1:25,:),1);
% 
% figure;
% subplot(2,1,1);plot(p)
% subplot(2,1,2);plot(i)

%% save long epochs for testing class probas

long_pre_move_erp = pop_epoch(pre_move_data, {'reach'}, [-2 + delay + eeg_delay, 0 + delay + eeg_delay]);
long_idle_erp = pop_epoch(idle_data, {'idle_start'}, [0 + eeg_delay, 2 + eeg_delay]);

long_idle = long_idle_erp.data;
long_pre_move = long_pre_move_erp.data;

%% select best channels

n_wins = 10;
n_best_chans = 20;

[best_chans_ixs, crit1, crit2] = rp_ERP_select_channels(pre_move_erp.data, idle_erp.data, EEG.srate/n_wins, 1); % extract informative channels

sel_chans = best_chans_ixs(1:n_best_chans);
chans_to_keep = {'C3', 'C4', 'Cz'};

for chan = chans_to_keep
    chan_ix = find(strcmp({pre_move_erp.chanlocs.labels}, chan{1}));

    if sum(ismember(sel_chans, chan_ix)) < 1
        sel_chans(2:end) = sel_chans(1:end-1);
        sel_chans(1) = chan_ix;
    end
end

%% save

path = fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)]);
if ~exist(path, 'dir')
    mkdir(path);
end

save(fullfile(path, 'long_pre_move_Baseline'), 'long_pre_move');
save(fullfile(path, 'long_idle_Baseline'), 'long_idle');

% make same size
% epochs = min([size(idle_erp.data,3), size(pre_move_erp.data,3)]);
% idle = idle_erp.data(:,:,1:epochs);
% pre_move = pre_move_erp.data(:,:,1:epochs);

idle = idle_erp.data;
pre_move = pre_move_erp.data;

writetable(table({pre_move_erp.chanlocs.labels}'), fullfile(path, 'sel_chans_names.csv'));
writematrix(sel_chans, fullfile(path, 'sel_chans.csv'));
save(fullfile(path, 'pre_move_Baseline'), 'pre_move');
save(fullfile(path, 'idle_Baseline'), 'idle');

%% reaction time

rt = {EEG.event.rt};
rt = rt(~cellfun('isempty', rt));
rt = cellfun(@str2num, rt)';
disp(['min rt: ', num2str(round(min(rt),2)), '; max rt: ', num2str(round(max(rt),2))])

delay(1) = prctile(rt,5);
delay(2) = prctile(rt,95);

writematrix(delay, fullfile(path, 'delay.csv'));

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

behavior = table(id, cond, tr_nr, rd, ed, rt);

writetable(behavior, fullfile(path, 'behavior.csv'));
