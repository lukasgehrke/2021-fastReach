%% config
current_sys = "mac";
eeglab_ver(current_sys);

%%

EEG = pop_loadset('filename',{'sub-3_EMS1_EEG.set','sub-3_EMS1_PHYSIO.set'},'filepath','/Volumes/projects/Lukas_Gehrke/2021-fastReach/data/study/2_raw-EEGLAB/sub-3/');
EEG = EEG(1);
EEG.event = EEG.event(find(contains({EEG.event.type}, 'reach_end')));

%%

[EEG.event.type] = deal('reach_end');
EEG = pop_epoch(EEG, {'reach_end'}, [-1, 0]);

%%

figure;plot(squeeze(mean(EEG.data(25,:,:),3)))

% figure;plot(squeeze(EEG.data(end,:,:)))