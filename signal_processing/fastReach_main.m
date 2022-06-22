
%% init
eeglab;
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/bemobil-pipeline-sj'));
addpath('/Users/lukasgehrke/Documents/code.nosync/fieldtrip-sj');

%% cfg

plotting = 1;

cfg.overwrite              = 'on';
cfg.subject                = 1;                                  % required

cfg.filename               = '/Users/lukasgehrke/Documents/code.nosync/fastReach/data/pilot/fastReach-mediation-test.xdf'; % required
% cfg.filename               = 'smb://stor1.bpn.tu-berlin.de/projects/Lukas_Gehrke/Willy_Nguyen/willy_test_EEG_EMG_mocapHand_reachEnd.xdf'


cfg.bids_target_folder     = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/1_bids';                               % required
cfg.task                   = 'fastReach';                         % optional 

cfg.eeg.stream_name        = 'BrainVision RDA';                      % required
cfg.eeg.chanloc_newname    = {'Fp1', 'Fz', 'F3', 'F7', 'FT9', 'FC5', 'FC1', ...
    'C3', 'T7', 'TP9', 'CP5', 'CP1', 'Pz', 'P3', 'P7', 'O1', 'Oz', 'O2', ...
    'P4', 'P8', 'TP10', 'CP6', 'CP2', 'Cz', 'C4', 'T8', 'FT10', 'FC6', ...
    'FC2', 'F4', 'F8', 'Fp2', 'AF7', 'AF3', 'AFz', 'F1', 'F5', 'FT7', ...
    'FC3', 'C1', 'C5', 'TP7', 'CP3', 'P1', 'P5', 'PO7', 'PO3', 'POz', ...
    'PO4', 'PO8', 'P6', 'P2', 'CPz', 'CP4', 'TP8', 'C6', 'C2', 'FC4', ...
    'FT8', 'F6', 'AF8', 'AF4', 'F2', 'VEOG'
    }; % doesn't work

cfg.motion.streams{1}.stream_name        = 'Rigid_handR';            % required, keyword in stream name                                                                              % searched for in field 'xdfdata{streamIndex}.info.name'
cfg.motion.streams{1}.tracking_system    = 'HTCVive';            % required, user-defined name of the tracking system
                                                                            % in case motion metadata are provided, match with fieldname in 'motionInfo.motion.TrackingSystems.(fieldname)'
                                                                            % e.g., motionInfo.motion.TrackingSystems.HTCVive.Manufacturer = 'HTC'; 
cfg.motion.streams{1}.tracked_points     = 'Rigid_handR';             % required, keyword in channel names, indicating which object (tracked point) is included in the stream 
                                                                            % searched for in field 'xdfdata{streamIndex}.info.desc.channels.channel{channelIndex}.label'
                                                                            % required to be unique in a single tracking system
% cfg.phys.streams{1}.stream_name          = {'OpenSignals'};           % optional

cfg.study_folder           = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/';  % required
cfg.session_names          = {'fastReach'};                      % required, enter task name as a string, or enter a cell array when there are multiple sessions in the data set  

cfg.event.move             = 'trial_end';
cfg.event.idle             = 'trial_start';
cfg.event.rp               = 'movement_onset';
cfg.event.win              = [-1.5, 0];
cfg.feat.idle_win          = [0, 1];
cfg.feat.rp_win            = [-1, 0];

cfg.n_best_chans           = 20;
cfg.n_wins                 = 10;

%% convert .xdf to bids to set

bemobil_xdf2bids(cfg);
bemobil_bids2set(cfg);

%% signal processing

EEG = pop_loadset('filename', ['sub-' num2str(cfg.subject)  '_fastReach_EEG.set'], ...
    'filepath', fullfile(cfg.study_folder, '2_raw-EEGLAB', ['sub-' num2str(cfg.subject)]));
ori_events = EEG.event;
% [EEG.chanlocs(:).labels] = deal(strrep({EEG.chanlocs.labels},'BrainVision RDA_',''));
% EEG = pop_chanedit(EEG,'lookup',fullfile(fileparts(which('dipfitdefs')),'standard_BESA','standard-10-5-cap385.elp'));
% EEG = eeg_checkset(EEG);

motion = pop_loadset('filename', ['sub-' num2str(cfg.subject)  '_fastReach_MOTION_HTCVive.set'], ...
    'filepath', fullfile(cfg.study_folder, '2_raw-EEGLAB', ['sub-' num2str(cfg.subject)]));

% motion
% - filter
motion = pop_eegfiltnew(motion, [], 6);

% eeg
EEG = pop_eegfiltnew(EEG, .1, 10);
EEG = pop_reref(EEG, []);

% EEG = clean_asr(EEG,[],[],[],[],'off'); -> todo play with settings

%% movement onset events

