from os import name
import time

from pylsl import StreamInfo, StreamOutlet, local_clock

class LSL():

    def __init__(self, name) -> None:
        self.srate = 0
        self.name = name
        self.type = 'Markers'
        self.n_channels = 1

        # first create a new stream info (here we set the name to BioSemi,
        # the content-type to EEG, 8 channels, 100 Hz, and float-valued data) The
        # last value would be the serial number of the device or some other more or
        # less locally unique identifier for the stream as far as available (you
        # could also omit it but interrupted connections wouldn't auto-recover)
        self.info = StreamInfo(self.name, self.type, self.n_channels, self.srate, 'string', 'myuid34234')

        # next make an outlet
        self.outlet = StreamOutlet(self.info)

    def send(self, marker, verbose):

        if isinstance(marker, list):
            marker = list_to_string(marker)

        self.outlet.push_sample([marker])
        if verbose:
            print(marker)

def list_to_string(list):
    return ','.join(str(elem) for elem in list)