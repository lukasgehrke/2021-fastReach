
cfg.subject                = 9;
cfg.fname                  = 'sub-P009_ses-S001_task-Default_run-003_eeg.xdf';

%% run fastReach signal processing training data
% init
eeglab;
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/bemobil-pipeline-sj'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/eeglab_changes/newColormap'));
addpath('/Users/lukasgehrke/Documents/code.nosync/fieldtrip-sj');

% cfg fastReach
cfg.filename               = fullfile(['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/source/sub-P00', ...
    num2str(cfg.subject)], 'ses-S001/eeg/', cfg.fname);
cfg.bids_target_folder     = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/1_bids';                               % required
cfg.task                   = 'fastReach';                         % optional 
cfg.study_folder           = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study';
cfg.session_names          = {'fastReach'};                      % required, enter task name as a string, or enter a cell array when there are multiple sessions in the data set  

cfg.eeg.stream_name        = 'BrainVision RDA';                      % required
cfg.eeg.chanloc_newname    = {'Fp1', 'Fz', 'F3', 'F7', 'FT9', 'FC5', 'FC1', ...
    'C3', 'T7', 'TP9', 'CP5', 'CP1', 'Pz', 'P3', 'P7', 'O1', 'Oz', 'O2', ...
    'P4', 'P8', 'TP10', 'CP6', 'CP2', 'Cz', 'C4', 'T8', 'FT10', 'FC6', ...
    'FC2', 'F4', 'F8', 'Fp2', 'AF7', 'AF3', 'AFz', 'F1', 'F5', 'FT7', ...
    'FC3', 'C1', 'C5', 'TP7', 'CP3', 'P1', 'P5', 'PO7', 'PO3', 'POz', ...
    'PO4', 'PO8', 'P6', 'P2', 'CPz', 'CP4', 'TP8', 'C6', 'C2', 'FC4', ...
    'FT8', 'F6', 'AF8', 'AF4', 'F2', 'VEOG'
    }; % doesn't work

cfg.motion.tracksys{1}.name                    = 'HTCVive';   % required, string, name of the tracking system
                                                                    % in case motion metadata are provided, match with fieldname in "motionInfo.motion.TrackingSystems.(fieldname)"
                                                                    % e.g., motionInfo.motion.TrackingSystems.HTCVive.Manufacturer = 'HTC'; 
cfg.motion.streams{1}.name                     = 'Tracker';      % required, keyword in stream name, searched for in field "xdfdata{streamIndex}.info.name"
cfg.motion.streams{1}.tracksys                 = 'HTCVive';   % required, match with one of the values in "motion.tracksys{}.name"
cfg.motion.streams{1}.tracked_points           = 'Tracker'; %  keyword in channel names, indicating which object (tracked point) is included in the stream
                                                                     % searched for in field "xdfdata{streamIndex}.info.desc.channels.channel{channelIndex}.label"
                                                                     % required to be unique in a single tracking system                                          
% cfg.phys.streams{1}.stream_name          = 'OpenSignals';           % optional
cfg.phys.streams{1}.stream_name          = 'eeg_classifier';           % optional
% cfg.phys.streams{}.stream_name          = 'motion_classifier';           % optional

cfg.other_data_types = {'motion', 'physio'};

%% convert .xdf to bids to set
bemobil_xdf2bids(cfg);
bemobil_bids2set(cfg);

%%

EEG = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_EEG.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);
EEG = pop_eegfiltnew(EEG, .1, 10);

Classifier = pop_loadset('filename', ['sub-' num2str(cfg.subject) '_fastReach_PHYSIO.set'], ...
    'filepath', ['/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/2_raw-EEGLAB/sub-' num2str(cfg.subject)]);

%%

c1 = EEG.data(5,:);
c2 = Classifier.data(2,:);
figure;plot(c1);hold on; plot(c2);
