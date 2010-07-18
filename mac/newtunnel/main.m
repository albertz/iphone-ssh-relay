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

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "MobileDevice.h"
#include <stdio.h>
#include <unistd.h>
#include <netinet/ip.h>
#include <signal.h>
#include <pthread.h>

int ssock = -1;

#define BUFFER_SIZE (1024*2048)
#define SOCKET_ERROR -1

short srv_port = 0;
short dev_port = 0;

// 接続数
static int threadCount = 0;

struct connection
{
	int srv_sock;
	int cli_sock;
};

void transfer_srv_to_dev(struct connection* con)
{
	uint8_t* buffer = malloc(BUFFER_SIZE);
	int bytes_recv, bytes_send;
	
	// スレッドカウントを増やす
	threadCount++;
	fflush(stdout);
	printf("threadcount=%d\n",threadCount);
	fflush(stdout);
	
	while (1) {
		// Mac からのデータを受信
		bytes_recv = recv(con->srv_sock, buffer, BUFFER_SIZE, 0);
		
			printf("mac->iphone %d\n", bytes_recv);
		
		// それを iPhone へ送る
		bytes_send = send(con->cli_sock, buffer, bytes_recv, 0);
		
		// エラー発生
		if (bytes_recv == 0 || bytes_recv == SOCKET_ERROR || bytes_send == 0 || bytes_send == SOCKET_ERROR) {
			// スレッドカウントを減らす
			threadCount--;
			fflush(stdout);
			printf("threadcount=%d\n", threadCount);
			fflush(stdout);
			
			// コネクションを閉じる
			close(con->cli_sock);
			close(con->srv_sock);
			
			free(buffer);
			
			free(con);
			
			// スレッドを終了
			return;
		}
	}
}


void transfer_dev_to_srv(struct connection* con)
{
	uint8_t* buffer = malloc(BUFFER_SIZE);
	int bytes_recv, bytes_send;
	
	while (1) {
		// Receive data from self server
		bytes_recv = recv(con->cli_sock, buffer, BUFFER_SIZE, 0);
		
		printf("iphone->mac %d\n", bytes_recv);
		
		// Send data to server
		bytes_send = send(con->srv_sock, buffer, bytes_recv, 0);
		
		// If have any errors
		if (bytes_recv == 0 || bytes_recv == SOCKET_ERROR || bytes_send == 0 || bytes_send == SOCKET_ERROR) {
			close(con->cli_sock);
			close(con->srv_sock);
			free(con);
			
			free(buffer);
			
			// Exit thread
			return;
		}
	}
}
void hexdump(const char* buf, size_t size, const char* label)
{
	printf("----------%s----------\n", label);
	int i;
	for (i = 0; i < size; i++) {
		printf("%02x(%1c)", buf[i], buf[i]);
		if (i % 4 == 0) {
			printf("  ");
		}
	}
	printf("\n");
	
	printf("----------\n");
}

