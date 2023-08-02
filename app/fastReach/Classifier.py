from pylsl import StreamInfo, StreamOutlet, StreamInlet, resolve_stream
import threading, pickle, numpy as np, time
from bci_funcs import windowed_mean, base_correct, slope
from bsl import StreamReceiver

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
        stream_info = StreamInfo(out_stream_name, 'Classifier', 3, self.srate/self.classifier_srate, 'double64', 'myuid34234')
        self.outlet = StreamOutlet(stream_info)
        
        # LSL inlet via BSL wrapper
        self.sr = StreamReceiver(bufsize=1, winsize=1, stream_name='BrainVision RDA')
        time.sleep(1)

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
            data = np.delete(data, 0, 1)
            data = data[:, self.chans]

            # tmp = base_correct(data.T, self.baseline_ix)
            # feats = windowed_mean(tmp, self.window_size).flatten().reshape(1,-1)
            slope_linear = slope(data.T, 'linear').flatten().reshape(1,-1)
            slope_exp = slope(data.T, 'exp').flatten().reshape(1,-1)
            feats = np.concatenate((slope_linear, slope_exp), axis=1)
        
            self.prediction = int(self.clf.predict(feats)[0]) #predicted class
            probs = self.clf.predict_proba(feats) #probability for class prediction
            self.probs = probs[0][int(self.target_class)]

            self.smooth_class[-1] = self.prediction
            self.smooth_proba[-1] = self.probs
            c = np.median(self.smooth_class)
            p = np.average(self.smooth_proba, weights=self.weights)
            self.smooth_class = np.roll(self.smooth_class,-1)
            self.smooth_proba = np.roll(self.smooth_proba,-1)

            if c == self.target_class and p >= self.threshold:
                self.state = True
            else:
                self.state = False

            score = self.clf.transform(feats)[0][0]
            self.outlet.push_sample([c, p, score])

            if self.print_states:
                print('rp: '+str(self.state) + ', class: ' + str(c) + ', probs: ' + str(p) + ', lda score: ' + str(score))

            time.sleep(self.classifier_srate/self.srate)