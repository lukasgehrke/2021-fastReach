% Main Processing Script to pipeline process PI data
% 
% Uses BeMoBIL Pipeline to parse XDF file and preprocess EEG, EMG and
% Classifier Output data

%% config
current_sys = "mac";
eeglab_ver(current_sys);

%% load configuration
pi_bemobil_config;

%% preprocess TODO adapt below

% set to 1 if all files should be recomputed and overwritten
force_recompute = 1;
subjects = 3;

for subject = subjects
    pi_import(bemobil_config, subject, 0);
%     pi_preprocess_EEG;
%     pi_preprocess_Physio;
end

% %% export features
% 
% for subject = subjects
%     
%     disp(subject);
% 
%     %% create out folder
%     
%     out_folder = fullfile(bemobil_config.study_folder, 'results', ['sub-' num2str(subject)], filesep);
%     if ~exist(out_folder, 'dir')
%         mkdir(out_folder)
%     end
% 
%     %% parse data
%     Physio = pop_loadset([bemobil_config.study_folder filesep ...
%         bemobil_config.physio_analysis_folder filesep ...
%         'sub-' num2str(subject) filesep 'sub-' num2str(subject) '_' ...
%         bemobil_config.processed_physio_filename]);
%     EEG = pop_loadset([bemobil_config.study_folder filesep ...
%         bemobil_config.single_subject_analysis_folder filesep ...
%         'sub-' num2str(subject) filesep 'sub-' num2str(subject) '_' ...
%         bemobil_config.preprocessed_and_ICA_filename]); % no rejection of eye components
% 
% end
% 
% disp("EXPORT DONE!!!")
