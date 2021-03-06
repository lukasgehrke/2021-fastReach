
import re
import pygame as pg
from pygame.locals import *
from pylsl import StreamInfo, StreamOutlet, StreamInlet, resolve_stream
import numpy as np
import serial, time, pickle, json, sys
from LSL import LSL
import threading
import ptext

EMS_RESET_TIME = time.time()

class fastReach:

    def __init__(self, pID, ems_on, arduino_port) -> None:
        self.lsl = LSL('fastReach')
        
        self.pID = pID
        path = '/Users/lukasgehrke/Documents/publications/2021-fastReach/app/fastReach/'
        self.config = json.load(open(path+'config.json', 'r'))
        self.markers = json.load(open(path+'markers.json', 'r'))
        self.instruction = json.load(open(path+'instructions.json', 'r'))
        
        self.init_screen(fullscreen=False)
        self.init_txt()

        if ems_on == True:
            
            self.ems = serial.Serial(port=arduino_port, baudrate=9600, timeout=.1)
            self.ems_resetter = EMSResetter(self.ems, self.lsl, self.markers)
            self.ems_resetter.start()

            data_path = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)

            model_path_eeg = data_path+'/model_'+str(self.pID)+'_eeg.sav'
            target_class = 1
            chans = pickle.load(open(data_path+'/chans_'+str(self.pID)+'_eeg.sav', 'rb'))
            threshold = .7
            buffer_feat_comp_size_samples = 250
            windowed_mean_size_samples = 25
            do_reg = False
            self.eeg = Classifier('eeg_classifier', buffer_feat_comp_size_samples/windowed_mean_size_samples,
                model_path_eeg, "eeg", target_class, chans, threshold, windowed_mean_size_samples, buffer_feat_comp_size_samples, do_reg)

            model_path_motion = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_motion.sav'
            target_class = 1
            chans = np.array([5,6,7])
            threshold = 1.0
            buffer_feat_comp_size_samples = 2
            windowed_mean_size_samples = 2
            do_reg = False
            self.motion = Classifier('motion_classifier', 45, model_path_motion, "motion", target_class,
                chans, threshold, windowed_mean_size_samples, buffer_feat_comp_size_samples, do_reg)

            self.motion.start()
            self.eeg.start()

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
 
    def start(self, trial_type, num_trials, ems_on):
        
        while True:
            for event in pg.event.get():
                if event.type == pg.KEYDOWN:
                    if event.key == pg.K_SPACE:
                        self.lsl.send(self.markers['start'],1)
                        start = time.time()

                        self.app(trial_type, num_trials, ems_on, start)

    def app(self, trial_type, num_trials, ems_on, start):

        trial_counter = 0
        name = []
        trial_marker_sent = False
        global EMS_RESET_TIME
        
        if trial_type == 'training':
            trial_dur = 4
            base_marker_sent = False

        elif trial_type == 'experiment':
            trial_dur = 4
        
        if ems_on == True:
            ems_sent = False
            ems_counter = trial_counter
            ems_time = start

        print_states = False
        while True:

            if print_states:
                # print('moving: '+str(self.motion.state))
                # print('rp: '+str(self.eeg.state))
                print([self.eeg.state, ems_sent, self.motion.state, self.ems_resetter.state])
            
            # trial logic
            elapsed = time.time() - start
            if trial_counter < num_trials:
            
                if trial_type == 'training' and base_marker_sent == False:
                    self.instruct(self.instruction["isi"])
                    if elapsed > 2:
                        self.lsl.send(self.markers['idle'],1)
                        base_marker_sent = True

                if elapsed > trial_dur:
                    self.instruct(self.instruction["start"]+'\n\n'+''.join(name))                    

                    if trial_marker_sent == True:
                        if trial_type == 'training' and time.time() - trial_end_time > 2: # next trial
                            start = time.time()
                            trial_marker_sent = False
                            base_marker_sent = False
                        elif trial_type == 'experiment':
                            start = time.time()
                            trial_marker_sent = False
                            ems_counter = trial_counter

            if trial_counter == num_trials:
                if time.time() - trial_end_time > 2:
                    self.lsl.send(self.markers['end'],1)
                    self.instruct(self.instruction["wait"])
                    ems_on = False
                    trial_counter += 1

            # ems behavior
            if ems_on == True:

                ems_duration = time.time() - ems_time
                if ems_duration > .5 and ems_sent == True:
                    ems_sent = False
                    self.ems.write("p".encode('utf-8'))
                    self.lsl.send(self.markers["ems off"],1)

                if elapsed > trial_dur and ems_counter == trial_counter and trial_marker_sent == False:

                    print("ems live")

                    if self.eeg.state == True and ems_sent == False and self.motion.state == False and self.ems_resetter.state == False:
                        self.ems.write("p".encode('utf-8'))
                        self.lsl.send(self.markers["ems on"],1)
                        ems_sent = True
                        ems_counter += 1
                        ems_time = time.time()
                        EMS_RESET_TIME = ems_time

            # keyboard input
            for event in pg.event.get():
                if event.type == pg.KEYDOWN:

                    if event.key == pg.K_ESCAPE:
                        pg.display.quit()

                    if elapsed > trial_dur and trial_marker_sent == False and trial_counter < num_trials:
                        name.append(event.unicode)
                        trial_counter += 1
                        self.lsl.send(self.markers["reach end"],1)
                        trial_marker_sent = True
                        trial_end_time = time.time()
                        print(elapsed)
                        

    def demo(self, mode):

        ems_time = time.time()
        ems_sent = False
        global EMS_RESET_TIME

        while True:

            ems_duration = time.time() - ems_time
            if ems_duration > .5 and ems_sent == True:
                ems_sent = False
                self.ems.write("p".encode('utf-8'))
                self.lsl.send(self.markers["ems off"],1)
        
            if mode == 'eeg':
                if self.eeg.state == True and ems_sent == False and self.motion.state == False and self.ems_resetter.state == False:
                    self.ems.write("p".encode('utf-8'))
                    self.lsl.send(self.markers["ems on"],1)
                    ems_sent = True
                    ems_time = time.time()
                    EMS_RESET_TIME = ems_time

            elif mode == 'button':

                for event in pg.event.get():
                    if event.type == pg.KEYDOWN:

                        if event.key == pg.K_ESCAPE:
                            pg.display.quit()
                            sys.exit()
                        else:
                            self.ems.write("p".encode('utf-8'))
                            self.lsl.send(self.markers["ems on"],1)
                            ems_sent = True
                            ems_time = time.time()
                            EMS_RESET_TIME = ems_time

