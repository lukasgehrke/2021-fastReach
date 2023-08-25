
pID = 11;

%% config
current_sys = "mac";
% eeglab
eeglab_ver(current_sys);

% addpath(genpath('D:\Lukas\signal-processing-motor-intent'));
% addpath('/Users/lukasgehrke/Documents/publications/2021-fastReach/signal_processing');
% addpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent');
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/liblsl-Matlab'))

pi_bemobil_config;

path = '/Volumes/Lukas_Gehrke/fastReach/data/0_source-data/';
% path = 'P:\Lukas_Gehrke\fastReach\data\0_source-data';

%% load data and parse events

% EEG = pop_loadxdf(fullfile(bemobil_config.study_folder, bemobil_config.source_data_folder, ...
%     ['sub-' sprintf('%03d', pID)], 'EMS1.xdf'), ...
%     'streamtype', 'EEG', 'exclude_markerstreams', {});
EEG = pop_loadxdf(fullfile(path, ...
    ['sub-' sprintf('%03d', pID)], 'Baseline.xdf'), ...
    'streamtype', 'EEG', 'exclude_markerstreams', {});

EEG.data(end+1,:) = EEG.data(end,:);

% EEG = pop_eegfiltnew(EMG, 10);
allEventsLats = [EEG.event.latency];

%% instantiate the library
disp('Loading library...');
lib = lsl_loadlib();

% make a new stream outlet
disp('Creating a new streaminfo...');
info = lsl_streaminfo(lib,'Lukas Test EEG','EEG',65,250,'cf_float32','sdfwerr32432');

disp('Opening an outlet...');
outlet = lsl_outlet(info);

% make a new stream outlet
info_marker = lsl_streaminfo(lib,'fastReach_restream','Markers',1,0,'cf_string','sdfwerr32432');
disp('Opening an outlet...');
outlet_marker = lsl_outlet(info_marker);

%% send data into the outlet, sample by sample
disp('Now transmitting data...');

i = 1;
last_event = '';
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

        if ~strcmp(event, last_event)
            disp(event);
            outlet_marker.push_sample({event});
            last_event = event;
        end
    end

end





