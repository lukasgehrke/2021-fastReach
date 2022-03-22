%% init
eeglab;
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/bemobil-pipeline-sj'));
addpath('/Users/lukasgehrke/Documents/code.nosync/fieldtrip-sj');

%% cfg Willy

cfg.subject                = 1;                                  % required
cfg.fname                  = 'test500Hy.xdf';
cfg.filename               = ['/Users/lukasgehrke/Desktop/' cfg.fname];
cfg.bids_target_folder     = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/1_bids';                               % required
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
cfg.phys.streams{1}.stream_name          = 'OpenSignals';           % optional

cfg.other_data_types = {'motion', 'physio'};

%% convert .xdf to bids to set

bemobil_xdf2bids(cfg);
bemobil_bids2set(cfg);

%% cfg processing
cfg.event.move             = 'reach:end';
cfg.event.idle             = 'idle:start';
cfg.event.rp               = 'movement_onset';
cfg.event.win              = [-2, -.1];
cfg.feat.rp_win            = [-1, 0];
cfg.feat.move_win          = [0, 1];
cfg.feat.idle_win          = [-.5, .5];

cfg.n_best_chans           = 20;
cfg.n_wins                 = 10;

EEG = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_EEG.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);
ori_events = EEG.event;
EEG = pop_eegfiltnew(EEG, .1, 10);
EEG = pop_reref(EEG, []);
% EEG = clean_asr(EEG,[],[],[],[],'off'); -> todo play with settings

for n = 1:length(EEG.chanlocs)
    EEG.chanlocs(n).labels = cfg.eeg.chanloc_newname{n};
end
EEG = pop_chanedit(EEG,'lookup',fullfile(fileparts(which('dipfitdefs')),'standard_BESA','standard-10-5-cap385.elp'));
EEG = eeg_checkset(EEG);

motion = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_MOTION_HTCVive.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);
motion = pop_eegfiltnew(motion, [], 6);

emg = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_PHYSIO.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);

%% movement onset events

motion_tmp = pop_epoch(motion, {cfg.event.move}, cfg.event.win);
mag = squeeze(sqrt(motion_tmp.data(5,:,:).^2 + motion_tmp.data(6,:,:).^2 + motion_tmp.data(7,:,:).^2));
% mag = squeeze(motion_tmp.data(1,:,:));

for i = 1:size(mag,2)
    onset(i) = fR_movement_onset_detector(mag(:,i), .7, 125, .05);
end
dists = size(mag,1) - onset;

% for i = 1:5
%     figure;plot(mag(:,i)); xline(onset(i));
% end

move_ev_ixs = strfind({motion.event.type}', cfg.event.move);
move_ev_ixs = find(~cellfun(@isempty, move_ev_ixs));
move_ev_lats = [EEG.event(move_ev_ixs).latency] - dists;
 
for i = 1:numel(move_ev_lats)
    onsets(i).type = cfg.event.rp;
    onsets(i).latency = move_ev_lats(i);
end

%% select data

EEG.event = onsets;
rp = pop_epoch(EEG, {cfg.event.rp}, cfg.feat.rp_win);
eeg.rp = rp.data - rp.data(:,1,:);
idle = pop_epoch(EEG, {cfg.event.idle}, cfg.feat.idle_win);
eeg.idle = idle.data - idle.data(:,1,:);

emg.event = onsets;
rp = pop_epoch(emg, {cfg.event.rp}, cfg.feat.rp_win);
emg.rp = squeeze(emg_rp.data(2,:,:) - emg_rp.data(2,1,:));
idle = pop_epoch(EEG, {cfg.event.idle}, cfg.feat.idle_win);
emg.idle = squeeze(idle.data(2,:,:)) - idle.data(2,1,:);

motion.event = onsets;
motion_tmp = pop_epoch(motion, {cfg.event.rp}, cfg.feat.move_win);
motion.move = squeeze(sqrt(motion_tmp.data(5,:,:).^2 + motion_tmp.data(6,:,:).^2 + motion_tmp.data(7,:,:).^2));
motion_tmp = pop_epoch(motion, {cfg.event.idle}, cfg.feat.idle_win);
motion.idle = squeeze(sqrt(motion_tmp.data(5,:,:).^2 + motion_tmp.data(6,:,:).^2 + motion_tmp.data(7,:,:).^2));

%% extract informative channels

% rp_ERP_select_channels

%% plot & save

% figure; plot(squeeze(mean(data.rp,3))');title('RP');
% figure; plot(mean(data.emg,2));
% figure; plot(mean(data.vel,2));

eeg = data.rp;
emg = data.emg;
motion = data.vel;

rp = ones(size(eeg,3),1);
idle = zeros(size(rp));
class = [rp]; %;no_rp];
epoch_ix = (1:size(rp))';
class = repelem(class, size(eeg,2));
epoch_ix = repelem(epoch_ix, size(eeg,2));

eeg = eeg(:,:)';
motion = motion(:);
emg = emg(:);

t = array2table([epoch_ix, class, motion, emg, eeg], "VariableNames", ['epoch_ix' 'class' 'motion' 'emg' cfg.eeg.chanloc_newname]);
writetable(t, [cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/data.csv']);

% if ~exist([cfg.study_folder '/eeglab2python/' num2str(cfg.subject)])
%     mkdir([cfg.study_folder '/eeglab2python/' num2str(cfg.subject)]);
% end
% save([cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/eeg.mat'], 'eeg');
% save([cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/emg.mat'], 'emg')
% save([cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/motion.mat'], 'motion')