class Classifier(threading.Thread):
    
    def __init__(self, stream_name, srate, model_path, type, target_class, chans, threshold, frame_rate, window_size, regression) -> None:
        self.model_path = model_path

        threading.Thread.__init__(self)

        stream_info = StreamInfo(stream_name, 'EMG', 3, srate, 'double64', 'myuid34234')
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
        self.do_reg = regression

        # create empty numpy array (2D: m1 and m2)
        self.all_data = np.zeros((len(self.chans), self.window_size))
        self.reg_feats = np.zeros((len(self.chans), int(self.window_size/self.frame_rate)))

        self.state = False
    
    def run(self):

        # tmp = []

        # frame = 0
        while True:

            # get a new sample (you can also omit the timestamp part if you're not interested in it)
            sample = np.array(self.inlet.pull_sample()[0])

            # TODO check if this is empty? Use of while True is bad here

            self.all_data[:,-1] = sample[self.chans-1].flatten()
            
            # if frame == self.frame_rate-1:
            #     frame = 0

            if self.type == "motion":

                feats = np.sqrt(
                    np.square(np.diff(self.all_data[0,:])) + 
                    np.square(np.diff(self.all_data[1,:])) + 
                    np.square(np.diff(self.all_data[2,:]))).reshape(1,-1)

            if self.type == "eeg":

                # feat_data = self.all_data - np.expand_dims(self.all_data[:,0],1)
                # feat_data = np.reshape(feat_data, (len(self.chans), int(self.window_size/self.frame_rate), self.frame_rate))
                # feat_data = np.reshape(self.all_data, (len(self.chans), int(self.window_size/self.frame_rate), self.frame_rate))
                feat_data = np.reshape(self.all_data, (len(self.chans), 25, 10))

                # TODO recheck if this is correct

                if self.do_reg == True:
                    try:
                        # t = time.time()
                        for i in range(len(self.chans)):
                            for j in range(10):
                                self.reg_feats[i,j] = np.polyfit(feat_data[i,j,:], feat_data[-1,j,:],1)[1]
                                feats = self.reg_feats.flatten().reshape(1,-1)
                        # elapsed = time.time() - t
                        # tmp.append(elapsed)
                    except:
                        print("waiting for buffer")
                else:
                    feats = np.mean(feat_data, axis = 1).flatten().reshape(1,-1)
    
            prediction = self.clf.predict(feats)[0] #predicted class
            probs = self.clf.predict_proba(feats) #probability for class prediction
            self.outlet.push_sample([prediction,probs[0][0],probs[0][1]])

            if prediction == self.target_class and probs[0][0] >= self.threshold:

                # if self.type == 'eeg':
                #     print(str(prediction) + ' ' + str(probs))
                # print(str(prediction) + ' ' + str(probs[0][0]))
                self.state = True
            else:
                self.state = False

            # if self.type == 'eeg':
                # print(str(prediction) + ' ' + str(probs))
                # print(str(probs[0][0]))
 
            # else:
            #     frame +=1

            self.all_data = np.roll(self.all_data,-1) # Speed could be increased here, something like all_data[:,0:-2] = all_data[:,1:-1]

class EMSResetter(threading.Thread):

    def __init__(self, ems, lsl, markers):
        threading.Thread.__init__(self)
        self.ems = ems
        self.lsl = lsl
        self.markers = markers
        self.state = False

    def run(self):

        global EMS_RESET_TIME

        while True:

            # print(time.time() - EMS_RESET_TIME) 
            if (time.time() - EMS_RESET_TIME) > 9.8 and self.state == False:
                self.state = True
                self.ems.write("p".encode('utf-8'))
                self.lsl.send(self.markers["ems reset"],1)
            if (time.time() - EMS_RESET_TIME) > 9.95 and self.state == True:
                self.ems.write("p".encode('utf-8'))
                EMS_RESET_TIME = time.time()
                self.state = False

### SET pID ###
pID = 13
trial_type = 'experiment' # training
num_trials = 75
with_ems = True
arduino_port = '/dev/tty.usbmodem11301' # ls /dev/tty.*
###

pg.init()
np.set_printoptions(precision=2)
exp = fastReach(pID, with_ems, arduino_port)

exp.start(trial_type, num_trials, with_ems)
# exp.demo(mode='button')
# exp.demo(mode='eeg')