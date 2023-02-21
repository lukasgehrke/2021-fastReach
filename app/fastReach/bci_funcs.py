import numpy as np

def windowed_mean(data, windows = 10):
    stepsize = data.shape[1] // windows
    win_data = np.reshape(data, (data.shape[0], windows, stepsize))
    return np.mean(win_data, axis = 2)

def base_correct(data):
    data_base_correct = data - data[:,0][:,None]
    return data_base_correct

def drop_baseline(data, baseline_end_ix):
    data = data[:,baseline_end_ix:]
    return data

def reshape_trial(data):
    data_reshaped_trial = np.reshape(data, (data.shape[2], data.shape[0] * data.shape[1]), order = 'F')
    # data_reshaped_trial = np.reshape(data, (data.shape[0] * data.shape[1]), order = 'F')
    return data_reshaped_trial