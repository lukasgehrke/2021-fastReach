
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

    def app(self, ems_on):

        if ems_on == True:
            
            # self.ems = serial.Serial(port='/dev/cu.usbmodem11201', baudrate=9600, timeout=.1)
            model_path_eeg = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_eeg.sav'

            chans = np.arange(20)
            self.eeg = Classifier(model_path_eeg, "eeg", chans, .8, 25, 250)
            self.eeg.state()

            # model_path_motion = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_motion.sav'
            # self.motion = Classifier(model_path_eeg, "motion", 5, .9, 1, 50)
            # self.motion.state()

        trial_counter = 0
        start = time.time()
        running = False
        trial = False
        marker_sent = False
        name = []
        ems_sent = False

        while trial_counter<self.config['num_trainings_trials']:

            elapsed = time.time() - start

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

            if ems_on == True and elapsed > 6:
                if self.eeg.state() == True and ems_sent == False: # and self.motion.state() == False 
                    self.ems.write("p".encode('utf-8'))
                    self.lsl.send(self.markers["ems"],1)
                    ems_sent = True

            for event in pg.event.get():
                if event.type == pg.KEYDOWN:

                    if event.key == pg.K_SPACE and running == False:

                        self.lsl.send(self.markers['start'],1)
                        running = True
                        trial = True
                        start = time.time()

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

            if trial_counter == self.config['num_trainings_trials']:
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
                    feats = self.all_data.reshape(-1,1) # when only 1 feature

                if self.type == "eeg":
                    feats = np.mean(np.reshape(self.all_data, (int(self.window_size/self.frame_rate), len(self.chans), self.frame_rate)), axis = 2)
        
                # prediction for emg-window
                prediction = self.clf.predict(feats)[0] #predicted class
                probs = self.clf.predict_proba(feats) #probability for class prediction

                # print(probs[0][int(prediction-1)])
                # print(prediction)

                # TODO confirm that the correct prediction output is selected here!
                if probs[0][int(prediction-1)] > self.threshold: #-1 da class 1,2 und index 0,1
                    if int(prediction) == 1:
                        return True
                    if int(prediction) == 2:
                        return False
                else:
                    return False

            frame +=1

# def __main__():
pg.init()
exp = fastReach(1)
exp.app(ems_on=True)
# input("continue with app")
# exp.app(ems_on=True)