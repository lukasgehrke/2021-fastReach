
import re
import pygame as pg
from pygame.locals import *
from pylsl import StreamInfo, StreamOutlet, StreamInlet, resolve_stream
import numpy as np
import serial, time, pickle, json, sys
from LSL import LSL
import threading
import ptext
import random
from bci_funcs import windowed_mean, base_correct, reshape_trial, drop_baseline
# import matplotlib.pyplot as plt

EMS_RESET_TIME = time.time()

class fastReach:
    """Experiment triggering electrical muscle stimulation EMS directly from the output of a brain-computer interface (BCI)
    This class initializes the different components, starts an EEG and motion classifier in separate threads, and draws the experiment to the screen.

    The experiment shows different letters on screen and waits for them to be pressed, then an intentional binding task follows.
    This plays a sound and asks the participant to estimate the duration of the sound.

    Args:
        pID (integer): participant ID used to save data
        ems_on (boolean): whether to run with or without electrical muscle stimulation (EMS)
        arduino_port (string): port of connected arduino device
    """

    def __init__(self, pID, ems_on, arduino_port, num_trials, debug) -> None:
        self.lsl = LSL('fastReach')

        self.print_states = debug
        
        self.pID = pID
        path = 'C:\\Users\\neuro\\Documents\\GitHub\\2021-fastReach\\app\\fastReach\\'
        self.config = json.load(open(path+'config.json', 'r'))
        self.markers = json.load(open(path+'markers.json', 'r'))
        self.instruction = json.load(open(path+'instructions.json', 'r'))
        
        self.isi_range = [3.5, 4.5]
        self.idle_marker_after_isi_start = self.isi_range[0] - 2

        # ib task settings
        ib_delays = np.array([200, 350, 500])
        self.ib_times = np.repeat(ib_delays, num_trials/len(ib_delays), axis=0)
        np.random.shuffle(self.ib_times)

        pg.init()
        self.init_screen(fullscreen=False)
        self.init_txt()
        self.init_sound(path)
        
        self.num_trials = num_trials
        self.trial_counter = 0
        self.init_trial()

        if ems_on == True:
            
            self.ems = serial.Serial(port=arduino_port, baudrate=9600, timeout=.1)

            # self.ems_resetter = EMSResetter(self.ems, self.lsl, self.markers)
            # self.ems_resetter.start()

            data_path = 'C:\\Users\\neuro\\Documents\\GitHub\\2021-fastReach\\data\\study\\eeglab2python\\'+str(self.pID)
            model_path_eeg = data_path+'\\model_'+str(self.pID)+'_eeg.sav'
            chans = pickle.load(open(data_path+'\\chans_'+str(self.pID)+'_eeg.sav', 'rb'))
            
            classifier_update_rate = 25
            data_srate = 250
            windows = 11
            baseline_ix = 1
            target_class = 1
            threshold = .7

            self.eeg = Classifier2('eeg_classifier', classifier_update_rate, data_srate, model_path_eeg, target_class, chans, threshold, windows, baseline_ix)
            self.eeg.start()
            
            # buffer_feat_comp_size_samples = 275
            # windowed_mean_size_samples = 25
            # do_reg = False            
            # self.eeg = Classifier('eeg_classifier', (buffer_feat_comp_size_samples/windowed_mean_size_samples)-1,
            #     model_path_eeg, "eeg", target_class, chans, threshold, windowed_mean_size_samples, buffer_feat_comp_size_samples, do_reg)

            # model_path_motion = '/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/eeglab2python/'+str(self.pID)+'/model_'+str(self.pID)+'_motion.sav'
            # target_class = 1
            # chans = np.array([5,6,7])
            # threshold = 1.0
            # buffer_feat_comp_size_samples = 2
            # windowed_mean_size_samples = 2
            # do_reg = False

            # self.motion = Classifier('motion_classifier', 45, model_path_motion, "motion", target_class,
            #     chans, threshold, windowed_mean_size_samples, buffer_feat_comp_size_samples, do_reg)
            # self.motion.start()

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
        
        # sampleRate = 44100
        # # 44.1kHz, 16-bit signed, mono
        # pg.mixer.pre_init(sampleRate, -16, 1) 
        # # 4096 : the peak ; volume ; loudness
        # # 440 : the frequency in hz
        # arr = np.array([4096 * np.sin(2.0 * np.pi * 440 * x / sampleRate) for x in range(0, sampleRate)]).astype(np.int16)
        # self.sound = pg.sndarray.make_sound(arr)
        # self.IB_DURATION = 500
        # self.IB_stepsize = 50

        # TODO prepare new IB task
        pg.mixer.init()
        pg.mixer.music.load(sound_file_path+'1glockenspiel.wav')

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
        self.ems_delay = random.uniform(EMS2MIN, EMS2MAX)

        self.key_board_input_enabled = False
        self.mouse_input_enabled = False

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
        self.ems.write("r".encode('utf-8'))
        
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
 
    def start(self, trial_type, ems_on):
        """_summary_

        Args:
            trial_type (string): Can be "training" or "experiment", "training" is always without EMS
            num_trials (integer): Number of trials to complete
            ems_on (boolean): Whether to EMS is presented or not
        """
        
        while True:
            for event in pg.event.get():
                if event.type == pg.KEYDOWN:

                    if event.key == pg.K_e:
                        self.flip_ems()

                    if event.key == pg.K_p:
                        self.ems.write("r".encode('utf-8'))

                    if event.key == pg.K_SPACE:

                        m = self.markers['start']+';condition:'+trial_type
                        self.lsl.send(m,1)
                        
                        # self.app(trial_type, num_trials, ems_on, start)
                        self.app2(trial_type, ems_on, time.time())

    def app(self, trial_type, num_trials, ems_on, start):
        """Experiment logic. Runs different task components based on increasing time, then waits for button inputs to reset time and step through different experiment components.

        Args:
            trial_type (string): Can be "training" or "experiment", "training" is always without EMS
            num_trials (integer): Number of trials to complete
            ems_on (boolean): Whether to EMS is presented or not
            start (time object): time.time() of the experiment start
        """

        trial_counter = 0
        ib_answer = []
        trial_marker_sent = False
        run_ib_task = False
        next_trial = False
        ib_answered = False
        sound_played = False
        letter_written = False

        global EMS_RESET_TIME
        
        if trial_type == 'training':
            trial_dur = 4
            idle_marker_sent = False

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
                print([self.eeg.state, ems_sent, self.motion.state]) # , self.ems_resetter.state])
            
            # trial logic
            elapsed = time.time() - start
            if trial_counter < num_trials:
            
                # runs in training and shows ISI message for 2 seconds then sends a marker at the end
                if trial_type == 'training' and idle_marker_sent == False:
                    self.instruct(self.instruction["isi"])

                    # send idle marker only in training condition
                    if elapsed > 2:
                        self.lsl.send(self.markers['idle'],1)
                        idle_marker_sent = True

                # interactive part of each trial starts after some initial resting period. Shows the sentence written so far, then waits for a button press to occur which sets trial_marker_sent to true
                if elapsed > trial_dur:
                    
                    if trial_marker_sent == True:
                        if trial_type == 'training': # and time.time() - reach_end_time > 2: # next trial
                            # start = time.time()
                            trial_marker_sent = False
                            # idle_marker_sent = False
                            run_ib_task = True

                        elif trial_type == 'experiment':
                            # start = time.time()
                            trial_marker_sent = False
                            ems_counter = trial_counter    
                            run_ib_task = True

                    if run_ib_task == False and letter_written == False:
                        if (trial_counter % 2) == 0:
                            target = random.choice(['a','s','d'])
                        else:
                            target = random.choice(['j','k','l'])

                        # self.instruct(self.instruction["start"]+'\n\n'+''.join(ib_answer))
                        self.instruct(target+'\n\n'+''.join(ib_answer))
                        letter_written = True

                    elif run_ib_task == True:

                        # after Xs after button press, play a sound and let participants judge whether they think this was longer than their reach to press lasted
                        # print the adjusted IB so I can then add it to the live phase
                        
                        if time.time() - reach_end_time < 2:
                            # self.instruct(self.instruction["start"]+'\n\n'+''.join(ib_answer))
                            self.instruct(target+'\n\n'+''.join(ib_answer))

                        # some interval
                        if time.time() - reach_end_time > 2 and time.time() - reach_end_time < 7:
                            self.instruct(self.instruction["ib task wait"])
                            self.lsl.send(self.markers["ib_task"]+"start",1)

                        if time.time() - reach_end_time > 4 and sound_played == False:
                            print(self.IB_DURATION)
                            self.lsl.send(self.markers["ib_task"]+"tone",1)
                            self.play_sound(self.IB_DURATION)
                            sound_played = True

                        # Listen to the sound:
                        if time.time() - reach_end_time > 7:
                            self.instruct(self.instruction["ib task"])

                        if ib_answered == True:
                            next_trial = True

                    if next_trial == True:
                        if trial_type == 'training':
                            idle_marker_sent = False
                        
                        trial_end_time = time.time()
                        trial_counter += 1
                        
                        sound_played = False
                        ib_answered = False
                        run_ib_task = False
                        
                        start = time.time()
                        next_trial = False
                        
                        letter_written = False
                        ib_answer = []

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
                    
                    self.ems.write("r".encode('utf-8'))
                    self.ems.write("e".encode('utf-8'))

                    self.lsl.send(self.markers["ems off"],1)

                if elapsed > trial_dur and ems_counter == trial_counter and trial_marker_sent == False:

                    # print("ems live")

                    if self.motion.state == True:
                        ems_counter += 1
                        self.lsl.send(self.markers["deactivate EMS due to movement"],1)

                    if self.eeg.state == True and ems_sent == False and self.motion.state == False: # and self.ems_resetter.state == False:
    
                        self.ems.write("r".encode('utf-8'))
                        self.ems.write("e".encode('utf-8'))

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

                    if event.key == pg.K_UP:
                        self.IB_DURATION += self.IB_stepsize
                        self.lsl.send(self.markers["ib_task"]+str(self.IB_stepsize),1)
                        ib_answered = True
                    if event.key == pg.K_DOWN:
                        self.IB_DURATION -= self.IB_stepsize              
                        self.lsl.send(self.markers["ib_task"]+str(self.IB_stepsize),1)
                        ib_answered = True

                    if elapsed > trial_dur and trial_marker_sent == False and trial_counter < num_trials and run_ib_task == False:
                        # ib_answer.append(event.unicode)
                        ib_answer = event.unicode
                        # trial_counter += 1
                        self.lsl.send(self.markers["reach end"],1)
                        trial_marker_sent = True
                        reach_end_time = time.time()
                        print(elapsed)

    def app2(self, trial_type, ems_on, start):
        """Experiment logic. Runs different task components based on increasing time, then waits for button inputs to reset time and step through different experiment components.

        Args:
            trial_type (string): Can be "training" or "experiment", "training" is always without EMS
            num_trials (integer): Number of trials to complete
            ems_on (boolean): Whether to EMS is presented or not
            start (time object): time.time() of the experiment start
        """
        
        while True:
            
            # trial logic
            elapsed = time.time() - start

            if self.trial_counter <= num_trials:

                # isi
                if elapsed < self.isi_dur and self.fix_cross_shown == False:
                    self.instruct(self.instruction["isi"])
                    self.fix_cross_shown = True

                # idle class marker
                if elapsed > self.idle_marker_after_isi_start and self.idle_marker_sent == False:
                    m = self.markers['idle']+';isi_duration:'+str(self.isi_dur)+';condition:'+trial_type+';trial_nr:'+str(self.trial_counter)
                    self.lsl.send(m,1)
                    self.idle_marker_sent = True

                # "live"
                if elapsed > self.isi_dur:

                    if self.blank_shown == False:
                        self.instruct(self.instruction["blank"])
                        self.blank_shown = True
                        self.mouse_input_enabled = True

                    # ems behavior
                    if ems_on == True and self.mouse_input_enabled == True and self.ems_active == False and self.ems_sent == False:
                        if trial_type == 'ems1' and self.eeg.state == True:
                            ems_time = self.send_ems_pulse("ems on", trial_type)
                        elif trial_type == 'ems2' and elapsed > (self.ems_delay + self.isi_dur):
                            ems_time = self.send_ems_pulse("ems on", trial_type)
                    if ems_on == True and self.ems_active == True and self.ems_sent == False:
                        ems_duration = time.time() - ems_time
                        if ems_duration > .5:
                            self.send_ems_pulse("ems off", trial_type)
                            self.ems_sent = True

                    # ib task following tap
                    if self.button_pressed == True and ((time.time() - button_press_time) * 1000) > self.ib_times[self.trial_counter-1]:
                        pg.mixer.music.play()
                        m = self.markers["ib_task"]+"start"+';condition:'+trial_type+';trial_nr:'+str(self.trial_counter)
                        self.lsl.send(m,1)
                        
                        self.sound_played = True
                        self.button_pressed = False
                        self.mouse_input_enabled = False
                        self.key_board_input_enabled = True

                    if self.sound_played == True:
                        self.instruct("Antwort: "+answer_string)

                    if self.ib_answered == True:
                        m = self.markers["ib_task"]+'answer'+';real_delay:'+str(self.ib_times[self.trial_counter-1])+';estimated_delay:'+answer_string+';condition:'+trial_type+';trial_nr:'+str(self.trial_counter)
                        self.lsl.send(m,1)
                        self.init_trial()
                        start = time.time()
                        self.ib_answered = False
                    
            if self.trial_counter > num_trials:
                
                m = self.markers['end']+';condition:'+trial_type
                self.lsl.send(m,1)
                self.instruct(self.instruction["wait"])
                break

            # keyboard input
            for event in pg.event.get():

                if self.mouse_input_enabled == True and event.type == pg.MOUSEBUTTONDOWN:
                    self.button_pressed = True
                    button_press_time = time.time()
                    m = self.markers["reach end"]+';rt:'+str(elapsed-self.isi_dur)+';condition:'+trial_type+';trial_nr:'+str(self.trial_counter)
                    self.lsl.send(m,1)
                    answer_string = ''.join(self.ib_answer)

                if self.key_board_input_enabled == True and event.type == pg.KEYDOWN:

                    if event.key == pg.K_ESCAPE:
                        pg.display.quit()
                        if ems_on:
                            self.flip_ems()

                    if event.key == pg.K_RETURN:
                        self.ib_answered = True

                    if button_press_time > self.ib_times[self.trial_counter-1] and not self.ib_answered == True:
                        self.ib_answer.append(event.unicode)
                        answer_string = ''.join(self.ib_answer)

            # debug
            if self.print_states:
                # print('moving: '+str(self.motion.state))
                print('rp: '+str(self.eeg.state) + ', class: ' + str(self.eeg.prediction) + ', probs: ' + str(self.eeg.probs))
                # print([self.eeg.state, self.ems_sent, self.motion.state]) # , self.ems_resetter.state])

    def demo(self, mode):
        """Runs the classifiers without any task.

        Args:
            mode (string): Can be "eeg" or "button". In EEG mode, waits for the EEG classifier to return True, then triggers EMS. In "button" mode, trigger EMS from button press.
        """

        ems_time = time.time()
        ems_sent = False
        ems_timeout = True
        global EMS_RESET_TIME

        while True:

            ems_duration = time.time() - ems_time

            if ems_duration > .5 and ems_sent == True:
                ems_sent = False

                self.ems.write("r".encode('utf-8'))
                self.ems.write("e".encode('utf-8'))

                self.lsl.send(self.markers["ems off"],1)
            
            if ems_duration > 4:
                ems_timeout = False
        
            if mode == 'eeg':
                if self.eeg.state == True and ems_sent == False and self.motion.state == False and ems_timeout == False: # and self.ems_resetter.state == False:
                    
                    self.ems.write("r".encode('utf-8'))
                    self.ems.write("e".encode('utf-8'))

                    self.lsl.send(self.markers["ems on"],1)
                    ems_sent = True
                    ems_timeout = True
                    ems_time = time.time()
                    EMS_RESET_TIME = ems_time

            elif mode == 'button':

                for event in pg.event.get():
                    if event.type == pg.KEYDOWN:

                        if event.key == pg.K_ESCAPE:
                            pg.display.quit()
                            sys.exit()
                        else:
        
                            self.ems.write("r".encode('utf-8'))
                            self.ems.write("e".encode('utf-8'))

                            self.lsl.send(self.markers["ems on"],1)
                            ems_sent = True
                            ems_time = time.time()
                            EMS_RESET_TIME = ems_time

