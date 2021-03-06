from __future__ import print_function

import os
import sys
import traceback

#Works in Python 2 and 3:
try: input = raw_input
except NameError: pass

vars = {}
for v in ["PCLI_PR", "PCLI_PP", "PCLI_ID"]:
    vars[v] = os.getenv(v)

while True:
    sys.stdout.write('>')
    sys.stdout.flush()
    try:
        args = input().split()
        args[0] = args[0].lower()
        if args[0] == "exit":
            break
        elif args[0] == "set":
            vars[args[1][2:]] = args[2].replace('"', '')
        elif args[0] == "echo":
            print(args[1].format(**vars).replace('$', ''))
        elif args[0] == "ask":
            sys.stdout.write("Right? (y/n) ")
            sys.stdout.flush()
            print("Answer: " + input())
        else:
            print(" ".join(args).upper())
        sys.stdout.write("Error Code: 0")
    except:
        traceback.print_exc()
        sys.stdout.write("Error Code: -1")
