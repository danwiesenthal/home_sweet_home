#!/usr/bin/env python
# coding=UTF-8
# Credit to Steve Losh!  Modified from his version, which can be found at: http://stevelosh.com/blog/2010/02/my-extravagant-zsh-prompt/

from __future__ import unicode_literals
import math
import subprocess
import string
import sys


p = subprocess.Popen(["ioreg", "-rc", "AppleSmartBattery"], stdout=subprocess.PIPE)
output = p.communicate()[0]

o_max_line = [l for l in output.splitlines() if ('MaxCapacity' in str(l) and len(str(l)) < 100)][0]
o_cur_line = [l for l in output.splitlines() if 'CurrentCapacity' in str(l)][0]

b_max_string = str(o_max_line).rpartition('=')[-1].strip()
b_max = float(''.join([c for c in b_max_string if c not in string.punctuation]))
b_cur_string = str(o_cur_line).rpartition('=')[-1].strip()
b_cur = float(''.join([c for c in b_cur_string if c not in string.punctuation]))


charge = b_cur / b_max
charge_threshold = int(math.ceil(10 * charge))

# Output
total_slots, slots = 10, []
filled = int(math.ceil(charge_threshold * (total_slots / 10.0))) * u'▸'
empty = (total_slots - len(filled)) * u'▹'

out_triangles = (filled + empty)

# Good:
color_green = u'%{[32m%}'
color_yellow = u'%{[1;33m%}'
color_red = u'%{[31m%}'
color_reset = u'%{[00m%}'

# Not good:
# color_green = '\033[0;32m'
# color_yellow = '\033[0;33m'
# color_red = '\033[0;31m'
# color_reset = '\033[0m'


color_out = (
    color_green if len(filled) > 5
    else color_yellow if len(filled) > 2
    else color_red
)

out = color_out + out_triangles + color_reset

if sys.version_info < (3,):
    sys.stdout.write(out.encode('utf-8'))
else:
    sys.stdout.write(out)