class Classifier2(threading.Thread):
    """Reads a data stream from LSL, computes features and predicts a class label and probability. For this, a model is loaded.

    Args:
        stream_name (string): ib_answer of LSL data stream created to stream classifier output
        classifier_srate (integer): Frame rate at which classifier is applied and streams out classification output
        model_path (string): Location of pickled (LDA) model
        type (string): "eeg" or "motion". This class can run classifier on EEG or Motion data
        target_class (integer): Returns true when prediction equals target class
        chans ([integer]): Channels (list) to be selected from LSL input data stream
        threshold (float): To evaluate whether prediction matches target_class with the probability exceeding this threshold
        frame_rate (integer): ?
        window_size (integer): Buffer size
        regression (boolean): [exploratory] When true, apply regression on features
    """
    def __init__(self, stream_name, classifier_srate, data_srate, model_path, target_class, chans, threshold, window_size, baseline_index) -> None:
        
        threading.Thread.__init__(self)

        # LSL outlet
        self.classifier_srate = classifier_srate
        stream_info = StreamInfo(stream_name, 'Classifier', 3, self.classifier_srate, 'double64', 'myuid34234')
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
        self.srate = data_srate

        self.all_data = np.zeros((len(self.chans), self.srate+int(self.srate/(self.window_size-self.baseline_ix))))
        self.feat_data = np.zeros((len(self.chans), self.window_size-self.baseline_ix))

        self.state = False
    
    def run(self):

        frame = 1
        while True:
            start = time.time()

            # get a new sample (you can also omit the timestamp part if you're not interested in it)
            sample = np.array(self.inlet.pull_sample()[0])
            self.all_data[:,-1] = sample[self.chans]

            if frame == self.classifier_srate: # every X ms

                tmp = base_correct(windowed_mean(self.all_data, windows = self.window_size))
                feats = drop_baseline(tmp, self.baseline_ix).flatten().reshape(1,-1)
        
                self.prediction = int(self.clf.predict(feats)[0]) #predicted class
                probs = self.clf.predict_proba(feats) #probability for class prediction
                self.outlet.push_sample([self.prediction,probs[0][0],probs[0][1]])
                self.probs = probs[0][0]

                if self.prediction == self.target_class and self.probs >= self.threshold:
                    self.state = True
                else:
                    self.state = False

                frame = 0

            frame += 1
            self.all_data = np.roll(self.all_data,-1) # Speed could be increased here, something like all_data[:,0:-2] = all_data[:,1:-1]

            time.sleep(max(1./self.srate - (time.time() - start), 0))

