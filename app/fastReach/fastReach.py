
import pygame as pg
from pygame.locals import *
from pylsl import StreamInlet, resolve_stream
import numpy as np
import serial, time, random, string, pickle, json
from LSL import LSL

class fastReach:

    def __init__(self) -> None:
        self.lsl = LSL('fastReach')

        path = '/Users/lukasgehrke/Documents/publications/2021-fastReach/app/fastReach/'
        self.config = json.load(open(path+'config.json', 'r'))
        self.markers = json.load(open(path+'markers.json', 'r'))
        # self.lsl.send(self.markers['create'],1)     
        self.instruction = json.load(open(path+'instructions.json', 'r'))

        self.ems = EmsClassifier()

    def init_screen(self):
        info = pg.display.Info()
        # self.screen = pg.display.set_mode((info.current_w, info.current_h), pg.FULLSCREEN) 
        self.screen = pg.display.set_mode((600, 600), pg.RESIZABLE)
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

    def training(self):
        
        self.init_screen()
        self.init_txt()

        trial_counter = 0
        key_press_time = time.time()
        running = False
        trial = False

        while trial_counter<self.config['num_trainings_trials']:

            elapsed = time.time() - key_press_time

            if elapsed < 4 and trial == True:
                self.instruct(self.instruction["training start"])

            elif elapsed > 4 and trial == True:
                letter = random.choice(string.ascii_uppercase)
                self.instruct(self.instruction["training task"]+letter)
                trial = False

            for event in pg.event.get():
                if event.type == pg.KEYDOWN:

                    if event.key == pg.K_SPACE and running == False:

                        self.lsl.send(self.markers['training start'],1)
                        running = True
                        trial = True
                        key_press_time = time.time()

                    if event.key == pg.K_ESCAPE:
                        pg.display.quit()

                    elif elapsed > 4:
                        
                        key_press_time = time.time()
                        trial_counter += 1
                        marker = self.markers["reach end"]+self.markers["trial number"]+str(trial_counter)+';'
                        self.lsl.send(marker,0)
                        print(marker)
                        trial = True

            if trial_counter == self.config['num_trainings_trials']:
                self.lsl.send(self.markers['training end'],1)
                # TODO send close the recording command to labrecorder

    def experiment(self):
        
        self.ems.run()

        # check EMS classifier output
        if self.ems.run:
            pass

class EmsClassifier:
    
    def __init__(self, ems_port='/dev/cu.usbmodem11201') -> None:
        # self.ems = serial.Serial(port=ems_port, baudrate=9600, timeout=.1)
        pass
    
    def run(self):

        # pickle load the model and good chans ix

        # first resolve an EMG stream on the lab network
        print("looking for an EEG stream...")
        # streams = resolve_stream('type', 'EEG')

        # # create a new inlet to read from the stream
        # inlet = StreamInlet(streams[0])

        # # create empty numpy array (2D: m1 and m2)
        # all_data = np.array([[],[]])

        # # set window_size and threshold
        # window_size = 250
        # threshold = 0.8
        # dropped_samples = 25 # number of samples dropped each round

        while True:
            pass

            # # get a new sample (you can also omit the timestamp part if you're not
            # # interested in it)
            # sample = inlet.pull_sample()
            # sample = sample[good_chans]
            
            # # add sample to all_data array
            # # TODO: dont use np.append, instead overwrite using indices of all_data array so not copies are created
            # all_data = np.append(all_data, [[sample[0]],[sample[1]]], axis = 1)
            
            # if all_data.shape[1] == window_size:
                
            #     # filter the data? fast enough?

            #     # feature calculations
            #     RMS_m1 = np.sqrt(np.sum(np.square(all_data[0]))/window_size)
            #     RMS_m2 = np.sqrt(np.sum(np.square(all_data[1]))/window_size)
                            
            #     # MAV
            #     MAV_m1 = np.sum(np.absolute(all_data[0]))/window_size
            #     MAV_m2 = np.sum(np.absolute(all_data[1]))/window_size 
                
            #     # VAR
            #     VAR_m1 = np.sum(np.square(all_data[0]))/(window_size-1)
            #     VAR_m2 = np.sum(np.square(all_data[1]))/(window_size-1) 
                            
            #     features = np.array([RMS_m1, RMS_m2, MAV_m1, MAV_m2, VAR_m1, VAR_m2])
                
            #     # reshape: 1 datapoint + many features
            #     reshaped = features.reshape(1,-1)
                
            #     # prediction for emg-window
            #     prediction = clf.predict(reshaped)[0] #predicted class
            #     probs = clf.predict_proba(reshaped) #probability for class prediction
                
            #     if probs[0][prediction-1] > threshold: #-1 da class 1,2 und index 0,1
            #         if prediction == 1:
            #             # ems_wait = input("press enter to send a EMS pulse: ") 
            #             self.ems.write("p".encode('utf-8'))
            #             return True
            #         if prediction == 2:
            #             # self.ems.write("p".encode('utf-8'))
            #             return False
                        
            #     # drop first entry
            #     # TODO: instead of np.delete overwrite the matrix entries
            #     all_data = np.delete(all_data, np.s_[:dropped_samples] , axis = 1)

# def __main__():
pg.init()
exp = fastReach()
exp.training()