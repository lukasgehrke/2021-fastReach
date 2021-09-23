function [sp] = extract_physio_features(events, physio, event_str, epoch, buffer)

%% signal processing
physio = pop_eegfiltnew(physio, .1, 10);

%% events
physio.event = events;
physio = eeg_checkset(physio);
physio = pop_epoch( physio, {event_str}, epoch);

%% EMG
for i = 1:size(physio.data,3)
    sp.emg.data(i,:) = squeeze(physio.data(2,:,i));
    [~,sp.emg.ylower(i,:)] = envelope(sp.emg.data(i,:),1,'peak');
    
    if buffer
        sp.emg.onset_sample(i) = fR_movement_onset_detector(sp.emg.ylower(i,buffer:end)*-1, .7, 125, .05);
        sp.emg.onset_sample(i) = sp.emg.onset_sample(i) + buffer;        
    else
        sp.emg.onset_sample(i) = fR_movement_onset_detector(sp.emg.ylower(i,:)*-1, .7, 125, .05);
    end 
    
end

%% EDA

end

