import os
start = ''
try:
    start += os.environ['ARGN'] + ": "
    for x in range(0, int(os.environ['ARGN'])):
        start += os.environ['ARG'+`x`] + ","
    print start
except KeyError:
    print "ARGN undefined"
