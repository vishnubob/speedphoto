#!/usr/bin/python

from optparse import OptionParser
import serial
import time

class Arduino:
    def __init__(self, port, baud=9600, debug=False):
        self.debug = debug
        self.port = serial.Serial(port, baud)
        
    def send(self, msg):
        if self.port:
            self.port.write(msg)
            time.sleep(.1)
        if self.debug:
            print "send => %s" % msg.strip()

    def recv(self):
        msg = ''
        while self.port.inWaiting():
            msg += self.port.read()
        if self.debug:
            print "recv <= %s" % msg.strip()
        return msg
    
    def reset(self):
        self.port.setDTR(1)
        time.sleep(.1)
        self.port.setDTR(0)

    def in_waiting(self):
        return self.port.inWaiting()

    def poll(self):
        while (not self.in_waiting()):
            pass

class FlashPhoto:
    def __init__(self, arduino):
        self.arduino = arduino

    def send_int(self, val):
        val = str(val)
        for char in val:
            self.arduino.send(char)
        if val < 0:
            self.arduino.send('-')

    def run(self, start, end, inc, repeat):
        cnt = 1
        for delay in range(start, end, inc):
            for r in range(repeat):
                print "pic #%d at %d" % (cnt, delay)
                self.send_int(delay)
                self.arduino.send('d')
                self.arduino.send('a')
                self.arduino.send('q')
                time.sleep(5)
                self.arduino.recv()
                cnt += 1

def get_args():
    parser = OptionParser()
    parser.add_option("-p", "--port", help="arduino port")
    parser.add_option("-r", "--repeat", type="int", help="repeat value")
    parser.add_option("-s", "--start", type="int", help="start value")
    parser.add_option("-e", "--end", type="int", help="end value")
    parser.add_option("-i", "--increment", type="int", help="arduino port")
    parser.set_defaults(port="/dev/ttyUSB0", repeat=1, start=0, end=1, increment=1)
    (opts, args) = parser.parse_args()
    opts = eval(str(opts))
    return opts, args

def run(opts, args):
    #arduino = Arduino(opts['port'], debug=True)
    arduino = Arduino(opts['port'])
    fp = FlashPhoto(arduino)
    fp.run(opts['start'], opts['end'], opts['increment'], opts['repeat'])

if __name__ == '__main__':
    opts, args = get_args()
    run(opts, args)
