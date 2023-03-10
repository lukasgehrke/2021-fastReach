
pID = 2;

%% config
current_sys = "mac";
% eeglab
eeglab_ver(current_sys);

% addpath(genpath('D:\Lukas\signal-processing-motor-intent'));
%addpath('/Users/lukasgehrke/Documents/publications/2021-fastReach/signal_processing');
addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');

pi_bemobil_config;

%% load data and parse events

EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, 'study', bemobil_config.source_data_folder, ...
    ['sub-' sprintf('%03d', pID)], 'EMS1.xdf'), ...
    'streamtype', 'EEG', 'exclude_markerstreams', {});

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