class Classifier(threading.Thread):
    """Reads a data stream from LSL, computes features and predicts a class label and probability. For this, a model is loaded.

    Args:
        stream_name (string): ib_answer of LSL data stream created to stream classifier output
        classifier_srate (integer): Frame rate at which classifier is applied and streams out classification output
        model_path (string): Location of pickled (LDA) model
        type (string): "eeg" or "motion". This class can run classifier on EEG or Motion data
        target_class (integer): Returns true when prediction equals target class
        chans ([integer]): Channels (list) to be selected from LSL input data stream
        threshold (float): To evaluate whether prediction matches target_class with the probability exceeding this threshold
        frame_rate (integer): ?
        window_size (integer): Buffer size
        regression (boolean): [exploratory] When true, apply regression on features
    """

    def __init__(self, stream_name, classifier_srate, model_path, type, target_class, chans, threshold, frame_rate, window_size, regression) -> None:
        self.model_path = model_path

        threading.Thread.__init__(self)

        self.classifier_srate = classifier_srate
        stream_info = StreamInfo(stream_name, 'Classifier', 3, self.classifier_srate, 'double64', 'myuid34234')
        self.outlet = StreamOutlet(stream_info)

        # pickle load the model and good chans ix
        self.clf = pickle.load(open(self.model_path, 'rb'))
        self.target_class = target_class

        self.type = type
        self.chans = chans

        if self.type == 'motion':
            streams = resolve_stream('type', 'rigidBody')
            
        elif self.type == 'eeg':
            streams = resolve_stream('name', 'BrainVision RDA')

        # create a new inlet to read from the stream
        self.inlet = StreamInlet(streams[0])

        self.threshold = threshold
        self.frame_rate = frame_rate
        self.window_size = window_size
        self.do_reg = regression
        self.baseline_size = 25

        # create empty numpy array (2D: m1 and m2)
        self.all_data = np.zeros((len(self.chans), self.window_size))
        self.reg_feats = np.zeros((len(self.chans), int(self.window_size/self.frame_rate)))

        self.feat_data = np.array((len(self.chans), 11, 25))

        self.state = False
    
    def run(self):

        frame = 1

        while True:

            start = time.time()

            # get a new sample (you can also omit the timestamp part if you're not interested in it)
            sample = np.array(self.inlet.pull_sample()[0])
            self.all_data[:,-1] = sample[self.chans-1].flatten() # TODO why flatten?

            if frame == self.classifier_srate: # every X ms

                if self.type == "motion":
                    feats = np.sqrt(
                        np.square(np.diff(self.all_data[0,:])) + 
                        np.square(np.diff(self.all_data[1,:])) + 
                        np.square(np.diff(self.all_data[2,:]))).reshape(1,-1)

                if self.type == "eeg":
                    # self.feat_data = np.reshape(self.all_data, (len(self.chans), 11, 25))
                    self.feat_data = base_correct(windowed_mean(self.all_data, windows = self.window_size))

                if self.do_reg == True:
                    try:
                        # t = time.time()
                        for i in range(len(self.chans)):
                            for j in range(10):
                                self.reg_feats[i,j] = np.polyfit(self.feat_data[i,j,:], self.feat_data[-1,j,:],1)[1]
                                feats = self.reg_feats.flatten().reshape(1,-1)
                        # elapsed = time.time() - t
                        # tmp.append(elapsed)
                    except:
                        print("waiting for buffer")
                else:
                    # feats = np.mean(self.feat_data, axis = 2) # windowed mean features
                    # feats -= feats[:,0][:,None] # base correct
                    feats = feats[:,1:]
                    # feats = feats.flatten().reshape(1,-1)
                    feats = reshape_trial(feats)
        
                prediction = self.clf.predict(feats)[0] #predicted class
                probs = self.clf.predict_proba(feats) #probability for class prediction
                self.outlet.push_sample([prediction,probs[0][0],probs[0][1]])

                if prediction == self.target_class and probs[0][0] >= self.threshold:
                    self.state = True
                else:
                    self.state = False

                frame = 0
                # print(str(prediction) + ' ' + str(probs))

            frame += 1
            self.all_data = np.roll(self.all_data,-1) # Speed could be increased here, something like all_data[:,0:-2] = all_data[:,1:-1]

            time.sleep(max(1./250 - (time.time() - start), 0))

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
    
                self.ems.write("r".encode('utf-8'))
                self.ems.write("e".encode('utf-8'))

                self.lsl.send(self.markers["ems reset"],1)
            if (time.time() - EMS_RESET_TIME) > 9.95 and self.state == True:
                
                self.ems.write("r".encode('utf-8'))
                self.ems.write("e".encode('utf-8'))

                EMS_RESET_TIME = time.time()
                self.state = False

### SET Experiment params ###
np.set_printoptions(precision=2)
arduino_port = 'COM3' #'/dev/tty.usbmodem21401' # ls /dev/tty.*


num_trials = 90 # muss durch 3 teilbar sein
pID = 1

#trial_type = 'baseline'
# trial_type = 'ems1'
trial_type = 'ems2'
EMS2MIN = 1
EMS2MAX = 2

if trial_type == 'baseline':
    with_ems = False
else:
    with_ems = True

###
debug = False
exp = fastReach(pID, with_ems, arduino_port, num_trials, debug)
exp.start(trial_type, with_ems)