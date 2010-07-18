/*
 Copyright (C) 2009 novi.
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <pthread.h>
#include <Foundation/Foundation.h>

int lockdown_checkin(int, int);


#define ssh_relay_log_err(arg, code) {NSLog(@"SSHRELAY-ERROR: " @arg @", code=%d", (code));}
#define ssh_relay_log_info(arg) {NSLog(@"SSHRELAY-INFO: " @arg);}

struct transfer_sock
{
	int lockd_sock;
	int cli_sock;
};

#define BUFFER_SIZE (1024*512)
#define SOCKET_ERROR -1

int transfer_valid;

void transfer_cli_to_lockdsock(struct transfer_sock* sock)
{
	ssize_t size_read, size_write;
	char* buf = malloc(BUFFER_SIZE);
	
	while (1) {
		// Read client data and write data to lockdown
		size_read = read(sock->cli_sock, buf, BUFFER_SIZE);
		//	NSLog(@"cli-sock read %d", size_read);
		size_write = write(sock->lockd_sock, buf, size_read);
		
		// If have errors
		if (size_read == 0 || size_write == 0 ||
			size_read == SOCKET_ERROR || size_write == SOCKET_ERROR) {
			
			close(sock->cli_sock);
			free(sock);
			
			free(buf);
			
			transfer_valid = 0;

			// Exit thread
			return;
		}
	}
	
}

void transfer_lockdsock_to_cli(struct transfer_sock* sock)
{
	ssize_t size_read, size_write;
	char* buf = malloc(BUFFER_SIZE);

	
	while (1) {
		size_read = read(sock->lockd_sock, buf, BUFFER_SIZE);
		//NSLog(@"lock_sock read %d", size_read);
		size_write = write(sock->cli_sock, buf, size_read);
		
		if (size_read == 0 || size_write == 0 ||
			size_read == SOCKET_ERROR || size_write == SOCKET_ERROR) {
			
			close(sock->lockd_sock);
			free(sock);
			
			free(buf);
			
			transfer_valid = 0;
			
			return;
		}
	}
	
}

int main(int argc, char *argv[]) {
    
	int lsock = lockdown_checkin(0, 0);
	if(lsock == -1) {
		ssh_relay_log_err("could not check in", -1);
        exit(EXIT_FAILURE);
    }
	
	char buf[BUFSIZ];
	int headsize = recv(lsock, buf, BUFSIZ, 0);
	if (headsize <= 0) {
		ssh_relay_log_err("hello message read error", 0);
		exit(EXIT_FAILURE);
	}
	
	NSLog(@"hello message read: %s (%d byte)", buf, headsize);
	
	short port = 0;
	sscanf(buf, "HELLO LOCKDOWN PORT=%0x", &port);
	NSLog(@"get port number %d (%x)", port, port);
	
	// Create socket for client
	int csock = socket(AF_INET, SOCK_STREAM, 0);
	
	// Create address
	struct sockaddr_in address;
	//	memset(&address, 0, sizeof address);
	bzero(&address, sizeof address);
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = INADDR_ANY;
	address.sin_port = htons(port);
	
	// Connect to self server
	int ret = connect(csock, (struct sockaddr *)&address, sizeof address);
	if (0 != ret) {
		ssh_relay_log_err("connect error", ret);
		exit(EXIT_FAILURE);
	}
	
	ssh_relay_log_info("transfer started");
	
	
	struct transfer_sock* tsock1;
	struct transfer_sock* tsock2;
	tsock1 = malloc(sizeof (struct transfer_sock));
	tsock2 = malloc(sizeof (struct transfer_sock));
	
	if (NULL == tsock1 || NULL == tsock2) {
		ssh_relay_log_err("malloc error", EXIT_FAILURE);
		exit(EXIT_FAILURE);
	}
	
	tsock1->cli_sock = csock;
	tsock1->lockd_sock = lsock;
	tsock2->cli_sock = csock;
	tsock2->lockd_sock = lsock;
	
	int lpThreadId;
	int lpThreadId2;
	pthread_t thread1;
	pthread_t thread2;
	
	lpThreadId = pthread_create(&thread1, NULL, (void*)transfer_cli_to_lockdsock, (void*)tsock1);
	lpThreadId2 = pthread_create(&thread2, NULL, (void*)transfer_lockdsock_to_cli, (void*)tsock2);
	
	pthread_detach(thread2);
	pthread_detach(thread1);
	
	transfer_valid = 1;
	
	while (1) {
		sleep(1);
		if (transfer_valid == 0) {
			break;
		}
	}
	
	ssh_relay_log_info("transfer closed");

	close(lsock);
    return 0;
}
