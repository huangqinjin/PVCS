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
    sys.stdout.write('>')
    sys.stdout.flush()
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
    sys.stdout.flush()
