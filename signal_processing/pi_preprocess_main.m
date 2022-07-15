% LG to run:
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/signal-processing-motor-intent'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/bemobil-pipeline-sj'));
addpath(genpath('/Users/lukasgehrke/Documents/code.nosync/eeglab_changes/newColormap'));
addpath('/Users/lukasgehrke/Documents/code.nosync/fieldtrip-sj');
addpath('/Users/lukasgehrke/Documents/publications/2021-fastReach/signal_processing/');

% initialize EEGLAB 
if ~exist('ALLCOM','var')
	eeglab;
end

% load configuration 
pi_bemobil_config;

% enter subject number
subjects = 2;

%% preprocess
pi_import;
pi_preprocess_EEG;
pi_preprocess_Motion;

%% export features

% % change if interested in different wins
% bemobil_config.feat.rp_wins           = {[-1, 0], [-.1, 0]};
% bemobil_config.feat.idle_wins         = {[-6, -5], [-5.1, -5]};
% 
% bemobil_config.eeg_srate              = 250;
% bemobil_config.physio_srate           = 1000; % both EMG and Eye
% bemobil_config.motion_srate           = 250;
% 
% % leave the below as is
% bemobil_config.event.move             = 'grab';
% bemobil_config.event.idle             = 'movement_onset';
% bemobil_config.event.rp               = 'movement_onset';
% bemobil_config.event.win              = [-3, -0];
% 
% bemobil_config.EMG_chans              = [8, 9];
% bemobil_config.Gaze_chan              = [1];
% 
% bemobil_config.n_best_chans           = 20; % for EEG
% bemobil_config.n_wins                 = 10; % for EEG
% 
% for i = 1:numel(bemobil_config.feat.rp_wins)
%     
%     bemobil_config.feat.rp_win = bemobil_config.feat.rp_wins{i};
%     bemobil_config.feat.idle_win = bemobil_config.feat.idle_wins{i};
% 
%     movint_export_features;
%     movint_export_timeseries;
% 
% end
