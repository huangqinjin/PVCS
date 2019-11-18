from __future__ import print_function

import sys

#Works in Python 2 and 3:
try: input = raw_input
except NameError: pass

a = 1
while True:
    line = input('>')
    if line == "exit":
        break
    else:
        print("Echo {}".format(line))
        print("Error Code: {}".format(a))
        sys.stdout.flush()
        a = a + 1