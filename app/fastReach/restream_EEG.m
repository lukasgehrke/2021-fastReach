
eeglab_ver("mac")

% config
pID = 13;
study_folder = '/Users/lukasgehrke/Documents/publications/2021-fastReach/';
subject_folder = fullfile(study_folder, 'data/study/0_raw-data/', num2str(pID));
fname = num2str(pID);

% load data
EEG = pop_loadxdf([fullfile(subject_folder, fname), '.xdf'] , 'streamname', 'BrainVision RDA', 'exclude_markerstreams', {});

% EEG = pop_eegfiltnew(EMG, 10);
allEventsLats = [EEG.event.latency];

%% instantiate the library
disp('Loading library...');
lib = lsl_loadlib();

% make a new stream outlet
disp('Creating a new streaminfo...');
info = lsl_streaminfo(lib,'BrainVision RDA','EEG',64,250,'cf_float32','sdfwerr32432');

disp('Opening an outlet...');
outlet = lsl_outlet(info);

%% send data into the outlet, sample by sample
disp('Now transmitting data...');

i = 1;
while true
    data = double(EEG.data(:,i));
    outlet.push_sample(data);
    pause(0.004);

    i = i + 1;
    if i > size(EEG.data,2)
        i = 1;
    end

    current_ev_ix = max(find(i>allEventsLats));
    if ~isempty(current_ev_ix)
        event = EEG.event(current_ev_ix).type;
        disp(event);
    end

end





