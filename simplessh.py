#!/usr/bin/python -u

import sys, re, os
from subprocess import *

def get_open_port():
	import socket
	s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	s.bind(("",0))
	s.listen(1)
	port = s.getsockname()[1]
	s.close()
	return port

localport = get_open_port()


args = sys.argv
quiet = False
rsynccomp = False
if "-quiet" in sys.argv: quiet = True; args.remove("-quiet")
if "-rsync" in sys.argv: quiet = True; rsynccomp = True; args.remove("-rsync")

tun = Popen([os.path.dirname(sys.argv[0]) + "/mac/newtunnel/build/Debug/newtunnel", "22", str(localport)], stdout=PIPE, stderr=STDOUT)

if not quiet: print "** Started tunnel, waiting to be ready ..."
while True:
	l = tun.stdout.readline()
	if not quiet: sys.stdout.write(l)
	if re.search("Waiting for connection", l):
		if not quiet: print "** Ready for SSH !"
		break

sshhost = "mobile@localhost -p " + str(localport) + " -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile /dev/null\""
if rsynccomp:
	sshcmd = "ssh " + sshhost + " " + " ".join(args[2:]) # first rsync arg is host but we replace that here
else:
	sshcmd = "ssh " + " ".join(args[1:]) + " " + sshhost
if not quiet: print "** running:", sshcmd
os.system(sshcmd)

if not quiet: print "** finished, killing tunnel"
tun.terminate()
