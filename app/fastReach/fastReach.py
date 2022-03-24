
import re
import pygame as pg
from pygame.locals import *
from pylsl import StreamInlet, resolve_stream
import numpy as np
import serial, time, random, string, pickle, json
from LSL import LSL
from threading import *

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
        txt = self.font.render(text, True, col)
        self.screen.blit(txt, txt.get_rect(center=self.screen_rect.center))
        # self.wait()
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
            
            self.ems = serial.Serial(port='/dev/cu.usbmodem11201', baudrate=9600, timeout=.1)
            model_path_eeg = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_eeg.sav'
            chans = np.arange(20)
            self.eeg = Classifier(model_path_eeg, "eeg", chans, .8, 25, 250)
            self.eeg.state()

            chans = np.array([4,5,6])
            model_path_motion = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_motion.sav'
            self.motion = Classifier(model_path_motion, "motion", chans, .6, 1, 10)
            self.motion.state()

        # trial logic
        trial_counter = 0
        trial = True
        marker_sent = False
        name = []

        # arduino
        ems_sent = False
        ems_counter = trial_counter
        ems_time = start

        # classifiers
        print_states = True

        while trial_counter<num_trials:

            if print_states:
                print(self.motion.state())
                # print(self.eeg.state())

            elapsed = time.time() - start
            ems_duration = time.time() - ems_time

            if ems_duration > .5 and ems_sent == True:
                ems_sent = False
                self.ems.write("p".encode('utf-8'))
                self.lsl.send(self.markers["ems off"],1)

            if elapsed > 2 and elapsed < 6 and trial == True:
                self.instruct(self.instruction["start"])

            if elapsed > 4 and marker_sent == False:
                self.lsl.send(self.markers['idle'],1)
                marker_sent = True

            if elapsed > 6 and trial == True:
                # letter = random.choice(string.ascii_uppercase)
                # self.instruct(self.instruction["training task"]+letter)

                self.instruct(''.join(name))
                trial = False

            if ems_on == True and elapsed > 6 and ems_counter == trial_counter:
                
                if self.eeg.state() == True and ems_sent == False and self.motion.state() == False:

                    self.ems.write("p".encode('utf-8'))
                    self.lsl.send(self.markers["ems on"],1)
                    ems_sent = True
                    ems_counter += 1
                    ems_time = time.time()

            for event in pg.event.get():
                if event.type == pg.KEYDOWN:

                    if event.key == pg.K_ESCAPE:
                        pg.display.quit()

                    if elapsed > 6:
                        
                        start = time.time()
                        name.append(event.unicode)
                        trial_counter += 1
                        self.lsl.send(self.markers["reach end"],1)
                        marker_sent = False
                        trial = True
                        self.instruct(''.join(name))

            if trial_counter == num_trials:
                self.lsl.send(self.markers['end'],1)
                self.instruct(self.instruction["wait"])

class Classifier(Thread):
    
    def __init__(self, model_path, type, chans, threshold, frame_rate, window_size) -> None:
        self.model_path = model_path

        # pickle load the model and good chans ix
        self.clf = pickle.load(open(self.model_path, 'rb'))

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
                
                # filter the data? fast enough?

                if self.type == "motion":
                    
                    # length of vector
                    # feats = np.sqrt(np.square(self.all_data[0,:]) + np.square(self.all_data[1,:]) + np.square(self.all_data[2,:]))
                    # feats = np.mean(feats - feats[0])
                    
                    # mag of vel
                    feats = np.sqrt(
                        np.square(np.diff(self.all_data[0,:])) + 
                        np.square(np.diff(self.all_data[1,:])) + 
                        np.square(np.diff(self.all_data[2,:])))

                    feats = feats.reshape(-1,1) # when only 1 feature

                if self.type == "eeg":
                    feats = np.mean(np.reshape(self.all_data, (int(self.window_size/self.frame_rate), len(self.chans), self.frame_rate)), axis = 2)
        
                # prediction for emg-window
                prediction = self.clf.predict(feats)[0] #predicted class
                probs = self.clf.predict_proba(feats) #probability for class prediction

                if self.type == "motion":
                    if prediction == 1 and probs[0][0] > self.threshold:
                        # print(str(prediction) + ' ' + str(probs[0][0]))
                        # print("hand is moving")
                        return True
                    else:
                        return False

                if self.type == "eeg":
                    if prediction == 1 and probs[0][0] > self.threshold:
                        # print(str(prediction) + ' ' + str(probs[0][0]))
                        # print("rp detected")
                        return True
                    else:
                        return False

            else:
                frame +=1

# def __main__():
pg.init()
exp = fastReach(2)
exp.start(num_trials=20, ems_on=True)
# input("continue with app")
# exp.app(num_trials = 50, ems_on=True)