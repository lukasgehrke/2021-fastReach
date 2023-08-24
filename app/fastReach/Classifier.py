from pylsl import StreamInfo, StreamOutlet, StreamInlet, resolve_stream
import threading, pickle, numpy as np, time
from bci_funcs import windowed_mean, base_correct, slope
from bsl import StreamReceiver
import mne

class Classifier(threading.Thread):
    """Reads a data stream from LSL, computes features and predicts a class label and probability. For this, a model is loaded. 
    Smoothes the class label (median) and probability (mean) over 5 consecutive predictions.

    Args:
        out_stream_name (string): name of LSL data stream created to stream classifier output
        classifier_srate (integer): Frame rate at which classifier is applied and streams out classification output
        data_srate (integer): Frame rate of incoming LSL data stream
        model_path (string): Location of pickled (LDA) model
        target_class (integer): Value of target class in the trained model
        chans ([integer]): Channels (list) to be selected from LSL input data stream
        threshold (float): To evaluate whether prediction matches target_class with the probability exceeding this threshold
        window_size (integer): Buffer size
        baseline_index (integer): Index of baseline window in buffer
    """
    def __init__(self, out_stream_name, classifier_srate, data_srate, model_path, target_class, chans, threshold, window_size, baseline_index, debug) -> None:
        
        threading.Thread.__init__(self)

        # LSL outlet
        self.classifier_srate = classifier_srate
        
        self.srate = data_srate
        # stream_info = StreamInfo(out_stream_name, 'Classifier', 2, self.srate/self.classifier_srate, 'double64', 'myuid34234')
        stream_info = StreamInfo(out_stream_name, 'EEG', 3, 10, 'double64', 'myuid34234')
        self.outlet = StreamOutlet(stream_info)

        stream_info = StreamInfo('eeg_state', 'EEG', 1, 10, 'double64', 'myuid34234')
        self.eeg_state = StreamOutlet(stream_info)
        
        # LSL inlet via BSL wrapper
        self.sr = StreamReceiver(bufsize=1, winsize=1, stream_name='BrainVision RDA')
        time.sleep(1)

        # create MNE raw object for filter
        # self.sr. check this for channel size, maybe its in there
        # TODO change 65 back to 66 and 64 to 65
        self.mne_raw_info = mne.create_info(ch_names=[f"EEG{n:01}" for n in range(1, 65)],  ch_types=["eeg"] * 64, sfreq=self.srate) # hardcoded

        self.model_path = model_path
        self.clf = pickle.load(open(self.model_path, 'rb'))
        self.target_class = target_class
        self.chans = chans
        self.threshold = threshold
        self.window_size = window_size
        self.baseline_ix = baseline_index

        self.probs = 0
        self.smooth_proba = np.zeros(5)
        self.weights = [.1,.2,.3,.4,.5]

        self.prediction = 0        
        self.smooth_class = np.zeros(5)

        self.state = False
        self.print_states = debug

    def run(self):

        while True:

            self.sr.acquire()
            data, timestamps = self.sr.get_window(stream_name='BrainVision RDA')
            data = np.delete(data, 0, 1) # TODO needs to be accessed from simulated_raw

            simulated_raw = mne.io.RawArray(data.T, self.mne_raw_info)
            
            #tic = time.time()
            simulated_raw = simulated_raw.copy().filter(l_freq = .1, h_freq=15)
            
            data = data[:, self.chans]
            data_filt = simulated_raw._data.T[:, self.chans]

            # tmp = base_correct(data.T, self.baseline_ix)
            # feats = windowed_mean(tmp, self.window_size).flatten().reshape(1,-1)
            feats = slope(data.T, 'linear').flatten().reshape(1,-1)
            # slope_exp = slope(data.T, 'exp').flatten().reshape(1,-1)
            # feats = np.concatenate((slope_linear, slope_exp), axis=1)
        
            self.prediction = int(self.clf.predict(feats)[0]) #predicted class
            probs = self.clf.predict_proba(feats) #probability for class prediction
            self.probs = probs[0][int(self.target_class)]

            # class and proba smoothing
            #self.smooth_class[-1] = self.prediction
            #self.smooth_proba[-1] = self.probs
            #c = np.median(self.smooth_class)
            #p = np.average(self.smooth_proba, weights=self.weights)
            #self.smooth_class = np.roll(self.smooth_class,-1)
            #self.smooth_proba = np.roll(self.smooth_proba,-1)

            c = self.prediction
            p = self.probs

            if c == self.target_class and p >= self.threshold:
                self.state = 1 #True
            else:
                self.state = 0 #False

            #toc = time.time() - tic
            #print(toc)

            score = self.clf.transform(feats)[0][0]
            self.outlet.push_sample([c, p, score])

            print(self.state)
            self.eeg_state.push_sample([self.state])
            # self.outlet.push_sample([c, p])

            if self.print_states:
                print('rp: '+str(self.state) + ', class: ' + str(c) + ', probs: ' + str(p) + ', lda score: ' + str(score))

            # time.sleep(self.classifier_srate/self.srate)
            time.sleep(.1)