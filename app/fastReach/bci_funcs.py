import numpy as np
from scipy import stats

def windowed_mean(data, n_windows = 10):
    """Computes windowed mean of data

    Args:
        data (_type_): 2D array, usually chans x time
        windows (int, optional): Number of windows data is split into . Defaults to 10.

    Returns:
        _type_: Windowed mean of data, of shape chans x n_windows
    """
    stepsize = data.shape[1] // n_windows
    win_data = np.reshape(data, (data.shape[0], n_windows, stepsize))
    return np.mean(win_data, axis = 2)

def select_mean(data, n_windows, window):
    """_summary_

    Args:
        data (_type_): _description_
        n_windows (_type_): _description_
        window (_type_): _description_

    Returns:
        _type_: _description_
    """

    win_means = windowed_mean(data, n_windows)
    return win_means[:,window-1]

def slope(data, function):

    slopes = np.array([])

    for i in range(data.shape[0]):

        if function == 'linear':
            slopes = np.append(slopes, stats.linregress(data[i,:], np.arange(0, data.shape[1]))[0])

        elif function == 'exp':
            log_clean_data = np.ma.masked_invalid(np.log(data[i,:] - np.min(data[i,:]))).compressed() # log of data, excluding -inf
            slopes = np.append(slopes, stats.linregress(log_clean_data, np.arange(0, log_clean_data.shape[0]))[0])

    return slopes

    


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