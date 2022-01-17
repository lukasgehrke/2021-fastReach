
"""Example program to demonstrate how to send string-valued markers into LSL."""

import random
import time
import keyboard

from pylsl import StreamInfo, StreamOutlet

def send_marker(out, marker):
    out.push_sample([marker])
    print(marker)

def main():
    # first create a new stream info (here we set the name to MyMarkerStream,
    # the content-type to Markers, 1 channel, irregular sampling rate,
    # and string-valued data) The last value would be the locally unique
    # identifier for the stream as far as available, e.g.
    # program-scriptname-subjectnumber (you could also omit it but interrupted
    # connections wouldn't auto-recover). The important part is that the
    # content-type is set to 'Markers', because then other programs will know how
    #  to interpret the content
    info = StreamInfo('CalibrationTest_fastReach', 'Markers', 1, 0, 'string')
    # next make an outlet
    outlet = StreamOutlet(info)

    print("now sending markers...")

    keyboard.add_hotkey('s', send_marker, args=(outlet, 'start'))
    keyboard.add_hotkey('n', send_marker, args=(outlet, 'end'))

    while True:
        if keyboard.is_pressed('esc'):  # if key 'escape' is pressed
            send_marker(outlet, 'exit')
            break

if __name__ == '__main__':
    main()