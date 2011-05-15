#!/usr/bin/python

import math
import sys

i2m = 0.0254
freq = 16000000

def ticks(d):
    m = d * i2m
    t = math.sqrt((2*m) / 9.81)
    return (t * (freq / 256))

print ticks(int(sys.argv[1]))
