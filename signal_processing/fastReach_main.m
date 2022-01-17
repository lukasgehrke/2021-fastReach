
% TODO init und cfg auslagern

%% init
eeglab;
addpath(genpath('/Users/lukasgehrke/Documents/code/signal-processing-motor-intent'));
addpath(genpath('/Users/lukasgehrke/Documents/documents.nosync/tools/bemobil-pipeline-sj'));
addpath('/Users/lukasgehrke/Documents/documents.nosync/tools/fieldtrip-sj');

%% cfg

cfg.subject                = 1;                                  % required
cfg.filename               = '/Users/lukasgehrke/Documents/code/fastReach/data/pilot/fastReach-mediation-test.xdf'; % required
cfg.bids_target_folder     = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/1_bids';                               % required
cfg.task                   = 'fastReach';                         % optional 

cfg.eeg.stream_name        = 'BrainVision RDA';                      % required

cfg.motion.streams{1}.stream_name        = 'Rigid_handR';            % required, keyword in stream name                                                                              % searched for in field "xdfdata{streamIndex}.info.name"
cfg.motion.streams{1}.tracking_system    = 'HTCVive';            % required, user-defined name of the tracking system
                                                                            % in case motion metadata are provided, match with fieldname in "motionInfo.motion.TrackingSystems.(fieldname)"
                                                                            % e.g., motionInfo.motion.TrackingSystems.HTCVive.Manufacturer = 'HTC'; 
cfg.motion.streams{1}.tracked_points     = 'Rigid_handR';             % required, keyword in channel names, indicating which object (tracked point) is included in the stream 
                                                                            % searched for in field "xdfdata{streamIndex}.info.desc.channels.channel{channelIndex}.label"
                                                                            % required to be unique in a single tracking system
% cfg.phys.streams{1}.stream_name          = {'OpenSignals'};           % optional

cfg.study_folder           = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/';  % required
cfg.session_names          = {'fastReach'};                      % required, enter task name as a string, or enter a cell array when there are multiple sessions in the data set  

%% convert .xdf to bids to set

bemobil_xdf2bids(cfg);
bemobil_bids2set(cfg);

%% signal processing

EEG = pop_loadset('filename', ['sub-' num2str(cfg.subject)  '_fastReach_EEG.set'], ...
    'filepath', fullfile(cfg.study_folder, '2_raw-EEGLAB', ['sub-' num2str(cfg.subject)]));
motion = pop_loadset('filename', ['sub-' num2str(cfg.subject)  '_fastReach_MOTION_HTCVive.set'], ...
    'filepath', fullfile(cfg.study_folder, '2_raw-EEGLAB', ['sub-' num2str(cfg.subject)]));

% motion
% - filter
motion = pop_eegfiltnew(motion, [], 6);

% eeg
EEG = pop_eegfiltnew(EEG, .1, 10);
% - ASR? EEG = clean_asr(EEG)


%% extract features

%% export