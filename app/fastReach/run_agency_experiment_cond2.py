from fastReach import fastReach

### Settings for each participant ###
pID = 12














system = 'win' # 'mac' or 'win'
if system == 'mac':
    arduino_port = '/dev/tty.usbmodem21401'
    # path = '/Users/lukasgehrke/Documents/publications/2021-fastReach'
    path = '/Volumes/projects/Lukas_Gehrke/2021-fastReach'
elif system == 'win':
    arduino_port = 'COM3' # ls /dev/tty.*
    # code_path = 'D:\\Lukas\\2021-fastReach'
    code_path = 'C:\\Users\\neuro\\Documents\\GitHub\\2021-fastReach'
    data_path = '\\\\stor1\projects\\Lukas_Gehrke\\fastReach\\data\\eeglab2python'

trial_type = 'ems_bci'
num_trials = 75
with_ems = True
debug = False

exp = fastReach(pID, code_path, data_path, with_ems, trial_type, arduino_port, num_trials, debug)
exp.start()