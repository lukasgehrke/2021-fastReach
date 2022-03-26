
import re
import pygame as pg
from pygame.locals import *
from pylsl import StreamInfo, StreamOutlet, StreamInlet, resolve_stream
import numpy as np
import serial, time, random, string, pickle, json
from LSL import LSL
from threading import *
import ptext

class fastReach:

    def __init__(self, pID) -> None:
        self.lsl = LSL('fastReach')
        
        self.pID = pID
        path = '/Users/lukasgehrke/Documents/publications/2021-fastReach/app/fastReach/'
        self.config = json.load(open(path+'config.json', 'r'))
        self.markers = json.load(open(path+'markers.json', 'r'))
        self.instruction = json.load(open(path+'instructions.json', 'r'))
        
        self.init_screen(fullscreen=False)
        self.init_txt()

    def init_screen(self, fullscreen):
        info = pg.display.Info()
        if fullscreen == True:
            self.screen = pg.display.set_mode((info.current_w, info.current_h), pg.FULLSCREEN) 
        else:
            self.screen = pg.display.set_mode((1200, 600), pg.RESIZABLE)
        self.screen.fill((240, 240, 240))
        self.screen_rect = self.screen.get_rect()

    def init_txt(self):
        self.font = pg.font.Font(None, 45)

    def instruct(self, text, col = (0,0,0)):

        self.screen.fill((240, 240, 240))
        ptext.draw(text, topleft=(200, 200), color=col, fontsize=40)  # Recognizes newline characters.
        pg.display.flip()

    def start(self, num_trials, ems_on):
        
        while True:
            for event in pg.event.get():
                if event.type == pg.KEYDOWN:
                    if event.key == pg.K_SPACE:
                        self.lsl.send(self.markers['start'],1)
                        start = time.time()
                        self.app(num_trials, ems_on, start)

    def app(self, num_trials, ems_on, start):

        if ems_on == True:
            
            self.ems = serial.Serial(port='/dev/tty.usbmodem11101', baudrate=9600, timeout=.1)
            data_path = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)

            model_path_eeg = data_path+'/model_'+str(self.pID)+'_eeg.sav'
            target_class = 1
            chans = pickle.load(open(data_path+'/chans_'+str(self.pID)+'_eeg.sav', 'rb'))
            threshold = .7
            buffer_feat_comp_size_samples = 500
            windowed_mean_size_samples = 50
            self.eeg = Classifier('eeg_classifier', model_path_eeg, "eeg", target_class, 
                chans, threshold, windowed_mean_size_samples, buffer_feat_comp_size_samples)
            self.eeg.state()

            model_path_motion = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_motion.sav'
            target_class = 1
            chans = np.array([4,5,6])
            threshold = .8
            buffer_feat_comp_size_samples = 10
            windowed_mean_size_samples = 2
            self.motion = Classifier('motion_classifier', model_path_motion, "motion", target_class,
                chans, threshold, windowed_mean_size_samples, buffer_feat_comp_size_samples)
            self.motion.state()

        # trial logic
        trial_counter = 0
        baseline = True
        base_marker_sent = False
        trial = False
        trial_marker_sent = False
        name = []
        trial_dur = 4

        # arduino
        ems_sent = False
        ems_counter = trial_counter
        ems_time = start

        # classifiers
        print_states = False

        while True: # trial_counter<num_trials:

            if print_states:
                print(self.motion.state())
                # print(self.eeg.state())

            elapsed = time.time() - start
            
            if ems_on == True:
                
                ems_duration = time.time() - ems_time
                if ems_duration > .5 and ems_sent == True:
                    ems_sent = False
                    self.ems.write("p".encode('utf-8'))
                    self.lsl.send(self.markers["ems off"],1)

                if elapsed > 6 and ems_counter == trial_counter:    
                    if self.eeg.state() == True and ems_sent == False and self.motion.state() == False:
                        self.ems.write("p".encode('utf-8'))
                        self.lsl.send(self.markers["ems on"],1)
                        ems_sent = True
                        ems_counter += 1
                        ems_time = time.time()

            if baseline == True:
                self.instruct(self.instruction["isi"])

                if elapsed > 2 and base_marker_sent == False:
                    self.lsl.send(self.markers['idle'],1)
                    base_marker_sent = True

                if elapsed > trial_dur:
                    baseline = False
                    trial = True

            if trial == True:
                self.instruct(self.instruction["start"]+'\n\n'+''.join(name))                    

                if trial_marker_sent == True:
                    if time.time() - trial_end_time > 2: # next trial
                        start = time.time()
                        trial = False
                        trial_marker_sent = False
                        base_marker_sent = False
                        baseline = True

            if trial_counter == num_trials:
                if time.time() - trial_end_time > 2:
                    self.lsl.send(self.markers['end'],1)
                    self.instruct(self.instruction["wait"])

                    baseline = False
                    trial = False
                    ems_on = False
                    trial_counter += 1

            for event in pg.event.get():
                if event.type == pg.KEYDOWN:

                    if event.key == pg.K_ESCAPE:
                        pg.display.quit()

                    if elapsed > trial_dur:
                        name.append(event.unicode)
                        trial_counter += 1
                        self.lsl.send(self.markers["reach end"],1)
                        trial_marker_sent = True
                        trial_end_time = time.time()
                        print(elapsed)

