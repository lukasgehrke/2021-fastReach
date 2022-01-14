
% check in with Sein Yeung or Marius Klug to get these two functions below
% to work to read in the .xdf datasets recoreded

% bemobil_xdf2bids
% bemobil_bids2set

% you'll find them in this repo on the dev branch
% https://github.com/BeMoBIL/bemobil-pipeline/tree/dev/import


%%

EEG = pop_loadset('filename','sub-1_preprocessed.set','filepath','/Users/lukasgehrke/Documents/publications/2021-CHI-fastReach/data/3_EEG-preprocessing/sub-1/');
motion = pop_loadset('filename','sub-1_motion_processed.set','filepath','/Users/lukasgehrke/Documents/publications/2021-CHI-fastReach/data/6_single-subject-motion-analysis/sub-1/');
physio = pop_loadset('filename','sub-1__PHYSIO.set','filepath','/Users/lukasgehrke/Documents/publications/2021-CHI-fastReach/data/2_raw-EEGLAB/sub-1/');

events = EEG.event;
motion.event = events;
physio.event = events;

fR.p.movement_class = {'trial_start', [0, 10]};
fR.p.idle_class = {'trial_end', [1, 2]};

% ignore first second after free to move epoch start
fR.p.ignore_early_samples = EEG.srate;

% movement detector for both hand velocity and emg
fR.p.raw_thresh = .7;
fR.p.fine_thresh = .05;
fR.p.window_for_fine_thresh = EEG.srate/2;

% feature windows
fR.p.feature.window_size = EEG.srate;
fR.p.feature.nr_windowed_means = 10;

%% signal processing EEG and Physio data

EEG_filt = pop_eegfiltnew(EEG, .1, 20);
physio = pop_eegfiltnew(physio, .1, 10);

% motion: overwrite random channel with magnitude, only need that!
motion.data(1,:) = sqrt(motion.data(4,:).^2 + motion.data(5,:).^2 + motion.data(6,:).^2);

%% MOVEMENT Class: extract movement onsets from Velocity and EMG

%%% get hand movement onsets and epochs from velocity -> defines movement class for classifier
tmp = pop_epoch(motion, fR.p.movement_class(1), fR.p.movement_class{2});
fR.move.vel.mag = squeeze(tmp.data(1,:,:));
for i = 1:size(fR.move.vel.mag,2)
    if fR.p.ignore_early_samples
        fR.move.vel.onset_sample(i) = fR_movement_onset_detector(fR.move.vel.mag(fR.p.ignore_early_samples:end,i), ...
            fR.p.raw_thresh, fR.p.window_for_fine_thresh, fR.p.fine_thresh);
        fR.move.vel.onset_sample(i) = fR.move.vel.onset_sample(i) + fR.p.ignore_early_samples;
    else
        fR.move.vel.onset_sample(i) = fR_movement_onset_detector(fR.move.vel.mag(:,i), ...
            fR.p.raw_thresh, fR.p.window_for_fine_thresh, fR.p.fine_thresh);
    end 
end

%%% get EMG hand movement onsets and epochs
tmp = pop_epoch(physio, fR.p.movement_class(1), fR.p.movement_class{2});
for i = 1:size(tmp.data,3)
    fR.move.emg.data(:,i) = squeeze(tmp.data(2,:,i));
    [~,fR.move.emg.ylower(:,i)] = envelope(fR.move.emg.data(:,i),1,'peak');
    fR.move.emg.ylower = fR.move.emg.ylower*-1;
    
    if fR.p.ignore_early_samples
        fR.move.emg.onset_sample(i) = fR_movement_onset_detector(fR.move.emg.ylower(fR.p.ignore_early_samples:end,i), ...
            fR.p.raw_thresh, fR.p.window_for_fine_thresh, fR.p.fine_thresh);
        fR.move.emg.onset_sample(i) = fR.move.emg.onset_sample(i) + fR.p.ignore_early_samples;
    else
        fR.move.emg.onset_sample(i) = fR_movement_onset_detector(fR.move.emg.ylower(fR.p.ignore_early_samples:end,i), ...
            fR.p.raw_thresh, fR.p.window_for_fine_thresh, fR.p.fine_thresh);
    end 
    
end

