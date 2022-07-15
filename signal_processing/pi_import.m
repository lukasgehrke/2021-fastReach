% addpath('P:\Lukas_Gehrke\toolboxes\eeglab');
% addpath(genpath('P:\Lukas_Gehrke\toolboxes\bemobil-pipeline'));
% 
% eeglab; % start eeglab to add bemobil pipeline to matlab path

rmpath(fileparts(which('ft_defaults'))) % remove the fieldtrip version that is in the pipeline
% addpath('P:\Marius\Project_BIDS\fieldtrip-motion2bids-2022-04-26') % add the modded fieldtrip 

studyFolder                         = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/';
sessionNames                        = {'pi'};

% general metadata shared across all modalities
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
generalInfo = [];

% required for dataset_description.json
generalInfo.dataset_description.Name                = 'Preconscious Interaction';
generalInfo.dataset_description.BIDSVersion         = 'unofficial extension';

% optional for dataset_description.json
generalInfo.dataset_description.License             = 'CC BY';
generalInfo.dataset_description.Authors             = {'Lukas Gehrke'};
generalInfo.dataset_description.Acknowledgements    = 'n/a';
generalInfo.dataset_description.Funding             = {''};
generalInfo.dataset_description.ReferencesAndLinks  = {};
generalInfo.dataset_description.DatasetDOI          = 'n/a';

% general information shared across modality specific json files 
generalInfo.InstitutionName                         = 'Technische Universitaet Berlin';
generalInfo.InstitutionalDepartmentName             = 'Biological Psychology and Neuroergonomics';
generalInfo.InstitutionAddress                      = 'Strasse des 17. Juni 135, 10623, Berlin, Germany';
generalInfo.TaskDescription                         = 'Participants equipped with VR HMD performed an object selection task.';
 

% information about the eeg recording system 
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
eegInfo     = [];
% eegInfo.coordsystem.EEGCoordinateSystem             = 'Other'; 
% eegInfo.coordsystem.EEGCoordinateUnits              = 'mm'; 

                                                   
% information about the motion recording system 
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
motionInfo  = []; 

% must not contain underscores!
tracking_systems{1}                                 = 'SteamVRTracker'; 

% motion specific fields in json
motionInfo.motion = [];
motionInfo.motion.RecordingType                     = 'continuous';

% system 1 information
motionInfo.motion.TrackingSystems(1).TrackingSystemName               = tracking_systems{1};
motionInfo.motion.TrackingSystems(1).Manufacturer                     = 'HTC';
motionInfo.motion.TrackingSystems(1).ManufacturersModelName           = 'Vive';
motionInfo.motion.TrackingSystems(1).SamplingFrequency                = 'n/a'; %  If no nominal Fs exists, 'n/a' entry returns 'n/a'. If it exists, n/a entry returns nominal Fs from motion stream.

% coordinate system
motionInfo.coordsystem.MotionCoordinateSystem      = 'RUF';
motionInfo.coordsystem.MotionRotationRule          = 'left-hand';
motionInfo.coordsystem.MotionRotationOrder         = 'ZXY';


% participant information 
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
subjectInfo = [];
% here describe the fields in the participant file
% for numerical values  : 
%       subjectData.fields.[insert your field name here].Description    = 'describe what the field contains';
%       subjectData.fields.[insert your field name here].Unit           = 'write the unit of the quantity';
% for values with discrete levels :
%       subjectData.fields.[insert your field name here].Description    = 'describe what the field contains';
%       subjectData.fields.[insert your field name here].Levels.[insert the name of the first level] = 'describe what the level means';
%       subjectData.fields.[insert your field name here].Levels.[insert the name of the Nth level]   = 'describe what the level means';
%--------------------------------------------------------------------------

%%
% loop over participants
% subjects = 2;

%
for subject = subjects

    config                        = [];                                 % reset for each loop 
    config.bids_target_folder     = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/1_BIDS-data'; % required
    
    config.filename               = fullfile(['/Users/lukasgehrke/Documents/publications/2021-fastReach/0_raw-data/s' num2str(subject) '/s' num2str(subject) '_' sessionNames{1} '.xdf']); % required

    config.task                   = 'PreconsciousInteraction';                           % optional
    config.subject                = subject;                            % required
    config.session                = sessionNames{1};              % required if there are more than 1 session
    config.overwrite              = 'on';
    
    config.eeg.stream_name        = 'BrainVision';                      % required
    config.eeg.chanloc_newname    = {'Fp1', 'Fz', 'F3', 'F7', 'FT9', 'FC5', 'FC1', ...
        'C3', 'T7', 'TP9', 'CP5', 'CP1', 'Pz', 'P3', 'P7', 'O1', 'Oz', 'O2', ...
        'P4', 'P8', 'TP10', 'CP6', 'CP2', 'Cz', 'C4', 'T8', 'FT10', 'FC6', ...
        'FC2', 'F4', 'F8', 'Fp2', 'AF7', 'AF3', 'AFz', 'F1', 'F5', 'FT7', ...
        'FC3', 'C1', 'C5', 'TP7', 'CP3', 'P1', 'P5', 'PO7', 'PO3', 'POz', ...
        'PO4', 'PO8', 'P6', 'P2', 'CPz', 'CP4', 'TP8', 'C6', 'C2', 'FC4', ...
        'FT8', 'F6', 'AF8', 'AF4', 'F2', 'VEOG'};
    config.eeg.ref_channel        = 'FCz'; % optional, relevant only if you want to re-use the ref channel after re-referencing        

    config.motion.streams{1}.xdfname                    = 'Rigid_HandR';
    config.motion.streams{1}.bidsname                   = tracking_systems{1};
    config.motion.streams{1}.tracked_points             = 'Rigid_HandR';
    config.motion.streams{1}.tracked_points_anat        = 'right hand';
    config.motion.streams{1}.positions.channel_names    = {'Rigid_Tracker_X';  'Rigid_Tracker_Y' ; 'Rigid_Tracker_Z' }; 
    config.motion.streams{1}.quaternions.channel_names  = {'Rigid_Tracker_quat_X';'Rigid_Tracker_quat_Y';...
                                                            'Rigid_Tracker_quat_Z';'Rigid_Tracker_quat_W'};
    
    %%
    
    bemobil_xdf2bids(config, ...
        'general_metadata', generalInfo,...
        'participant_metadata', subjectInfo,...
        'motion_metadata', motionInfo, ...
        'eeg_metadata', eegInfo);
       
    
    % configuration for bemobil bids2set
    %----------------------------------------------------------------------
    config.study_folder             = studyFolder;
    config.session_names            = sessionNames;
    config.raw_EEGLAB_data_folder   = '2_raw-EEGLAB';
    config.other_data_types         = {'motion'};
    
    bemobil_bids2set(config);
    
end
