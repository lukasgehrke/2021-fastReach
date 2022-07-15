%% processing loop

for subject = subjects
    
    %% prepare filepaths and check if already done
    
	disp(['Subject #' num2str(subject)]);
	STUDY = []; CURRENTSTUDY = 0; ALLEEG = [];  CURRENTSET=[]; EEG=[]; EEG_interp_avref = []; EEG_single_subject_final = [];

	% load completely processed files
    input_filepath = [bemobil_config.study_folder bemobil_config.single_subject_analysis_folder bemobil_config.filename_prefix num2str(subject)];
	EEG = pop_loadset('filename', [ bemobil_config.filename_prefix num2str(subject)...
		'_' bemobil_config.single_subject_cleaned_ICA_filename], 'filepath', input_filepath);
    EEG = movint_clean_and_parse_events(EEG);

    input_filepath = [bemobil_config.study_folder bemobil_config.motion_analysis_folder bemobil_config.filename_prefix num2str(subject)];
	Motion = pop_loadset('filename', [ bemobil_config.filename_prefix num2str(subject)...
		'_' bemobil_config.processed_motion_filename], 'filepath', input_filepath);

    input_filepath = [bemobil_config.study_folder bemobil_config.physio_analysis_folder bemobil_config.filename_prefix num2str(subject)];
	Physio = pop_loadset('filename', [ bemobil_config.filename_prefix num2str(subject)...
		'_' bemobil_config.processed_physio_filename], 'filepath', input_filepath);

    Motion.event = EEG.event;
    Physio.event = EEG.event;

    %% add features: ERP, EMG, EYE  

    bemobil_config.filter_plot_low = .1;
    bemobil_config.filter_plot_high = 10;

    % detect movement onsets
    vel = squeeze(sqrt(diff(Motion.data(4,:)).^2+diff(Motion.data(5,:)).^2+diff(Motion.data(6,:)).^2));
    Motion.data(1,:) = [vel, mean(vel)];

    % add gaze velocity
    gaze_vel = squeeze(sqrt(diff(Physio.data(14,:)).^2+diff(Physio.data(15,:)).^2+diff(Physio.data(16,:)).^2));
    Physio.data(bemobil_config.Gaze_chan,:) = [gaze_vel, mean(gaze_vel)];

    motion_tmp = pop_epoch(Motion, {bemobil_config.event.move}, bemobil_config.event.win);
    mag = squeeze(motion_tmp.data(1,:,:));
    for i = 1:size(mag,2)
        onset(i) = fR_movement_onset_detector(mag(:,i), .7, 125, .05);
    end
    dists = size(mag,1) - onset;
    
    move_ev_ixs = strfind({Motion.event.type}', bemobil_config.event.move);
    move_ev_ixs = find(~cellfun(@isempty, move_ev_ixs));
    move_ev_lats = [Motion.event(move_ev_ixs).latency] - dists;
     
    for i = 1:numel(move_ev_lats)
        onsets(i).type = bemobil_config.event.rp;
        onsets(i).latency = move_ev_lats(i);
    end
    
    %% select data
    
    ori_events = EEG.event;
    EEG.event = onsets;

    EEG = pop_resample(EEG, bemobil_config.eeg_srate);
    idle = pop_epoch(EEG, {bemobil_config.event.idle}, bemobil_config.feat.idle_win);
    rp = pop_epoch(EEG, {bemobil_config.event.rp}, bemobil_config.feat.rp_win);
    
    % EEG: find ~10% noisiest epoch indices by searching for large amplitude
    % fluctuations on the channel level using eeglab auto_rej function
    [~, noisy_epochs] = pop_autorej(rp, 'nogui','on','eegplot','off');

    EEG.event = ori_events;

    %% features
    
    if ~exist([bemobil_config.study_folder '/eeglab2python/' num2str(subject)])
        mkdir([bemobil_config.study_folder '/eeglab2python/' num2str(subject)]);
        mkdir([bemobil_config.study_folder '/out_figures/' num2str(subject)]);
    end

    % EEG
    idle.data = idle.data - idle.data(:,1,:);
    rp.data = rp.data - rp.data(:,1,:);
    
    % select most discriminatory EEG channels
    samples_win = abs(bemobil_config.feat.rp_win(1)*EEG.srate);
    [best_chans_ixs, crit1, crit2] = rp_ERP_select_channels(rp.data, idle.data, ceil(samples_win/bemobil_config.n_wins), 0); % extract informative channels
    sel_chans = best_chans_ixs(1:bemobil_config.n_best_chans);

    feats.eeg.idle = idle.data(sel_chans,:,:);
    feats.eeg.rp = rp.data(sel_chans,:,:);
    
    % save
    chans = array2table([sel_chans], "VariableNames", {'chans'});
    writetable(chans, [bemobil_config.study_folder '/eeglab2python/' num2str(subject) '/chans.csv']);
    figure;
    val = zscore(mean(crit1,2));
    topoplot(val,EEG.chanlocs(sel_chans),'headrad',.5,'electrodes','pts','chaninfo',EEG.chaninfo);
    title("raw data")
    cbar;
    saveas(gcf,[bemobil_config.study_folder 'out_figures/' num2str(subject) '/scalp_map_s' num2str(subject) ...
        '_rp-win_' num2str(bemobil_config.feat.rp_win(1)) '-' num2str(bemobil_config.feat.rp_win(2))], 'epsc');
    close(gcf);

    % EMG
    Physio.event = onsets;
    Physio = pop_resample(Physio, bemobil_config.physio_srate);
    idle = pop_epoch(Physio, {bemobil_config.event.idle}, bemobil_config.feat.idle_win);
    rp = pop_epoch(Physio, {bemobil_config.event.rp}, bemobil_config.feat.rp_win);
    feats.emg.idle = idle.data(bemobil_config.EMG_chans,:,:); % - idle.data(bemobil_config.EMG_chan,1,:));
    feats.emg.rp = rp.data(bemobil_config.EMG_chans,:,:); % - rp.data(bemobil_config.EMG_chan,1,:));

    % Eye
    feats.eye.idle = idle.data(bemobil_config.Gaze_chan,:,:); % - idle.data(bemobil_config.EMG_chan,1,:));
    feats.eye.rp = rp.data(bemobil_config.Gaze_chan,:,:); % - rp.data(bemobil_config.EMG_chan,1,:));

    % Motion
    Motion.event = onsets;
    Motion = pop_resample(Motion, bemobil_config.motion_srate);
    idle = pop_epoch(Motion, {bemobil_config.event.idle}, bemobil_config.feat.idle_win);
    rp = pop_epoch(Motion, {bemobil_config.event.rp}, bemobil_config.feat.rp_win);
    feats.motion.idle = idle.data(1,:,:);
    feats.motion.rp = rp.data(1,:,:);

    % Eye intersect
    wait_ev_ixs = find(ismember({EEG.event.type}', 'pre_move'));
    grab_ev_ixs = find(ismember({EEG.event.type}', 'grab'));
    for i = 1:numel(wait_ev_ixs)
        eye_lats = [EEG.event((wait_ev_ixs(i)+1):(grab_ev_ixs(i)-1)).latency];
        fix_dur = diff(eye_lats);
        fix_dur = fix_dur(1:2:end);
        balls = {EEG.event((wait_ev_ixs(i)+1):(grab_ev_ixs(i)-1)).object};
        balls = balls(1:2:end-1);

        ball1 = find(ismember(balls, 'ball1'));
        ball2 = find(ismember(balls, 'ball2'));

        ball1_dur = sum(fix_dur(ball1));
        ball2_dur = sum(fix_dur(ball2));

        if ball1_dur > ball2_dur
            winner = 'ball1';
        else
            winner = 'ball2';
        end
        ball_prediction{i} = winner;
    end
    grabbed_balls = {EEG.event(grab_ev_ixs).ball};
    prediction = cellfun(@strcmp, ball_prediction, grabbed_balls);
    performance = sum(prediction) / numel(prediction);

    writetable(table(performance), [bemobil_config.study_folder '/eeglab2python/' num2str(subject) '/fixation_performance_s' num2str(subject) '.csv']);

    %% make design matrix

    feats.eeg.rp(:,:,noisy_epochs) = [];
    feats.eeg.idle(:,:,noisy_epochs) = [];
    feats.emg.rp(:,:,noisy_epochs) = [];
    feats.emg.idle(:,:,noisy_epochs) = [];
    feats.eye.rp(:,noisy_epochs) = [];
    feats.eye.idle(:,noisy_epochs) = [];
    feats.motion.rp(:,noisy_epochs) = [];
    feats.motion.idle(:,noisy_epochs) = [];

    % loop over modalities
    modalities = {'eeg', 'emg', 'eye', 'motion'};

    for mod = modalities

        mod = mod{1};

        rp = ones(size(feats.(mod).rp,3),1);
        idle = ones(size(feats.(mod).idle,3),1)*2;
        rp_class = [rp;idle];
        epoch_ix = (1:size(rp_class))';

        switch mod
            case 'eeg'
                srate = EEG.srate;
                var_name = {EEG.chanlocs(sel_chans).labels};
            case 'emg'
                srate = Physio.srate;
                var_name = {'EMG1', 'EMG2'};
            case 'eye'
                srate = Physio.srate;
                var_name = {'GazeVel'};
            case 'motion'
                srate = Motion.srate;
                var_name = {'HandVel'};
        end
        sample = (1:size(feats.(mod).rp,2))' / srate - 1;
        
        sample = repmat(sample, size(rp_class,1),1);
        rp_class = repelem(rp_class, size(feats.(mod).rp,2));
        epoch_ix = repelem(epoch_ix, size(feats.(mod).rp,2));
    
        % add features
        features = [feats.(mod).rp(:,:)'; feats.(mod).idle(:,:)'];

%         EEG_out = [feats.eeg.rp(:,:)'; feats.eeg.idle(:,:)'];
%         Motion_out = [feats.motion.rp(:); feats.motion.idle(:)];
%         EMG_out = [feats.emg.rp(:,:)'; feats.emg.idle(:,:)'];
%         Eye_out = [feats.eye.rp(:); feats.eye.idle(:)];
%         t = array2table([sample, epoch_ix, rp_class, Motion_out, EMG_out, Eye_out, EEG_out], ...
%             "VariableNames", ['sample', 'epoch_ix' 'rp_class' 'HandVel' 'EMG1' 'EMG2' 'GazeVel' {EEG.chanlocs(sel_chans).labels}]);

        t = array2table([sample, epoch_ix, rp_class, features], ...
            "VariableNames", [{'sample', 'epoch_ix', 'rp_class'}, var_name]);
    
        writetable(t, [bemobil_config.study_folder '/eeglab2python/' num2str(subject) ...
            '/data_s' num2str(subject) ...
            '_rp-win_' num2str(bemobil_config.feat.rp_win(1)) '-' num2str(bemobil_config.feat.rp_win(2)) ...
            '_srate-' num2str(srate) ...
            '_modality-' mod ...
            '.csv']);

    end

    disp('Data export done!');

end