%%% EEG epochs
tmp = pop_epoch(EEG, fR.p.movement_class(1), fR.p.movement_class{2});
fR.move.eeg.raw_data = tmp.data;
tmp = pop_epoch(EEG_filt, fR.p.movement_class(1), fR.p.movement_class{2});
fR.move.eeg.filt_data = tmp.data;

%% IDLE Class

tmp = pop_epoch(motion, fR.p.idle_class(1), fR.p.idle_class{2});
fR.idle.vel.feat = squeeze(tmp.data(1,:,:));

tmp = pop_epoch(physio, fR.p.idle_class(1), fR.p.idle_class{2});
for i = 1:size(tmp.data,3)
    fR.idle.emg.data(:,i) = squeeze(tmp.data(2,:,i));
    [~,fR.idle.emg.ylower(:,i)] = envelope(fR.idle.emg.data(:,i),1,'peak');
    fR.idle.emg.ylower = fR.idle.emg.ylower*-1;
end

tmp = pop_epoch(EEG, fR.p.idle_class(1), fR.p.idle_class{2});
fR.idle.eeg.raw_data = tmp.data; % - tmp.data(:,1,:); % baseline correction
fR.idle.eeg.raw_data_base_corrected = tmp.data - tmp.data(:,1,:); % baseline correction

tmp = pop_epoch(EEG_filt, fR.p.idle_class(1), fR.p.idle_class{2});
fR.idle.eeg.filt_data = tmp.data; %  - tmp.data(:,1,:); % baseline correction
fR.idle.eeg.filt_feat = tmp.data - tmp.data(:,1,:); % baseline correction

%% FEATURES: Data selection

%%% Movement class: select data using velocity onsets
fR.p.bad_trial = [];
for i = 1:numel(fR.move.vel.onset_sample)
    interval = (fR.move.vel.onset_sample(i) - EEG.srate)+1:fR.move.vel.onset_sample(i);
    try
        fR.move.vel.feat(:,i) = fR.move.vel.mag(interval,i) - fR.move.vel.mag(interval(1),i);
        fR.move.emg.feat(:,i) = fR.move.emg.ylower(interval,i) - fR.move.emg.ylower(interval(1),i);
        fR.move.eeg.filt_feat(:,:,i) = fR.move.eeg.filt_data(:,interval,i) - fR.move.eeg.filt_data(:,interval(1),i);
        fR.move.eeg.raw_feat(:,:,i) = fR.move.eeg.raw_data(:,interval,i) - fR.move.eeg.raw_data(:,interval(1),i);
    catch
        fR.p.bad_trial = [fR.p.bad_trial, i];
    end
end

% %%% (Robust) Windowed Means
% % EMG: windowed means
% % EEG: regress out horizontal eye movements for each (robust) windowed mean
% for w = 2%1:fR.p.feature.nr_windowed_means
%     w_step = EEG.srate/fR.p.feature.nr_windowed_means;
%     w_end = w*w_step;
%     w_start = w_end-w_step+1;
%     win = w_start:w_end;
%     
%     tic
%     for i = 1:numel(fR.move.vel.onset_sample)
%         
%         eye_move = fR.move.eeg.filt_feat(64,win,i)';
%         eye_idle = fR.idle.eeg.filt_data(64,win,i)';
%         
%         fR.move.emg.feat_windowed = fR.move.emg.feat(win,i);
%         fR.idle.emg.feat_windowed = fR.idle.emg.data(win,i);
% 
%         for c = 1:numel(EEG.chanlocs)
%             
%             eeg_move = fR.move.eeg.filt_feat(c,win,i)';
%             eeg_idle = fR.idle.eeg.filt_data(c,win,i)';
% 
%             design = table(eye_move,eeg_move,eye_idle,eeg_idle);
%             mdl_move = fitlm(design, 'eeg_move ~ eye_move'); % 
%             mdl_idle = fitlm(design, 'eeg_idle ~ eye_idle'); %
% 
%             fR.move.eeg.filt_feat_eye_clean(c,w,i) = mdl_move.Coefficients.Estimate(1);
%             fR.idle.eeg.filt_data_eye_clean(c,w,i) = mdl_idle.Coefficients.Estimate(1);
%         end
%     end
%     toc
% end

% save results

