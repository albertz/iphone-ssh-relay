#!/usr/bin/python

import os, sys

def shellquote(s):
    return "'" + s.replace("'", "'\\''") + "'"

# use a random host-name in either $1 or $2
os.system("rsync -avP -e " + shellquote( shellquote(os.path.dirname(sys.argv[0])) + "/simplessh.py -rsync")
		  + " " + " ".join(map(shellquote, sys.argv[1:]))
		 )
