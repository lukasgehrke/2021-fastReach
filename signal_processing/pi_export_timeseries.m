%% processing loop

for subject = subjects

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

    vel = squeeze(sqrt(diff(Motion.data(4,:)).^2+diff(Motion.data(5,:)).^2+diff(Motion.data(6,:)).^2));
    Motion.data(1,:) = [vel, mean(vel)];

    motion_tmp = pop_epoch(Motion, {bemobil_config.event.move}, bemobil_config.event.win);
    mag = squeeze(motion_tmp.data(1,:,:));
    for i = 1:size(mag,2)
        onset(i) = fR_movement_onset_detector(mag(:,i), .7, 125, .05);
    end
    dists = size(mag,1) - onset;

    move_ev_ixs = strfind({Motion.event.type}', bemobil_config.event.move);
    move_ev_ixs = find(~cellfun(@isempty, move_ev_ixs));
    idle_ev_ixs = strfind({Motion.event.type}', bemobil_config.event.idle);
    idle_ev_ixs = find(~cellfun(@isempty, idle_ev_ixs));

    move_ev_lats = [EEG.event(move_ev_ixs).latency] - dists;
    idle_ev_lats = [EEG.event(idle_ev_ixs).latency];

    eeg = EEG.data;
    motion = Motion.data(1,:);
    emg = Physio.data(bemobil_config.EMG_chans,:);
    gaze = Physio.data(bemobil_config.Gaze_chan,:);

    writematrix(eeg, [bemobil_config.study_folder '/eeglab2python/' num2str(subject) '/eeg.csv']);
    writematrix(motion, [bemobil_config.study_folder '/eeglab2python/' num2str(subject) '/motion.csv']);
    writematrix(emg, [bemobil_config.study_folder '/eeglab2python/' num2str(subject) '/emg.csv']);
    writematrix(gaze, [bemobil_config.study_folder '/eeglab2python/' num2str(subject) '/gaze.csv']);

    writematrix(idle_ev_lats, [bemobil_config.study_folder '/eeglab2python/' num2str(subject) '/idle_event_latencies.csv']);
    writematrix(move_ev_lats, [bemobil_config.study_folder '/eeglab2python/' num2str(subject) '/motion_onset_event_latencies.csv']);

    disp('Timeseries export done!');
end
