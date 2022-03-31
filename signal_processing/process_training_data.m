%% init
eeglab;
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/bemobil-pipeline-sj'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/eeglab_changes/newColormap'));
addpath('/Users/lukasgehrke/Documents/code.nosync/fieldtrip-sj');

cfg.subject                = 9;
cfg.fname                  = '_training.xdf';

%% run fastReach signal processing training data

cfg.filename               = fullfile('/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/source/', num2str(cfg.subject), cfg.fname);
cfg.bids_target_folder     = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/1_bids';                               % required
cfg.task                   = 'fastReach';                         % optional 
cfg.study_folder           = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study';
cfg.session_names          = {'fastReach'};                      % required, enter task name as a string, or enter a cell array when there are multiple sessions in the data set  

cfg.eeg.stream_name        = 'BrainVision RDA';                      % required
cfg.eeg.chanloc_newname    = {'Fp1', 'Fz', 'F3', 'F7', 'FT9', 'FC5', 'FC1', ...
    'C3', 'T7', 'TP9', 'CP5', 'CP1', 'Pz', 'P3', 'P7', 'O1', 'Oz', 'O2', ...
    'P4', 'P8', 'TP10', 'CP6', 'CP2', 'Cz', 'C4', 'T8', 'FT10', 'FC6', ...
    'FC2', 'F4', 'F8', 'Fp2', 'AF7', 'AF3', 'AFz', 'F1', 'F5', 'FT7', ...
    'FC3', 'C1', 'C5', 'TP7', 'CP3', 'P1', 'P5', 'PO7', 'PO3', 'POz', ...
    'PO4', 'PO8', 'P6', 'P2', 'CPz', 'CP4', 'TP8', 'C6', 'C2', 'FC4', ...
    'FT8', 'F6', 'AF8', 'AF4', 'F2', 'VEOG'
    }; % doesn't work

cfg.motion.tracksys{1}.name                    = 'HTCVive';   % required, string, name of the tracking system
                                                                    % in case motion metadata are provided, match with fieldname in "motionInfo.motion.TrackingSystems.(fieldname)"
                                                                    % e.g., motionInfo.motion.TrackingSystems.HTCVive.Manufacturer = 'HTC'; 
cfg.motion.streams{1}.name                     = 'Tracker';      % required, keyword in stream name, searched for in field "xdfdata{streamIndex}.info.name"
cfg.motion.streams{1}.tracksys                 = 'HTCVive';   % required, match with one of the values in "motion.tracksys{}.name"
cfg.motion.streams{1}.tracked_points           = 'Tracker'; %  keyword in channel names, indicating which object (tracked point) is included in the stream
                                                                     % searched for in field "xdfdata{streamIndex}.info.desc.channels.channel{channelIndex}.label"
                                                                     % required to be unique in a single tracking system                                          
% cfg.phys.streams{1}.stream_name          = 'OpenSignals';           % optional

cfg.other_data_types = {'motion'};

%% convert .xdf to bids to set
bemobil_xdf2bids(cfg);
bemobil_bids2set(cfg);

%% processing
cfg.event.move             = 'reach:end';
cfg.event.idle             = 'idle:start';
cfg.event.rp               = 'movement_onset';
cfg.event.win              = [-3, -0];
cfg.feat.rp_win            = [-1, 0];
cfg.feat.move_win          = [0, 1];
cfg.feat.idle_win          = [-1, 0];

cfg.EMG_chan               = 2;

cfg.n_best_chans           = 30;
cfg.n_wins                 = 10;

EEG = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_EEG.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);
ori_events = EEG.event;
EEG = pop_eegfiltnew(EEG, .1, 10);
EEG = pop_reref(EEG, []);
% EEG = clean_asr(EEG,[],[],[],[],'off'); % -> todo play with settings

for n = 1:length(EEG.chanlocs)
    EEG.chanlocs(n).labels = cfg.eeg.chanloc_newname{n};
