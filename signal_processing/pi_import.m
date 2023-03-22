function pi_import(cfg, subject, training)

    sessionNames                        = {'Baseline', 'EMS1', 'EMS2'};
    
    % general metadata shared across all modalities
    %--------------------------------------------------------------------------
    %--------------------------------------------------------------------------
    generalInfo = [];
    
    % required for dataset_description.json
    generalInfo.dataset_description.Name                = 'Preconscious Interaction';
    generalInfo.dataset_description.BIDSVersion         = 'unofficial extension';
    
    % optional for dataset_description.json
    generalInfo.dataset_description.License             = 'CC BY';
    generalInfo.dataset_description.Authors             = {'Lukas Gehrke', 'Leonie Terfurth'};
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
    
    config.task                   = 'PI';                           % optional
    config.subject                = subject;                            % required
    config.overwrite              = 'on';
    config.eeg.stream_name        = 'BrainVision RDA';                      % required
    config.eeg.chanloc_newname    = {'Fp1', 'Fz', 'F3', 'F7', 'FT9', 'FC5', 'FC1', ...
        'C3', 'T7', 'TP9', 'CP5', 'CP1', 'Pz', 'P3', 'P7', 'O1', 'Oz', 'O2', ...
        'P4', 'P8', 'TP10', 'CP6', 'CP2', 'Cz', 'C4', 'T8', 'FT10', 'FC6', ...
        'FC2', 'F4', 'F8', 'Fp2', 'AF7', 'AF3', 'AFz', 'F1', 'F5', 'FT7', ...
        'FC3', 'C1', 'C5', 'TP7', 'CP3', 'P1', 'P5', 'PO7', 'PO3', 'POz', ...
        'PO4', 'PO8', 'P6', 'P2', 'CPz', 'CP4', 'TP8', 'C6', 'C2', 'FC4', ...
        'FT8', 'F6', 'AF8', 'AF4', 'F2', 'VEOG' , 'EMG'};
    config.eeg.ref_channel        = 'FCz'; % optional, relevant only if you want to re-use the ref channel after re-referencing
    config.other_data_types        = {'physio'};
    
    %%
    
    for session = sessionNames
        config.session                = session{1};              % required if there are more than 1 session
        config.filename               = [cfg.study_folder filesep '0_source-data' filesep sub_path filesep [session{1}, '.xdf']];

        if ~strcmp(config.session, 'Baseline')
            config.phys.streams{1}.stream_name          = 'eeg_classifier';            % optional
        end

        bemobil_xdf2bids(config, ...
            'general_metadata', generalInfo,...
            'participant_metadata', subjectInfo,...
            'eeg_metadata', eegInfo);
    end
        
    % configuration for bemobil bids2set
    %----------------------------------------------------------------------
    config.study_folder             = cfg.study_folder;
    config.session_names            = sessionNames;
    config.set_folder               = cfg.study_folder; %fullfile(config.study_folder, '2_raw-EEGLAB');
    bemobil_bids2set(config);
    
end