class Classifier(Thread):
    
    def __init__(self, stream_name, model_path, type, target_class, chans, threshold, frame_rate, window_size) -> None:
        self.model_path = model_path

        stream_info = StreamInfo(stream_name, 'Classifier', 2, 0, 'string', 'myuid34234')
        self.outlet = StreamOutlet(stream_info)

        # pickle load the model and good chans ix
        self.clf = pickle.load(open(self.model_path, 'rb'))
        self.target_class = target_class

        self.type = type
        self.chans = chans

        if self.type == 'motion':
            streams = resolve_stream('type', 'rigidBody')
            
        elif self.type == 'eeg':
            streams = resolve_stream('type', 'EEG')

        # create a new inlet to read from the stream
        self.inlet = StreamInlet(streams[0])

        self.threshold = threshold
        self.frame_rate = frame_rate
        self.window_size = window_size

        # create empty numpy array (2D: m1 and m2)
        self.all_data = np.zeros((len(self.chans), self.window_size))

    
    def state(self):

        frame = 0
        while True:

            # get a new sample (you can also omit the timestamp part if you're not interested in it)
            sample = self.inlet.pull_sample()

            self.all_data[:,-1] = np.array(sample[0])[self.chans]
            self.all_data = np.roll(self.all_data,-1) # Speed could be increased here, something like all_data[:,0:-2] = all_data[:,1:-1]
            
            if frame >= self.frame_rate:
                frame = 0

                if self.type == "motion":
                    
                    # length of vector
                    # feats = np.sqrt(np.square(self.all_data[0,:]) + np.square(self.all_data[1,:]) + np.square(self.all_data[2,:]))
                    # feats = np.mean(feats - feats[0])
                    
                    # mag of vel
                    feats = np.sqrt(
                        np.square(np.diff(self.all_data[0,:])) + 
                        np.square(np.diff(self.all_data[1,:])) + 
                        np.square(np.diff(self.all_data[2,:]))).reshape(-1,1)

                if self.type == "eeg":
                    feats = np.mean(np.reshape(self.all_data, (int(self.window_size/self.frame_rate), len(self.chans), self.frame_rate)), axis = 2).flatten().reshape(-1,1)
        
                prediction = self.clf.predict(feats)[0] #predicted class
                probs = self.clf.predict_proba(feats) #probability for class prediction

                self.outlet.push_sample([prediction,probs[0][0]])

                if prediction == self.target_class and probs[0][0] > self.threshold:
                    # print(str(prediction) + ' ' + str(probs[0][0]))
                    return True
                else:
                    return False

            else:
                frame +=1

### SET PID ###
pID = 4
with_ems = False
num_trials = 56
###

pg.init()
exp = fastReach(pID)
exp.start(num_trials, with_ems)