void notification(struct am_device_notification_callback_info* info)
{
	printf("Device notificaion\n");
	//printf("info; %s\n", info->dev->serial);

	
	puts("Info: Device connected.");
	
	int ret;
	// ターゲットが準備完了
	// デバイスへ接続
	struct am_device* target_device = info->dev;
	ret = AMDeviceConnect(target_device);
	if (ret != ERR_SUCCESS) {
		printf("AMDeviceConnect = %i\n", ret);
		exit(-1);
	}
	
	ret = AMDeviceIsPaired(target_device);
	if (ret != 1) {
		printf("AMDeviceIsPaired = %i\n", ret);
		exit(-1);
	}
	
	ret = AMDeviceValidatePairing(target_device);
	if (ret != ERR_SUCCESS) {
		printf("AMDeviceValidatePairing = %i\n", ret);
		exit(-1);
	}
	
	ret = AMDeviceStartSession(target_device);
	if (ret != ERR_SUCCESS) {
		printf("AMDeviceStartSession = %i\n", ret);
		exit(-1);
	}
	
	
	printf("Info: New connection...\n");
	
	
	
	

		
	while (1) {
		printf("// Waiting for connection // \n");
		fflush(stdout);
		int new_ssock = accept(ssock, NULL, NULL);
		
		if (-1 == new_ssock) {
			printf("accept error\n");
			continue;
		}
	
		// サービスを開始
		int handle;
		// サービス名と接続されたハンドルの戻り値をhandleで指定
		ret = AMDeviceStartService(target_device, CFSTR("com.apple.ssh_relay"), (int*)&handle);
		if (ret != ERR_SUCCESS) {
			printf("AMDeviceStartService = %x\n", ret);
			exit(-1);
		}
		
		int stmp = 1;
		if (setsockopt(handle, SOL_SOCKET, SO_KEEPALIVE, &stmp, sizeof stmp) != 0) {
			printf("setsockopt error\n");
			//exit(-1);
		}
		
		usleep(1000*1000);
		
		//const char* hellomsg = "HELLO LOCKDOWN PORT=16";
		char hellomsg[BUFSIZ];
		sprintf(hellomsg, "HELLO LOCKDOWN PORT=%0x", dev_port);
		int hellosendsize = send(handle, hellomsg, strlen(hellomsg), 0);
		if (hellosendsize != strlen(hellomsg)) {
			printf("hello message send error!\n");
			
				
			exit(EXIT_FAILURE);
			
			continue;
		}

		
		// Create socket information
		struct connection* connection1;
		struct connection* connection2;
		
		connection1 = malloc(sizeof(struct connection));
		if (! connection1) {
			exit(EXIT_FAILURE);
		}
		connection2 = malloc(sizeof(struct connection));    
		if (! connection2) {
			exit(EXIT_FAILURE);
		}
		
		connection1->srv_sock = new_ssock;
		connection1->cli_sock = handle;
		connection2->srv_sock = new_ssock;
		connection2->cli_sock = handle;
		
		
		printf("sock handle newsock:%d iphone:%d\n", new_ssock, handle);
		fflush(stdout);
		
		// Create transfer thread
		
		int lpThreadId;
		int lpThreadId2;
		pthread_t thread1;
		pthread_t thread2;
		
		lpThreadId = pthread_create(&thread1, NULL, (void*)transfer_dev_to_srv, (void*)connection1);
		lpThreadId2 = pthread_create(&thread2, NULL, (void*)transfer_srv_to_dev, (void*)connection2);
		
		pthread_detach(thread2);
		pthread_detach(thread1);
	}
	
	
}

int main (int argc, const char * argv[]) {
	
	
	if ( !(argc >= 3 && argc <= 4))
	{
		printf("\nTHIS IS ALPHA VERSION\n");
		printf("\niphone_tunnel v3.0 for Mac\n");
		printf("Created by novi. (novi.mad<at>gmail.com)\n");
		printf("\nusage: iphone_tunnel <iPhone port> <Local port> (Device ID, 40 digit)\n");
		printf("example: iphone_tunnel 22 9876 0123456...abcdef\n");
		return 0;
	}
	int devport, srvport;
	
	sscanf(argv[1], "%d", &devport);
	sscanf(argv[2], "%d", &srvport);
	
	dev_port = devport;
	srv_port = srvport;
	
	if (dev_port == 0 || srv_port == 0) {
		printf("invalid port!\n");
		exit(EXIT_FAILURE);
	}
	
	printf("devport %d, srvport %d\n", dev_port, srv_port);
	
	// Create socket for server
	struct sockaddr_in saddr;
	memset(&saddr, 0, sizeof saddr);
	saddr.sin_family = AF_INET;
	saddr.sin_addr.s_addr = INADDR_ANY;
	saddr.sin_port = htons(srv_port);     
	ssock = socket(AF_INET, SOCK_STREAM, 0);
	
	if (-1 == ssock) {
		printf("socket create failed\n");
		exit(-1);
	}
	
	// Set option to avoid bind error
	// http://homepage3.nifty.com/owl_h0h0/unix/job/UNIX/network/socket.html
	int temp = 1;
	if(setsockopt(ssock, SOL_SOCKET, SO_REUSEADDR, &temp, sizeof(temp))) {
		fprintf(stderr, "setsockopt() failed");
	}
	
	// Bind
	int ret = bind(ssock, (struct sockaddr*)&saddr, sizeof(struct sockaddr));
	if (0 != ret) {
		printf("bind error!\n", ret);
		exit(-2);
	}
	
	// Send request for connection
	listen(ssock, 0);
	
	
	
		struct am_device_notification *notif; 
		ret = AMDeviceNotificationSubscribe(notification, 0, 0, 0, &notif);
		if (ret != ERR_SUCCESS) {
			printf("AMDeviceNotificationSubscribe = %i\n", ret);
			exit(EXIT_FAILURE);
		}
		
		CFRunLoopRun();
		printf("RUN LOOP EXIT\n");
		
		
    
    return 0;
}

