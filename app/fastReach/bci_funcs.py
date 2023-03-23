import numpy as np

def windowed_mean(data, windows = 10):
    """Computes windowed mean of data

    Args:
        data (_type_): 2D array, usually chans x time
        windows (int, optional): Number of windows data is split into . Defaults to 10.

    Returns:
        _type_: Windowed mean of data, of shape chans x windows
    """
    stepsize = data.shape[1] // windows
    win_data = np.reshape(data, (data.shape[0], windows, stepsize))
    return np.mean(win_data, axis = 2)

def base_correct(data, baseline_end_ix):
    """Subtracts baseline from data

    Args:
        data (_type_): 2D array, usually chans x time

    Returns:
        _type_: Baseline corrected 2D array, usually chans x time
    """
    base = np.mean(data[:,:int(baseline_end_ix)], axis = 1)
    data_base_correct = data - base[:,None]
    return data_base_correct

def drop_baseline(data, baseline_end_ix):
    """Drops baseline from data"""
    data = data[:,baseline_end_ix:]
    return data

def reshape_trial(data):
    data_reshaped_trial = np.reshape(data, (data.shape[2], data.shape[0] * data.shape[1]), order = 'F')
    # data_reshaped_trial = np.reshape(data, (data.shape[0] * data.shape[1]), order = 'F')
    return data_reshaped_trial