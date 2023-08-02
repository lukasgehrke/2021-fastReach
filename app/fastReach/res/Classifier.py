from pylsl import StreamInfo, StreamOutlet, StreamInlet, resolve_stream
import threading, pickle, numpy as np, time
from bci_funcs import windowed_mean, base_correct, slope

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
        
        # LSL inlet
        streams = resolve_stream('name', 'BrainVision RDA')
        self.inlet = StreamInlet(streams[0])

        self.model_path = model_path
        self.clf = pickle.load(open(self.model_path, 'rb'))
        self.target_class = target_class
        self.probs = 0
        self.prediction = 0
        self.chans = chans
        self.threshold = threshold
        self.window_size = window_size
        self.baseline_ix = baseline_index

        self.all_data = np.zeros((len(self.chans), self.srate))
        self.feat_data = np.zeros((len(self.chans), self.window_size))
        
        self.smooth_class = np.zeros(5)
        self.smooth_proba = np.zeros(5)

        self.state = False
        self.print_states = debug
    
    def run(self):

        frame = 1
        while True:
            start = time.time()

            # get a new sample (you can also omit the timestamp part if you're not interested in it)
            sample = np.array(self.inlet.pull_sample()[0])
            self.all_data[:,-1] = sample[self.chans]

            if frame == self.classifier_srate: # every X ms

                tmp = base_correct(self.all_data, self.baseline_ix-1)
                # feats = windowed_mean(tmp, self.window_size).flatten().reshape(1,-1)
                feats = slope(tmp, 'linear').flatten().reshape(1,-1)
        
                self.prediction = int(self.clf.predict(feats)[0]) #predicted class
                probs = self.clf.predict_proba(feats) #probability for class prediction

                self.probs = probs[0][self.target_class]

                self.smooth_class[-1] = self.prediction
                self.smooth_proba[-1] = self.probs

                c = np.median(self.smooth_class)
                p = self.smooth_proba.mean()
                score = self.clf.transform(feats)[0][0]

                self.outlet.push_sample([c, p, score])

                if c == self.target_class and p >= self.threshold:
                    self.state = True
                else:
                    self.state = False

                self.smooth_class = np.roll(self.smooth_class,-1)
                self.smooth_proba = np.roll(self.smooth_proba,-1)

                if self.print_states:
                    print('rp: '+str(self.state) + ', class: ' + str(c) + ', probs: ' + str(p) + ', lda score: ' + str(score))

                frame = 0

            frame += 1
            self.all_data = np.roll(self.all_data,-1) # Speed could be increased here, something like all_data[:,0:-2] = all_data[:,1:-1]

            time.sleep(max(1./self.srate - (time.time() - start), 0)) # maintain sampling rate