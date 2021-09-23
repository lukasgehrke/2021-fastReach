motion = pop_loadset('filename','sub-1_motion_processed.set','filepath','/Users/lukasgehrke/Documents/publications/2021-CHI-fastReach/data/6_single-subject-motion-analysis/sub-1/');
EEG = pop_loadset('filename','sub-1_preprocessed.set','filepath','/Users/lukasgehrke/Documents/publications/2021-CHI-fastReach/data/3_EEG-preprocessing/sub-1/');
physio = pop_loadset('filename','sub-1__PHYSIO.set','filepath','/Users/lukasgehrke/Documents/publications/2021-CHI-fastReach/data/2_raw-EEGLAB/sub-1/');

ignore_early_samples = 250;
events = EEG.event;

%% signal processing
sp_move = extract_motion_features(events,motion,'trial_start',[0, 10],ignore_early_samples);

sp_eeg = extract_EEG_features(EEG,sp_move.onset_sample,'trial_start',{[0, 10],[-3, -2]});

sp_physio = extract_physio_features(events,physio,'trial_start',[0, 10],ignore_early_samples);

%% plot movement onset detection using EMG envelope and Velocity data

sp_physio.emg.data = sp_physio.emg.data';
sp_physio.emg.ylower = sp_physio.emg.ylower';

%% align data using velocity onsets

for i = 1:size(sp_move.mag,2)
    interval = sp_move.onset_sample(i)-ceil(EEG.srate/4):sp_move.onset_sample(i)+(EEG.srate/4);
    vel(:,i) = sp_move.mag(interval,i) - sp_move.mag(interval(1),i);
    emg(:,i) = sp_physio.emg.data(interval,i) - sp_physio.emg.data(interval(1),i);
    env(:,i) = sp_physio.emg.ylower(interval,i) - sp_physio.emg.ylower(interval(1),i);
end

vel = vel';
env = env';
emg = emg';

%% plot single trial

normal;
figure('visible','on', 'Renderer', 'painters', 'Position', [10 10 600 500]);

plot(vel(1,:),'LineWidth',2); hold on;
plot(env(1,:),'LineWidth',2);
plot(emg(1,:),'LineWidth',2);
legend('vel','emg envelope','emg');

ylim([-.2,.2]);

% add markers
markers = [EEG.srate/4];
markers_label = {'onset vel'};
for i = 1:numel(markers)
    [l, h] = vline(markers(i),'.',markers_label{i});
    l.LineStyle = '-';
    l.LineWidth = 3;
    l.Color = 'k';
    h.Color = 'k';
    h.FontSize = 24;
end

set(gca,'FontSize',24)

print(gcf, [save_path 'vel_emg_single_trial_ori.eps'], '-depsc');
close(gcf);

%% difference onsets emg and vel

env = -1*env;
emg = -1*emg;
onset_emg = round(mean(sp_move.onset_sample) - mean(sp_physio.emg.onset_sample)) / EEG.srate;

normal;
figure('visible','on', 'Renderer', 'painters', 'Position', [10 10 600 500]);

% plot condition 1
colors = brewermap(5, 'Spectral');
colors1 = colors(2, :);
ploterp_lg(vel, [], [], ceil(EEG.srate/4), 1, 'a.u.', 'time (s)', [-.02, .1], colors1, '-');
hold on

% plot condition 2
colors2 = colors(5, :);
ploterp_lg(env, [], [], ceil(EEG.srate/4), 1, '', '', [-.02, .1], colors2, '-.');

colors3 = colors(4, :);
ploterp_lg(emg, [], [], ceil(EEG.srate/4), 1, '', '', [-.02, .1], colors3, '-.');
legend('','vel','','','emg envelope','','','emg');

% add markers
markers = [onset_emg];
markers_label = {'onset emg'};
for i = 1:numel(markers)
    [l, h] = vline(markers(i),'.',markers_label{i});
    
    if i<= 2
        l.LineStyle = '-.';
    else
        l.LineStyle = ':';
    end
    l.Color = colors2;
    h.Color = colors2;
    l.LineWidth = 3;
    h.FontSize = 24;
end

save_path = '/Users/lukasgehrke/Documents/publications/2021-CHI-fastReach/figures/';
mkdir(save_path)
print(gcf, [save_path 'vel_emg.eps'], '-depsc');
close(gcf);