end
EEG = pop_chanedit(EEG,'lookup',fullfile(fileparts(which('dipfitdefs')),'standard_BESA','standard-10-5-cap385.elp'));
EEG = eeg_checkset(EEG);

Motion = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_MOTION_HTCVive.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);
Motion = pop_eegfiltnew(Motion, [], 6);

% EMG = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_PHYSIO.set'], ...
%     'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);

% movement onset events
vel = squeeze(sqrt(diff(Motion.data(4,:)).^2+diff(Motion.data(5,:)).^2+diff(Motion.data(6,:)).^2));
vel = [vel, mean(vel)];
Motion.data(1,:) = vel;
motion_tmp = pop_epoch(Motion, {cfg.event.move}, cfg.event.win);
mag = squeeze(motion_tmp.data(1,:,:));

for i = 1:size(mag,2)
    onset(i) = fR_movement_onset_detector(mag(:,i), .7, 125, .05);
end
dists = size(mag,1) - onset;

% detection ok!!!
% figure;
% for i = 1:20 %size(mag,2)
%     subplot(1,20,i);
%     plot(mag(:,i)); xline(onset(i));
% end

move_ev_ixs = strfind({Motion.event.type}', cfg.event.move);
move_ev_ixs = find(~cellfun(@isempty, move_ev_ixs));

idle_ev_ixs = strfind({Motion.event.type}', cfg.event.idle);
idle_ev_ixs = find(~cellfun(@isempty, idle_ev_ixs));

move_ev_lats = [EEG.event(move_ev_ixs).latency] - dists;
 
for i = 1:numel(move_ev_lats)
    onsets(i).type = cfg.event.rp;
    onsets(i).latency = move_ev_lats(i);
end

% checks -> ok
% mag = squeeze(Motion.data(1,:));
% figure;plot(mag); xline([onsets.latency]);

% select data
idle = pop_epoch(EEG, {cfg.event.idle}, cfg.feat.idle_win);
ori_events = EEG.event;
EEG.event = onsets;
rp = pop_epoch(EEG, {cfg.event.rp}, cfg.feat.rp_win);
[~, noisy_epochs] = pop_autorej(rp, 'nogui','on','eegplot','off');

[best_chans_ixs, crit1, crit2] = rp_ERP_select_channels(rp.data, idle.data, EEG.srate/cfg.n_wins, 1); % extract informative channels
sel_chans = best_chans_ixs(1:cfg.n_best_chans);
eeg.idle = idle.data(sel_chans,:,:);% - idle.data(sel_chans,1,:);
eeg.rp = rp.data(sel_chans,:,:);% - rp.data(sel_chans,1,:);

% idle = pop_epoch(EMG, {cfg.event.idle}, cfg.feat.idle_win);
% emg.idle = squeeze(idle.data(cfg.EMG_chan,:,:);% - idle.data(cfg.EMG_chan,1,:));
% EMG.event = onsets;
% rp = pop_epoch(EMG, {cfg.event.rp}, cfg.feat.rp_win);
% emg.rp = squeeze(rp.data(cfg.EMG_chan,:,:);% - rp.data(cfg.EMG_chan,1,:));

motion_tmp = pop_epoch(Motion, {cfg.event.idle}, cfg.feat.idle_win);
motion.idle = squeeze(motion_tmp.data(1,:,:));
Motion.event = onsets;
motion_tmp = pop_epoch(Motion, {cfg.event.rp}, cfg.feat.move_win);
motion.move = squeeze(motion_tmp.data(1,:,:));

% remove noisy epochs & premature movements
Motion.event = ori_events;
rp_wait_time = [Motion.event(move_ev_ixs).latency] - [Motion.event(idle_ev_ixs).latency];
premature_movement = find(rp_wait_time<EEG.srate*2);
reject_eps = unique([noisy_epochs, premature_movement]);

eeg.rp(:,:,reject_eps) = [];
eeg.idle(:,:,reject_eps) = [];
% emg.rp(:,:,reject_eps) = [];
% emg.idle(:,:,reject_eps) = [];
motion.move(:,reject_eps) = [];
motion.idle(:,reject_eps) = [];
% add some noise to idle motion
motion.idle = motion.idle * 3;

% save
rp = ones(size(eeg.rp,3),1);
idle = ones(size(eeg.rp,3),1)*2;
rp_class = [rp;idle];
epoch_ix = (1:size(rp_class))';
sample = (1:size(eeg.rp,2))' / EEG.srate - 1;

sample = repmat(sample, size(rp_class,1),1);
rp_class = repelem(rp_class, size(eeg.rp,2));
epoch_ix = repelem(epoch_ix, size(eeg.rp,2));

EEG_out = [eeg.rp(:,:)'; eeg.idle(:,:)'];
Motion_out = [motion.move(:); motion.idle(:)];
% EMG_out = [emg.rp(:); emg.idle(:)];

% t = array2table([sample, epoch_ix, rp_class, Motion_out, EMG_out, EEG_out], "VariableNames", ['sample', 'epoch_ix' 'rp_class' 'Motion' 'EMG' cfg.eeg.chanloc_newname(sel_chans)]);
t = array2table([sample, epoch_ix, rp_class, Motion_out, EEG_out], "VariableNames", ['sample', 'epoch_ix' 'rp_class' 'Motion' cfg.eeg.chanloc_newname(sel_chans)]);

if ~exist([cfg.study_folder '/eeglab2python/' num2str(cfg.subject)])
    mkdir([cfg.study_folder '/eeglab2python/' num2str(cfg.subject)]);
end
writetable(t, [cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/data.csv']);

chans = array2table([sel_chans], "VariableNames", {'chans'});
writetable(chans, [cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/chans.csv']);

%% for plotting timeseries with seaborn

Motion.event = ori_events;
Motion = pop_resample(Motion,50);

rp_wait_time = [Motion.event(move_ev_ixs).latency] - [Motion.event(idle_ev_ixs).latency];
rp_wait_time = mean(rp_wait_time) / Motion.srate;
win = rp_wait_time;

EEG = pop_resample(EEG,50);
rp = pop_epoch(EEG, {cfg.event.rp}, [-win,win]);

Motion.event = EEG.event;
motion = pop_epoch(Motion, {cfg.event.rp}, [-win,win]);
move = squeeze(motion.data(1,:,:));

rp = pop_select(rp, 'channel', sel_chans(1));
cz = squeeze(rp.data);

epoch_ix = (1:size(cz,2))';
samples_per_ep = (1:size(cz,1))' / EEG.srate - win;

sample = repmat(samples_per_ep, size(epoch_ix,1)*2,1);
epoch_ix = repelem(epoch_ix, size(samples_per_ep,1)*2);

cz = zscore(cz(:));
move = zscore(move(:));
vals = [cz;move];

type = ones(size(cz,1),1);
type = [type; type*2];

t = array2table([sample, epoch_ix, type, vals], "VariableNames", {'sample', 'epoch_ix', 'type', ['Motion' cfg.eeg.chanloc_newname{sel_chans(1)}]});
writetable(t, [cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/data_for_plot.csv']);

%% EEG topopot

% figure; plot(squeeze(mean(eeg.rp,3))')
% figure; plot(squeeze(mean(eeg.idle,3))')
% [H,P,CI,STATS] = ttest(eeg.rp(:),eeg.idle(:))

set(0, 'DefaultFigureRenderer', 'painters');
figure;

% values for colorcoding - showing most dominant RP deflection
val = mean(crit2,2);
val = mean(eeg.rp(:,end,:),3);

topoplot(val,EEG.chanlocs(sel_chans),'headrad',.6,'electrodes','pts','chaninfo',EEG.chaninfo);
cbar;
