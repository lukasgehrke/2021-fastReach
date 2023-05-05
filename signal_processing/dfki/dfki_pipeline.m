%% config
current_sys = "mac";
eeglab_ver(current_sys);

%% load configuration
dfki_bemobil_config;

subjects = 2;

%% preprocess TODO adapt below

% set to 1 if all files should be recomputed and overwritten
force_recompute = 1;

for subject = subjects
    dfki_import(bemobil_config, subject);
    dfki_preprocess_EEG;
    dfki_preprocess_Physio;
end

%% extract features

results = [];

for subject = subjects

    design = [];

    %% load
    output_filepath = [bemobil_config.study_folder filesep bemobil_config.single_subject_analysis_folder filesep bemobil_config.filename_prefix num2str(subject)];
    EEG = pop_loadset('filename', [ bemobil_config.filename_prefix num2str(subject)...
	    '_' bemobil_config.single_subject_cleaned_ICA_filename], 'filepath', output_filepath);
    EEG.event = dfki_parse_events(EEG.event);

    

end