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

sshparams = "-p " + str(localport) + " -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile /dev/null\""
sshhost = "mobile@localhost " + sshparams
if rsynccomp:
	if args[3] == "--server":
		# args[1:3] : {host} rsync --server
		sshcmd = "ssh " + sshhost + " " + " ".join(args[2:])
	elif args[5] == "--server" and args[1] == "-l":
		# args[1:4] : -l {user} {host} rsync --server
		sshhost = args[2] + "@localhost " + sshparams
		sshcmd = "ssh " + sshhost + " " + " ".join(args[4:]) # first rsync arg is host but we replace that here
	else:
		raise Exception, "unknown command string: [" + ";".join(args) + "]"
else:
	sshcmd = "ssh " + " ".join([sshhost] + args[1:] + ["2>/dev/null"])
if not quiet: print "** running:", sshcmd
os.system(sshcmd)

if not quiet: print "** finished, killing tunnel"
tun.terminate()
