
import os
import pygame as pg
from pygame.locals import *
import numpy as np
import pandas as pd
import serial, time, json
from LSL import LSL
from pylsl import StreamInlet, resolve_stream

from bsl import StreamReceiver
import ptext
import random

from Classifier import Classifier

EEG_UPDATE_RATE = .15 # TODO this has to be higher than an LSL pull_sample takes on the machine this is running on

class fastReach:
    """Experiment triggering electrical muscle stimulation EMS directly from the output of a brain-computer interface (BCI)
    This class initializes the different components, starts an EEG and motion classifier in separate threads, and draws the experiment to the screen.

    The experiment shows different letters on screen and waits for them to be pressed, then an intentional binding task follows.
    This plays a sound and asks the participant to estimate the duration of the sound.

    Args:
        pID (integer): participant ID used to save data
        path (string): path to the data folder
        self.ems_on (boolean): whether to run with or without electrical muscle stimulation (EMS)
        arduino_port (string): port of connected arduino device
        num_trials (integer): Number of trials to complete
        debug (boolean): whether to print debug messages
    """

    def __init__(self, pID, code_path, data_path, ems_on, trial_type, arduino_port, num_trials, debug) -> None:
        self.lsl = LSL('fastReach')
        
        self.pID = 'sub-0' + "%02d" % (pID)
        self.code_path = code_path+os.sep+'app'+os.sep+'fastReach'+os.sep
        self.data_path = data_path+os.sep+self.pID+os.sep

        self.markers = json.load(open(self.code_path+'markers.json', 'r'))
        self.instruction = json.load(open(self.code_path+'instructions.json', 'r'))
        
        self.isi_range = [3.5, 4.5]
        self.idle_marker_after_isi_start = self.isi_range[0] - 2

        # ib task settings
        ib_delays = np.array([200, 350, 500])
        self.ib_times = np.repeat(ib_delays, num_trials/len(ib_delays), axis=0)
        np.random.shuffle(self.ib_times)

        pg.init()
        self.init_screen(fullscreen=False)
        self.init_txt()
        self.init_sound(self.code_path)
        
        self.trial_type = trial_type
        self.num_trials = num_trials
        self.trial_counter = 0

        # default values
        self.ems_randommin = 0
        self.ems_randommax = 1
        self.ems_on = ems_on

        self.init_trial()

        if self.ems_on == True:
            
            # self.ems = serial.Serial(port=arduino_port, baudrate=9600, timeout=.1)
            self.ems_training_delay = 2
            stim_delay = pd.read_csv(self.data_path+'delay.csv')
            self.ems_randommin = float(stim_delay.columns[0])
            self.ems_randommax = float(stim_delay.columns[1])

        if self.trial_type == 'ems_bci':
            
            # resolve eeg_classifier stream
            # self.eeg_state_stream = StreamReceiver(winsize=1, bufsize=1, stream_name='eeg_state')

            streams = resolve_stream('name', 'eeg_classifier')
            self.classifier_inlet = StreamInlet(streams[0])
            time.sleep(1)

            self.eeg_state = False
            
            # now running Classifier externally and streaming output via LSL
            #model_path_eeg = self.data_path+'model_'+str(self.pID)+'_eeg.sav'
            #with open(self.data_path+os.sep+'bci_params.json', 'r') as f:
            #    bci_params = json.load(f)

            #self.eeg = Classifier('eeg_classifier', bci_params['classifier_update_rate'], bci_params['data_srate'], model_path_eeg, 
            #                         bci_params['target_class'], bci_params['chans'], bci_params['threshold'], bci_params['windows'], bci_params['baseline'],
            #                         debug)
            #self.eeg.start()

    def init_screen(self, fullscreen):
        """Initialize screen object using pygame

        Args:
            fullscreen (boolean): Whether to run in fullscreen mode
        """
        info = pg.display.Info()
        if fullscreen == True:
            self.screen = pg.display.set_mode((info.current_w, info.current_h), pg.FULLSCREEN) 
        else:
            self.screen = pg.display.set_mode((1200, 600), pg.RESIZABLE)
        self.screen.fill((240, 240, 240))
        self.screen_rect = self.screen.get_rect()

    def init_txt(self):
        self.font = pg.font.Font(None, 45)

    def init_sound(self, sound_file_path):

        pg.mixer.init()
        pg.mixer.music.load(sound_file_path+os.sep+'1glockenspiel.wav')

    def init_trial(self):
        
        self.isi_dur = random.uniform(self.isi_range[0], self.isi_range[1])
        self.trial_counter += 1

        # trial logic
        self.fix_cross_shown = False
        self.idle_marker_sent = False
        self.blank_shown = False
        self.button_pressed = False
        self.sound_played = False

        self.trial_marker_sent = False
        self.run_ib_task = False
        self.next_trial = False
        self.ib_answered = False

        # ib task
        self.ib_answer = []

        # ems
        self.ems_active = False
        self.ems_sent = False
        self.ems_delay = random.uniform(self.ems_randommin, self.ems_randommax)

        self.key_board_input_enabled = False
        self.mouse_input_enabled = False

        # bci
        self.classifier_update_start = time.time()

    def play_sound(self, duration):
        """Plays a sound using pygame

        Args:
            duration (integer): Duration in seconds that the sound is played
        """
        # self.sound.play(-1)
        # pg.time.delay(duration)
        # self.sound.stop()

        pg.mixer.music.play(loops=0)

    def flip_ems(self):
        
        # open discharge into resistor
        self.ems.write("r".encode('utf-8'))
        self.ems.write("e".encode('utf-8'))

    def send_ems_pulse(self, marker, trial_type):
        """Sends a pulse to the EMS device
        """
        # self.ems.write("r".encode('utf-8'))
        
        m = self.markers[marker]+';condition:'+trial_type+';trial_nr:'+str(self.trial_counter)
        self.lsl.send(m,1)

        if marker == "ems on":
            self.ems_active = True
        elif marker == "ems off":
            self.ems_active = False
        
        return time.time()

    def instruct(self, text, col = (0,0,0)):
        """Writes text to the screen object

        Args:
            text (string): The text to draw
            col (tuple, optional): Color of the text. Defaults to (0,0,0).
        """

        self.screen.fill((240, 240, 240))
        w, h = pg.display.get_surface().get_size()
        ptext.draw(text, center=(w/2, h/2), color=col, fontsize=120)  # Recognizes newline characters.
        pg.display.flip()
 
    def start(self):
        """_summary_

        Args:
            trial_type (string): Can be "training" or "experiment", "training" is always without EMS
            num_trials (integer): Number of trials to complete
            self.ems_on (boolean): Whether to EMS is presented or not
        """
        
        while True:
            for event in pg.event.get():
                if event.type == pg.KEYDOWN:

                    if event.key == pg.K_e:
                        self.flip_ems()

                    if event.key == pg.K_p:
                        self.ems.write("r".encode('utf-8'))

                    if event.key == pg.K_SPACE:

                        m = self.markers['start']+';condition:'+self.trial_type
                        self.lsl.send(m,1)
                        
                        # self.app(trial_type, num_trials, self.ems_on, start)
                        self.app(time.time())

    def app(self, start):
        """Experiment logic. Runs different task components based on increasing time, then waits for button inputs to reset time and step through different experiment components.

        Args:
            trial_type (string): Can be "training", "baseline", "ems_bci" or "ems_random". 
                - In 'training' mode, the ems is trigger 2 seconds after the fixation cross dissapears. 
                This can be used to make participants comfortable with the EMS stimulation device in the trial logic.
                - In 'baseline' mode, the ems is not triggered at all. This trial_type is used to obtain physiological training data.
                - In 'ems_bci' mode, the ems is controlled (after the fixation cross dissapears and until the touchscreen is touched) by a Brain-Computer Interface, see class Classifier2
                - In 'ems_random' mode, the ems is randomly activated in the time interval of the 5th and 95th percentile of the reaction times in the baseline data.
            self.ems_on (boolean): Whether to EMS is presented or not
            start (time object): time.time() of the experiment start
        """

        classifier_srate = start

        while self.trial_counter <= self.num_trials:
            
            # trial logic
            now = time.time()
            elapsed = now - start
            elapsed_classifier_srate = now - classifier_srate

            if self.trial_type == 'ems_bci' and elapsed_classifier_srate >= EEG_UPDATE_RATE:
                classifier_srate = time.time()

                tic = time.time()
                data = self.classifier_inlet.pull_sample()
                toc = time.time() - tic
                print(toc)

                if data[0] < 1:
                    self.eeg_state = False
                else:
                    self.eeg_state = True

                # print(self.eeg_state)

            # isi
            if elapsed < self.isi_dur and self.fix_cross_shown == False:
                self.instruct(self.instruction["isi"])
                self.fix_cross_shown = True

            # idle class marker
            if elapsed > self.idle_marker_after_isi_start and self.idle_marker_sent == False:
                m = self.markers['idle']+';isi_duration:'+str(self.isi_dur)+';condition:'+self.trial_type+';trial_nr:'+str(self.trial_counter)
                self.lsl.send(m,1)
                self.idle_marker_sent = True

            # "live"
            if elapsed > self.isi_dur:

                if self.blank_shown == False:
                    self.instruct(self.instruction["blank"])
                    self.blank_shown = True
                    self.mouse_input_enabled = True

                # ems behavior
                # if self.ems_on== True and self.mouse_input_enabled == True and self.ems_active == False and self.ems_sent == False:
                if elapsed > (self.isi_dur + 1) and self.ems_on == True and self.mouse_input_enabled == True and self.ems_active == False and self.ems_sent == False:
                    # if self.trial_type == 'ems_bci' and self.eeg.state == True:
                    if self.trial_type == 'ems_bci' and self.eeg_state == True:
                        ems_time = self.send_ems_pulse("ems on", self.trial_type)
                        print('send pulse')
                    elif self.trial_type == 'ems_random' and elapsed > (self.ems_delay + self.isi_dur):
                        ems_time = self.send_ems_pulse("ems on", self.trial_type)
                    elif self.trial_type == 'training' and elapsed > (self.ems_training_delay + self.isi_dur):
                        ems_time = self.send_ems_pulse("ems on", self.trial_type)
                if self.ems_on == True and self.ems_active == True and self.ems_sent == False:
                    ems_duration = time.time() - ems_time
                    if ems_duration > .5:
                        self.send_ems_pulse("ems off", self.trial_type)
                        self.ems_sent = True

                # deactivates that ems can be triggered after tap, since the sound appears with a delay, the ems could be triggered after the tap but before the sound was played, this fixes that
                if self.button_pressed == True:
                    self.mouse_input_enabled = False

                # ib task following tap
                if self.button_pressed == True and ((time.time() - button_press_time) * 1000) > self.ib_times[self.trial_counter-1]:
                    pg.mixer.music.play()
                    m = self.markers["ib_task"]+"start"+';condition:'+self.trial_type+';trial_nr:'+str(self.trial_counter)
                    self.lsl.send(m,1)
                    
                    self.sound_played = True
                    self.button_pressed = False
                    self.key_board_input_enabled = True

                if self.sound_played == True:
                    self.instruct("Antwort: "+answer_string)

                if self.ib_answered == True:
                    m = self.markers["ib_task"]+'answer'+';real_delay:'+str(self.ib_times[self.trial_counter-1])+';estimated_delay:'+answer_string+';condition:'+self.trial_type+';trial_nr:'+str(self.trial_counter)
                    self.lsl.send(m,1)
                    self.init_trial()
                    start = time.time()
                    self.ib_answered = False

            # keyboard input
            for event in pg.event.get():

                # touchscreen tap to start ib task
                if self.mouse_input_enabled == True and event.type == pg.MOUSEBUTTONDOWN:
                    self.button_pressed = True
                    button_press_time = time.time()
                    m = self.markers["reach end"]+';rt:'+str(elapsed-self.isi_dur)+';condition:'+self.trial_type+';trial_nr:'+str(self.trial_counter)
                    self.lsl.send(m,1)
                    answer_string = ''.join(self.ib_answer)

                if event.type == pg.KEYDOWN and event.key == pg.K_ESCAPE:
                    pg.display.quit()
                    if self.ems_on:
                        self.flip_ems()

                if self.key_board_input_enabled == True and event.type == pg.KEYDOWN:

                    if event.key == pg.K_RETURN or event.key == pg.K_KP_ENTER:
                        self.ib_answered = True

                    if button_press_time > self.ib_times[self.trial_counter-1] and not self.ib_answered == True:

                        if event.key == pg.K_BACKSPACE and not len(self.ib_answer) == 0:
                            self.ib_answer.pop()    
                        elif not event.key == pg.K_BACKSPACE:
                            self.ib_answer.append(event.unicode)
                        answer_string = ''.join(self.ib_answer)

        else:
            m = self.markers['end']+';condition:'+self.trial_type
            self.lsl.send(m,1)
            self.instruct(self.instruction["wait"])