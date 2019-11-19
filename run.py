from __future__ import print_function

import sys

#Works in Python 2 and 3:
try: input = raw_input
except NameError: pass

vars = {
    "PCLI_PR": "",
    "PCLI_PP": "",
    "PCLI_ID": "",
}
while True:
    args = input('>').split()
    if args[0] == "exit":
        break
    elif args[0] == "Set":
        vars[args[1][2:]] = args[2].replace('"', '')
    elif args[0] == "Echo":
        print(args[1].format(**vars).replace('$', ''))
    else:
        print("Echo {}".format(" ".join(args)))
    print("Error Code: {}".format(0))
    sys.stdout.flush()
