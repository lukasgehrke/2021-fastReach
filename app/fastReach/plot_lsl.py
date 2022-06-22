# Author: Teon Brooks <teon.brooks@gmail.com>
#
# License: BSD (3-clause)
import matplotlib.pyplot as plt

from mne.datasets import sample
from mne.io import read_raw_fif

from mne_realtime import LSLClient, MockLSLStream

print(__doc__)

# this is the host id that identifies your stream on LSL
host = 'BrainVision RDA'
# this is the max wait time in seconds until client connection
wait_max = 5


# Load a file to stream raw data
data_path = sample.data_path()
raw_fname = data_path + '/MEG/sample/sample_audvis_filt-0-40_raw.fif'
raw = read_raw_fif(raw_fname).crop(0, 30).load_data().pick('eeg')

# For this example, let's use the mock LSL stream.
_, ax = plt.subplots(1)
n_epochs = 5

# main function is necessary here to enable script as own program
# in such way a child process can be started (primarily for Windows)
if __name__ == '__main__':
    with MockLSLStream(host, raw, 'eeg'):
        with LSLClient(info=raw.info, host=host, wait_max=wait_max) as client:
            client_info = client.get_measurement_info()
            sfreq = int(client_info['sfreq'])

            # let's observe ten seconds of data
            for ii in range(n_epochs):
                print('Got epoch %d/%d' % (ii + 1, n_epochs))
                plt.cla()
                epoch = client.get_data_as_epoch(n_samples=sfreq)
                epoch.average().plot(axes=ax)
                plt.pause(1.)
            plt.draw()
print('Streams closed')