
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
        
        self.init_screen(fullscreen=True)
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
            self.ems = serial.Serial(port='/dev/cu.usbmodem11201', baudrate=9600, timeout=.1)
            model_path_eeg = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_motion.sav'
            self.eeg = Classifier(model_path_eeg, 'eeg')
            model_path_motion = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_eeg.sav'
            self.motion = Classifier(model_path_motion, 'motion')

        trial_counter = 0
        start = time.time()
        running = False
        trial = False
        marker_sent = False
        name = []

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
                if self.eeg.state() == True and self.motion.state() == False and ems_sent == False:
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
                # TODO send close the recording command to labrecorder

class Classifier(Thread):
    
    def __init__(self, model_path, type) -> None:
        self.model_path = model_path

        # pickle load the model and good chans ix
        self.clf = pickle.load(open(self.model_path, 'rb'))

        # if type == 'motion':
        #     streams = resolve_stream('type', 'rigidBody')
        # elif type == 'eeg':
        #     streams = resolve_stream('type', 'eeg')

        # # create a new inlet to read from the stream
        # self.inlet = StreamInlet(streams[0])

        # create empty numpy array (2D: m1 and m2)
        self.all_data = np.array([[],[]])

        # set window_size and threshold
        # TODO make this as passed parameters
        self.window_size = 250
        self.threshold = 0.8
        self.dropped_samples = 25 # number of samples dropped each round
    
    def state(self):

        while True:

            # get a new sample (you can also omit the timestamp part if you're not interested in it)
            sample = self.inlet.pull_sample()
            # sample = sample[good_chans]
            
            # add sample to all_data array
            # TODO: dont use np.append, instead overwrite using indices of all_data array so not copies are created
            self.all_data = np.append(self.all_data, [[sample[0]],[sample[1]]], axis = 1)
            
            if self.all_data.shape[1] == self.window_size:
                
                # filter the data? fast enough?

                # feature calculations
                RMS_m1 = np.sqrt(np.sum(np.square(self.all_data[0]))/self.window_size)
                            
                features = np.array([RMS_m1, RMS_m2, MAV_m1, MAV_m2, VAR_m1, VAR_m2])
                
                # reshape: 1 datapoint + many features
                reshaped = features.reshape(1,-1)
                
                # prediction for emg-window
                prediction = self.clf.predict(reshaped)[0] #predicted class
                probs = self.clf.predict_proba(reshaped) #probability for class prediction
                
                if probs[0][prediction-1] > self.threshold: #-1 da class 1,2 und index 0,1
                    if prediction == 1:
                        return True
                    if prediction == 2:
                        return False
                        
                # drop first entry
                # TODO: instead of np.delete overwrite the matrix entries
                self.all_data = np.delete(self.all_data, np.s_[:self.dropped_samples] , axis = 1)

# def __main__():
pg.init()
exp = fastReach(1)
exp.app(ems_on=False)
input("continue with app")
exp.app(ems_on=True)