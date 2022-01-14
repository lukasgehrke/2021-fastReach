function [sp] = extract_EEG_features(EEG, onsets, event_str, epoch_classes)
%EXTRACT_EEG_FEATURES Summary of this function goes here
%   Detailed explanation goes her

%% select sample in pre-movement class

EEG_mov = pop_epoch( EEG, {event_str}, epoch_classes{1});

for i = 1:numel(onsets)
    premovement_class(:,:,i) = EEG_mov.data(:,onsets-249:onsets,i);
end

%% select samples in idle class

EEG_idle = pop_epoch( EEG, {event_str}, epoch_classes{2});

%% baseline correct

premovement_class = premovement_class - mean(premovement_class(:,1:25,:),2);
EEG_idle.data = EEG_idle.data - mean(EEG_idle.data(:,1:25,:),2);

%% select discriminatory channels: which channels show negative going RP
% the signal in the last 200ms is smaller than in the first 200ms

for c = 1:numel(EEG.chanlocs)
    sp.rp_move(c,:) = squeezemean(premovement_class(c,end-49:end,:),2) - squeezemean(premovement_class(c,1:50,:),2);
    [H(c),P(c),CI,STATS] = ttest(sp.rp_move(c,:));
    t(c) = STATS.tstat;
end

sp.selected_chans_rp = intersect(find(t<0), find(P < .05));
% {EEG.chanlocs(sp.selected_chans_rp).labels}

%% which channels show the negative going deflection only in the movement class

for c = 1:numel(EEG.chanlocs)
    sp.rp_idle(c,:) = squeezemean(EEG_idle.data(c,end-49:end,:),2) - squeezemean(EEG_idle.data(c,1:50,:),2);
    [H(c),P(c),CI,STATS] = ttest(sp.rp_idle(c,:));
    t(c) = STATS.tstat;
end

sp.selected_chans_rp_class_dep = find(mean(sp.rp_move,2) < mean(sp.rp_idle,2));
% {EEG.chanlocs(sp.selected_chans_rp_class_dep).labels}

%% merge selected channels

sp.selected_channels = intersect(sp.selected_chans_rp, sp.selected_chans_rp_class_dep);
% {EEG.chanlocs(sp.selected_channels).labels}

%%

% chan = 35; % cz24
% figure;
% plot(squeezemean(premovement_class(chan,:,:),3)); hold on;
% plot(squeezemean(EEG_idle.data(chan,:,:),3));
% legend({'movement', 'idle'});

end

