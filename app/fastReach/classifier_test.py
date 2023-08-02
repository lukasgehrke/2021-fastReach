model_path_eeg = data_path+'model_'+str(self.pID)+'_eeg.sav'
with open(data_path+os.sep+'bci_params.json', 'r') as f:
    bci_params = json.load(f)

self.eeg = Classifier('eeg_classifier', bci_params['classifier_update_rate'], bci_params['data_srate'], model_path_eeg, 
                            bci_params['target_class'], bci_params['chans'], bci_params['threshold'], bci_params['windows'], bci_params['baseline'],
                            debug)
self.eeg.start()