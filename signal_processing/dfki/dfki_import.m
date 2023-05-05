function dfki_import(cfg, subject)

    sessionNames                        = {'1'};
    
    % general metadata shared across all modalities
    %--------------------------------------------------------------------------
    %--------------------------------------------------------------------------
    generalInfo = [];
    
    % required for dataset_description.json
    generalInfo.dataset_description.Name                = 'DFKI';
    generalInfo.dataset_description.BIDSVersion         = 'unofficial extension';
    
    % optional for dataset_description.json
    generalInfo.dataset_description.License             = 'CC BY';
    generalInfo.dataset_description.Authors             = {''};
    generalInfo.dataset_description.Acknowledgements    = 'n/a';
    generalInfo.dataset_description.Funding             = {''};
    generalInfo.dataset_description.ReferencesAndLinks  = {};
    generalInfo.dataset_description.DatasetDOI          = 'n/a';
    
    % general information shared across modality specific json files 
    generalInfo.InstitutionName                         = 'Technische Universitaet Berlin';
    generalInfo.InstitutionalDepartmentName             = 'Biological Psychology and Neuroergonomics';
    generalInfo.InstitutionAddress                      = 'Strasse des 17. Juni 135, 10623, Berlin, Germany';
    generalInfo.TaskDescription                         = 'Participants equipped with VR HMD performed an grasp and place task.';
     
    
    % information about the eeg recording system 
    %--------------------------------------------------------------------------
    %--------------------------------------------------------------------------
    eegInfo     = [];
    % eegInfo.coordsystem.EEGCoordinateSystem             = 'Other'; 
    % eegInfo.coordsystem.EEGCoordinateUnits              = 'mm'; 
    
    
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
    
    config                        = [];                                 % reset for each loop 
    config.bids_target_folder     = fullfile(cfg.study_folder, '1_BIDS-data'); % required
    
    sub_path                      =  ['sub-', sprintf( '%03d', subject)];
    
    config.task                   = 'DFKI';                           % optional
    config.subject                = subject;                            % required
    config.overwrite              = 'on';
    config.eeg.stream_name        = 'LiveAmpSN-100005-0671';                      % required
    config.eeg.ref_channel        = 'FCz'; % optional, relevant only if you want to re-use the ref channel after re-referencing
    config.other_data_types        = {'motion', 'physio'};
    
    % information about the motion recording system 
    %--------------------------------------------------------------------------
%     %--------------------------------------------------------------------------
%     motionInfo  = []; 
%     
%     % motion specific fields in json
%     motionInfo.motion = [];
%     motionInfo.motion.RecordingType                     = 'continuous';
    %%
    
    for session = sessionNames
        config.session                = session{1};              % required if there are more than 1 session
        config.filename               = [cfg.study_folder filesep '0_source-data' filesep sub_path filesep 'task' filesep '1' filesep 'S001' filesep 'EEG' filesep [session{1}, '.xdf']];
        
        config.phys.streams{1}.stream_name          = 'OpenSignals';            % optional

%         config.motion.streams{1}.xdfname                    = 'TrackedHand';
%         config.motion.streams{1}.bidsname                   = 'HTCTrackedHand';
%         config.motion.streams{1}.tracked_points             = 'TrackedHand';
%         config.motion.streams{2}.xdfname                    = 'RedirectedHand';
%         config.motion.streams{2}.bidsname                   = 'HTCRedirectedHand';
%         config.motion.streams{2}.tracked_points             = 'RedirectedHand';

        bemobil_xdf2bids(config, ...
            'general_metadata', generalInfo,...
            'participant_metadata', subjectInfo,...
            'eeg_metadata', eegInfo);
%             'motion_metadata', motionInfo);
    end
        
    % configuration for bemobil bids2set
    %----------------------------------------------------------------------
    config.study_folder             = cfg.study_folder;
    config.session_names            = sessionNames;
    config.set_folder               = fullfile(config.study_folder, '2_raw-EEGLAB');
    bemobil_bids2set(config);
    
end
