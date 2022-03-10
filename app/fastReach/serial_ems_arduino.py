import serial
ems = serial.Serial(port='/dev/cu.usbmodem1101', baudrate=9600, timeout=.1)

while True:
    ems_wait = input("press enter to send a EMS pulse: ") 
    ems.write("p".encode('utf-8'))
    