%% EEG Channel Selection
% criterium 1: Which channels show negative going RP, i.e., the signal in the last 200ms is smaller than in the first 200ms
for c = 1:numel(EEG.chanlocs)
    fR.move.eeg.rp.feat_eye_clean_diff(c,:) = fR.move.eeg.filt_feat(c,end,:) - fR.move.eeg.filt_feat(c,1,:);
    
    [fR.move.eeg.rp.H(c), ...
        fR.move.eeg.rp.P(c), ~, STATS] = ttest(fR.move.eeg.rp.feat_eye_clean_diff(c,:));
    fR.move.eeg.rp.t(c) = STATS.tstat;
end
fR.move.eeg.rp.rp_chans = intersect(find(fR.move.eeg.rp.t>0), find(fR.move.eeg.rp.P < .05));

% criterium 2: which channels show the negative going deflection only in the movement class
for c = 1:numel(EEG.chanlocs)
    fR.idle.eeg.rp.feat_eye_clean_diff(c,:) = fR.idle.eeg.filt_feat(c,end,:) - fR.idle.eeg.filt_feat(c,1,:);
    
    [fR.idle.eeg.rp.H(c), ...
        fR.idle.eeg.rp.P(c), ~, STATS] = ttest(fR.idle.eeg.rp.feat_eye_clean_diff(c,:));
    fR.idle.eeg.rp.t(c) = STATS.tstat;
end
fR.move.eeg.rp.rp_chans_idle = find(mean(fR.move.eeg.rp.feat_eye_clean_diff,2) > ...
    mean(fR.idle.eeg.rp.feat_eye_clean_diff,2));

% save channel info
fR.move.eeg.rp.selected_channels = intersect(fR.move.eeg.rp.rp_chans, ...
    fR.move.eeg.rp.rp_chans_idle);
fR.move.eeg.rp.removed_channels = 1:numel(EEG.chanlocs);
fR.move.eeg.rp.removed_channels(fR.move.eeg.rp.selected_channels) = [];
fR.move.eeg.rp.selected_channels_labels = {EEG.chanlocs(fR.move.eeg.rp.selected_channels).labels};

%%
% %% plot feature
% 
% test = squeezemean(fR.move.eeg.filt_feat,3)';
% % test = 1-fR.move.eeg.rp.t;
% test(:,fR.move.eeg.rp.removed_channels) = [];
% 
% figure;plot(test);legend(fR.move.eeg.rp.selected_channels_labels)
% xlabel('samples')
% ylabel('amplitude')
% 
% %% plots
% fR.move.eeg.rp.selected_channels_labels
% % test = mean(fR.move.eeg.rp.feat_eye_clean_diff,2);
% test = 1-fR.move.eeg.rp.t;
% test(fR.move.eeg.rp.removed_channels) = 0;
% figure;topoplot(test', EEG.chanlocs, 'electrodes', 'labels');
% title('tscore RP (first win - last win)');
% 
% % move = squeeze(fR.move.eeg.filt_feat(24,1:250,:));
% % idle = squeeze(fR.idle.eeg.filt_data(24,1:250,:));
% 
% move = squeeze(fR.move.eeg.filt_feat_eye_clean(25,:,:));
% idle = squeeze(fR.idle.eeg.filt_data_eye_clean(25,:,:));
% 
% colors = brewermap(5, 'Spectral');
% colors1 = colors(2, :);
% figure; ploterp_lg(move', [], [], 10, 1, '\muV', 'time to movement onset (s)', [-20, 10], colors1, '-.'); hold on
% ploterp_lg(move', [], [], 10, 1, '\muV', 'time to movement onset (s)', [-20, 10], colors1, '-.'); hold on
% 
% colors2 = colors(5, :);
% ploterp_lg(idle', [], [], 10, 1, '', '', [-20 10], colors2, '-.');
% legend('','move','idle','');

%% add timestamps of movement onset on the cont. data

allEventTypes = {EEG.event.type}';
keywordIdx = find(strcmp(allEventTypes, fR.p.movement_class{1}));
lats_epchs = [EEG.event(keywordIdx).latency];

lats_move_onsets = lats_epchs' + fR.move.vel.onset_sample';
EEG_ts = EEG.data(fR.move.eeg.rp.selected_channels,:);