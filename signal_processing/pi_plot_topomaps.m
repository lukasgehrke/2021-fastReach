%% plot topomap

current_sys = "mac";
pi_bemobil_config;

load('/Volumes/Lukas_Gehrke/fastReach/data/eeglab2python/locs.mat');

% load csv scores and concatenate to one matrix
pIDs = [12, 14:17, 19:23] ; %1:10; % remove also 18 1

% what is all_chans_score_order and what does it mean???
for pID = pIDs
    tmp = readtable(fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'all_chans_score_order.csv'));
    all_chans_score_order(pID,:) = tmp.Var1;
end
all_chans_score_order = all_chans_score_order(pIDs,:);


slope_pre_move = slope_pre_move(pIDs,:,:);
slope_pre_move(slope_pre_move == 0) = NaN;

slope = nanmean(slope_pre_move, 3);
slope = mean(slope, 1);

% slope = mean(slope_pre_move(pIDs,:),1);
% slope = mean(slope_idle(pIDs,:),1);
% slope(end) = 0;

slope = zscore(slope);

% topoplot(slope, EEG.chanlocs)
figure; topoplot(slope,locs,'style','map','electrodes','labelpoint','chaninfo',EEG.chaninfo);