%% init
eeglab;
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/bemobil-pipeline-sj'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/eeglab_changes/newColormap'));
addpath('/Users/lukasgehrke/Documents/code.nosync/fieldtrip-sj');

cfg.subject                = 13;

%% run fastReach signal processing training data

cfg.study_folder           = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study';
cfg.eeg.chanloc_newname    = {'Fp1', 'Fz', 'F3', 'F7', 'FT9', 'FC5', 'FC1', ...
    'C3', 'T7', 'TP9', 'CP5', 'CP1', 'Pz', 'P3', 'P7', 'O1', 'Oz', 'O2', ...
    'P4', 'P8', 'TP10', 'CP6', 'CP2', 'Cz', 'C4', 'T8', 'FT10', 'FC6', ...
    'FC2', 'F4', 'F8', 'Fp2', 'AF7', 'AF3', 'AFz', 'F1', 'F5', 'FT7', ...
    'FC3', 'C1', 'C5', 'TP7', 'CP3', 'P1', 'P5', 'PO7', 'PO3', 'POz', ...
    'PO4', 'PO8', 'P6', 'P2', 'CPz', 'CP4', 'TP8', 'C6', 'C2', 'FC4', ...
    'FT8', 'F6', 'AF8', 'AF4', 'F2', 'VEOG'
    };

cfg.event.move             = 'reach:end';
cfg.event.idle             = 'idle:start';
cfg.event.rp               = 'movement_onset';
cfg.event.win              = [-3, -0];
cfg.feat.rp_win            = [-1, 0];
cfg.feat.move_win          = [0, 1];
cfg.feat.idle_win          = [-1, 0];

cfg.EMG_chan               = 2;

cfg.n_best_chans           = 40;
cfg.n_wins                 = 10;

EEG = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_EEG.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);
ori_events = EEG.event;

for n = 1:length(EEG.chanlocs)
    EEG.chanlocs(n).labels = cfg.eeg.chanloc_newname{n};
end
EEG = pop_chanedit(EEG,'lookup',fullfile(fileparts(which('dipfitdefs')),'standard_BESA','standard-10-5-cap385.elp'));
EEG = eeg_checkset(EEG);

Motion = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_MOTION_HTCVive.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);
vel = squeeze(sqrt(diff(Motion.data(4,:)).^2+diff(Motion.data(5,:)).^2+diff(Motion.data(6,:)).^2));
vel = [vel, mean(vel)];
Motion.data(1,:) = vel;

% motion onset and idle event latencies
motion_tmp = pop_epoch(Motion, {cfg.event.move}, cfg.event.win);
mag = squeeze(motion_tmp.data(1,:,:));
for i = 1:size(mag,2)
    onset(i) = fR_movement_onset_detector(mag(:,i), .7, 125, .05);
end
dists = size(mag,1) - onset;

move_ev_ixs = strfind({Motion.event.type}', cfg.event.move);
move_ev_ixs = find(~cellfun(@isempty, move_ev_ixs));
idle_ev_ixs = strfind({Motion.event.type}', cfg.event.idle);
idle_ev_ixs = find(~cellfun(@isempty, idle_ev_ixs));

move_ev_lats = [EEG.event(move_ev_ixs).latency] - dists;
idle_ev_lats = [EEG.event(idle_ev_ixs).latency];

eeg = EEG.data;
motion = Motion.data(1,:);

writematrix(eeg, [cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/eeg.csv']);
writematrix(motion, [cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/motion.csv']);

writematrix(idle_ev_lats, [cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/idle_event_latencies.csv']);
writematrix(move_ev_lats, [cfg.study_folder '/eeglab2python/' num2str(cfg.subject) '/motion_onset_event_latencies.csv']);