motion_tmp = pop_epoch(motion, {cfg.event.move}, cfg.event.win);
mag = squeeze(sqrt(motion_tmp.data(5,:,:).^2 + motion_tmp.data(6,:,:).^2 + motion_tmp.data(7,:,:).^2)); 

for i = 1:size(mag,2)
    onset(i) = fR_movement_onset_detector(mag(:,i), .7, 125, .05);
end
dists = size(mag,1) - onset;

move_ev_ixs = strfind({motion.event.type}', cfg.event.move);
move_ev_ixs = find(~cellfun(@isempty, move_ev_ixs));

move_ev_lats = [EEG.event(move_ev_ixs).latency] - dists;
 
for i = 1:numel(move_ev_lats)
    onsets(i).type = cfg.event.rp;
    onsets(i).latency = move_ev_lats(i);
end

if plotting
    EEG.event = onsets;
    EEG_tmp = pop_epoch(EEG, {cfg.event.rp}, [-1 .1]);
    EEG_tmp.data = EEG_tmp.data - EEG_tmp.data(:,1,:);
    figure;plot(squeeze(mean(EEG_tmp.data,3))');title('RP');
end

%% select data

EEG.event = ori_events;
idle = pop_epoch(EEG, {cfg.event.idle}, cfg.feat.idle_win);
idle.data = idle.data - idle.data(:,1,:);
data.idle = idle.data;

EEG.event = onsets;
rp = pop_epoch(EEG, {cfg.event.rp}, cfg.feat.rp_win);
rp.data = rp.data - rp.data(:,1,:);
data.rp = rp.data;

% select most discriminitave channels based on ERP
data.chans_ixs = rp_ERP_select_channels(data.rp, data.idle, 25, plotting);

if plotting
    figure; plot(squeeze(mean(data.rp,3))')
    figure; plot(squeeze(mean(data.idle,3))')
%     [H,P,CI,STATS] = ttest(data.rp(:),data.idle(:))

    disp('channels meeting criteria:')
    {EEG.chanlocs(data.chans_ixs(1:cfg.n_best_chans)).labels}'
    try
        figure;topoplot([],EEG.chanlocs(data.chans_ixs(1:cfg.n_best_chans)),'style','blank','electrodes','labelpoint','chaninfo',EEG.chaninfo);
    catch
        warning('Could not create figure, EEGlab not loaded')
    end
end

%% extract features: ERP windowed means

c_ixs = data.chans_ixs(1:cfg.n_best_chans);
for i = 1:numel(c_ixs)
    for j = 1:cfg.n_wins
    
        step1 = (j-1) * EEG.srate/cfg.n_wins + 1;
        step2 = j * EEG.srate/cfg.n_wins;
    
        data.rp_win_means(i,j,:) = mean(data.rp(c_ixs(i),step1:step2,:),2);
        data.idle_win_means(i,j,:) = mean(data.idle(c_ixs(i),step1:step2,:),2);
    
    end
end


%% LDA test/exploration

rp = ones(size(data.rp_win_means(:),1),1);
idle = zeros(size(rp,1),1);

meas = [data.rp_win_means(:);data.idle_win_means(:)];
classes = [rp;idle];

c = cvpartition(size(classes,1),'Holdout',0.3);
idxTrain = training(c);
idxNew = test(c);

MdlLinear = fitcdiscr(meas(idxTrain), classes(idxTrain));

cvMdl = crossval(MdlLinear); % Performs stratified 10-fold cross-validation
cvtrainError = kfoldLoss(cvMdl)
cvtrainAccuracy = 1-cvtrainError

%% export

%% export data for exploration Willy

EEG.event = ori_events;
idle = pop_epoch(EEG, {cfg.event.idle}, cfg.feat.idle_win);
idle.data = idle.data - idle.data(:,1,:);
eeg_idle = idle.data;

EEG.event = onsets;
rp = pop_epoch(EEG, {cfg.event.rp}, cfg.feat.rp_win);
rp.data = rp.data - rp.data(:,1,:);
eeg_rp = rp.data;

% select most discriminitave channels based on ERP
eeg_chans_ixs = rp_ERP_select_channels(data.eeg.rp, data.eeg.idle, 25, plotting);

motion.event = ori_events;
idle = pop_epoch(motion, {cfg.event.idle}, cfg.feat.idle_win);
idle.data = idle.data - idle.data(:,1,:);
motion_idle = idle.data;

motion.event = onsets;
rp = pop_epoch(motion, {cfg.event.rp}, cfg.feat.rp_win);
rp.data = rp.data - rp.data(:,1,:);
motion_rp = rp.data;

save('eeg_idle.mat', 'eeg_idle')
save('eeg_rp.mat', 'eeg_rp')
save('eeg_chans_ixs.mat', 'eeg_chans_ixs')
save('motion_idle.mat', 'motion_idle')
save('motion_rp.mat', 'motion_rp')


















