
%% config
current_sys = "mac";
eeglab_ver(current_sys);

pi_bemobil_config;

%% load data and parse events

pIDs = [12, 14:17, 19:23] ; %1:10; % remove also 18 1
cond = {'Baseline'};
cz_ix = 24;
design_erp = [];
design_slope = [];

for pID = pIDs

    %% load
    % load(fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'idle_Baseline.mat'));
    % load(fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'pre_move_Baseline.mat'));

    load(fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'idle_processed.mat'));
    load(fullfile(bemobil_config.study_folder, 'eeglab2python', ['sub-' sprintf('%03d', pID)], 'pre_move_processed.mat'));

    %% get ERP at Cz

    baseline_cond_trials = 70;
    idle = idle(:,:,1:baseline_cond_trials);
    pre_move = pre_move(:,:,1:baseline_cond_trials);

    idle_means = mean(idle,3);
    pre_move_means = mean(pre_move,3);

    % base correct
    idle_means = idle_means - mean(idle_means(:,1:25),2);
    pre_move_means = pre_move_means - mean(pre_move_means(:,1:25),2);

    idle_cz = idle_means(cz_ix,:)';
    pre_move_cz = pre_move_means(cz_ix,:)';
    cz = [idle_cz; pre_move_cz];

    idle_last_win(pID,:) = mean(idle_means(:,226:end),2);
    pre_move_last_win(pID,:) = mean(pre_move_means(:,226:end),2);

    for t = 1:size(idle,3)
        for i = 1:63
            p = polyfit(1:250, idle(i,:,t), 1);
            slope_idle(pID,i,t) = p(1);
        end
    end
    
    for t = 1:size(pre_move,3)
        for i = 1:63
            p = polyfit(1:250, pre_move(i,:,t), 1);
            slope_pre_move(pID,i,t) = p(1);
        end
    end

    slope_idle = mean(slope_idle,3);
    slope_pre_move = mean(slope_pre_move,3);
    slopes = [slope_idle(pID, cz_ix), slope_pre_move(pID, cz_ix)]';
    
    sample = [1:numel(idle_cz), 1:numel(pre_move_cz)]';
    sample = sample / 250;
    id = repelem(pID, numel(cz))';
    cond = cell(1, numel(cz));
    cond(1:numel(idle_cz)) = {'idle'};
    cond(numel(idle_cz):end) = {'pre_move'};
    condition = cond';

    design_tmp = table(id, condition, sample, cz);
    design_erp = [design_erp; design_tmp];

    id = repelem(pID, 2)';
    condition = {'idle', 'pre_move'}';

    design_tmp = table(id, condition, slopes);
    design_slope = [design_slope; design_tmp];

end

% writetable(design_erp, fullfile(bemobil_config.study_folder, 'PI_results_design_erp.csv'));
% writetable(design_slope, fullfile(bemobil_config.study_folder, 'PI_results_design_slope.csv'));

writetable(design_erp, fullfile(bemobil_config.study_folder, 'PI_results_design_erp_processed.csv'));
writetable(design_slope, fullfile(bemobil_config.study_folder, 'PI_results_design_slope_processed.csv'));

% 

load('/Volumes/Lukas_Gehrke/fastReach/data/eeglab2python/locs.mat');

% last_win_p = pre_move_last_win(pIDs,:);
% last_win_p = mean(last_win_p, 1);
% last_win_p = last_win_p(1:63);
% last_win_p_cond = zscore(last_win_p);
% figure; topoplot(last_win_p_cond,locs,'style','map','electrodes','pts','chaninfo',EEG.chaninfo); colorbar; caxis([-2 2]);

slope_p = slope_pre_move(pIDs,:,:);
slope_p = mean(slope_p, 1);
slope_pre_move_cond = zscore(slope_p);
figure('Renderer', 'painters', 'Position', [10 10 200 200]);
topoplot(slope_pre_move_cond,locs,'style','map','electrodes','pts','chaninfo',EEG.chaninfo); colorbar; caxis([-3 3]);

slope_i = slope_idle(pIDs,:,:);
slope_i = mean(slope_i, 1);
slope_idle_cond = zscore(slope_i);
figure('Renderer', 'painters', 'Position', [10 10 200 200]);
topoplot(slope_idle_cond,locs,'style','map','electrodes','pts','chaninfo',EEG.chaninfo); colorbar; caxis([-3 3]);

data = slope_pre_move_cond - slope_idle_cond;
% data = slope_p - slope_i;
figure('Renderer', 'painters', 'Position', [10 10 200 200]);
topoplot(data,locs,'style','map','electrodes','pts','chaninfo',EEG.chaninfo); colorbar; caxis([-3 3]);
