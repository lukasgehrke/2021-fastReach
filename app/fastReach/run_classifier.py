import os, json
from Classifier import Classifier

pID = 'sub-011'

data_path = '/Volumes/Lukas_Gehrke/fastReach/data/eeglab2python/'
# data_path = '\\\\stor1\projects\\Lukas_Gehrke\\fastReach\\data\\eeglab2python\\'
debug = False

model_path_eeg = data_path+pID+os.sep+'model_'+pID+'_eeg.sav'
with open(data_path+pID+os.sep+'bci_params.json', 'r') as f:
    bci_params = json.load(f)

eeg = Classifier('Lukas Test EEG', 'eeg_classifier', bci_params['classifier_update_rate'], bci_params['data_srate'], model_path_eeg, 
                            bci_params['target_class'], bci_params['chans'], bci_params['threshold'], bci_params['windows'], bci_params['baseline'],
                            debug)
eeg.start()