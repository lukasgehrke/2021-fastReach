from fastReach import fastReach

# system = 'mac' # 'mac' or 'windows'
# if system == 'mac':
#     arduino_port = '/dev/tty.usbmodem21401'
#     # path = '/Users/lukasgehrke/Documents/publications/2021-fastReach'
#     path = '/Volumes/projects/Lukas_Gehrke/2021-fastReach'
# elif system == 'win':
#     arduino_port = 'COM3' # ls /dev/tty.*
#     path = 'C:\\Users\\neuro\\Documents\\GitHub\\2021-fastReach\\'
#     # TODO: add windows path of server drive project folder

path = '/Users/lukasgehrke/Documents/publications/2021-fastReach/' # add path to repository here!!!
arduino_port = ''

### Settings for each participant ###
pID = 3

# trial_type = 'baseline'
trial_type = 'ems_bci'
# trial_type = 'ems_random'
# trial_type = 'training'

if trial_type == 'training':
    num_trials = 9
else:
    num_trials = 75

if trial_type == 'baseline':
    with_ems = False
else:
    with_ems = True

debug = True

exp = fastReach(pID, path, with_ems, trial_type, arduino_port, num_trials, debug)
exp.start()