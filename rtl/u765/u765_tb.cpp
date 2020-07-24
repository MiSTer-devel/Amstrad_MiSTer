#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>
#include "Vu765_test.h"
#include "verilated.h"
#include "verilated_vcd_c.h"


static Vu765_test *tb;
static VerilatedVcdC *trace;
static int tickcount;

static unsigned char sdbuf[512];
static FILE *edsk;
static int reading;
static int read_ptr;

int img_read(int sd_rd) {
	if (!sd_rd) return 0;
	printf("img_read: %02x lba: %d\n", sd_rd, tb->sd_lba);
	int lba = tb->sd_lba;
	fseek(edsk, lba << 9, SEEK_SET);
	fread(&sdbuf, 512, 1, edsk);
	reading = 1;
	read_ptr = 0;
}

void tick(int c) {
	int sd_rd, sd_wr;

	tb->clk_sys = c;
	tb->eval();
	trace->dump(tickcount++);

	if (c) {
		if (reading) {
			tb->sd_ack = 1;
			tb->sd_buff_wr = 1;
			tb->sd_buff_dout = sdbuf[read_ptr];
			tb->sd_buff_addr = read_ptr;
			read_ptr++;
			if (read_ptr == 512) reading = 0;
		} else {
			tb->sd_ack = 0;
			tb->sd_buff_wr = 0;
		}

		if (sd_rd != tb->sd_rd) img_read(tb->sd_rd);
		sd_rd = tb->sd_rd;
	}
}

void wait (int t) {
	for (int i=0; i<t; i++) {
		tick(1);
		tick(0);
	}
}

int readstatus() {
	int dout;

	tb->a0 = 0;
	tick(1);
	tick(0);
	tb->nRD = 0;
	tb->nWR = 1;
	tick(1);
	tick(0);
	tick(1);
	tick(0);
	dout = tb->dout;
	tb->nRD = 1;
	tick(1);
	tick(0);
	//printf("READ STATUS = 0x%02x\n", dout);
	return dout;
}

void sendbyte(int byte) {
	while ((readstatus() & 0xcf) != 0x80) {};
	tb->a0 = 1;
	tick(1);
	tick(0);
	tb->nRD = 1;
	tb->nWR = 0;
	tb->din = byte;
	tick(1);
	tick(0);
	tick(1);
	tick(0);
	tb->nWR = 1;
	tick(1);
	tick(0);
}

int readbyte() {
	int byte;

	while ((readstatus() & 0xcf) != 0xc0) {};
	tb->a0 = 1;
	tick(1);
	tick(0);
	tb->nRD = 0;
	tb->nWR = 1;
	tick(1);
	tick(0);
	tick(1);
	tick(0);
	byte = tb->dout;
	tb->nRD = 1;
	tick(1);
	tick(0);
	return byte;
}

void read_result() {
	printf("--- COMMAND RESULT ----\n");
	printf("ST0 = 0x%02x\n", readbyte());
	printf("ST1 = 0x%02x\n", readbyte());
	printf("ST2 = 0x%02x\n", readbyte());
	printf("C   = 0x%02x\n", readbyte());
	printf("H   = 0x%02x\n", readbyte());
	printf("R   = 0x%02x\n", readbyte());
	printf("N   = 0x%02x\n", readbyte());
}

void read_data() {
	int status, byte;
	int offs=0;
	long chksum=0;

	while(true) {
		while (((status=readstatus()) & 0xcf) != 0xc0) {};
		if ((status & 0x20) != 0x20) {
			printf("Data sum: %ld\n", chksum);
			return;
		}
		tb->a0 = 1;
		tb->nRD = 0;
		tb->nWR = 1;
		tick(1);
		tick(0);
		tick(1);
		tick(0);
		byte = tb->dout;
		tb->nRD = 1;
		tick(1);
		tick(0);
		chksum += byte;
//		printf("%02x ", byte);
//		offs++;
//		if ((offs%16)==0) printf("\n %03x ", offs);
	}
}

void cmd_recalibrate() {
	printf("=== RECALIBRATE ===\n");
	sendbyte(0x07);
	sendbyte(0x00);
}

void cmd_seek(int ncn) {
	printf("=== SEEK ===\n");
	sendbyte(0x0f);
	sendbyte(0x00);
	sendbyte(ncn);
}

void cmd_read_id(int head) {
	printf("=== READ ID ===\n");
	sendbyte(0x0a);
	sendbyte(head << 2);
	read_result();
}

void cmd_read(int c,int h,int r,int n,int eot,int gpl,int dtl) {
	printf("=== READ ===\n");
	sendbyte(0x06);
	sendbyte(h << 2);
	sendbyte(c);
	sendbyte(h);
	sendbyte(r);
	sendbyte(n);
	sendbyte(eot);
	sendbyte(gpl);
	sendbyte(dtl);

	read_data();

	read_result();
}

void mount(FILE *edsk, int dno) {
	int fsize;

	fseek(edsk, 0, SEEK_END);
	fsize = ftell(edsk);
	tb->img_size = fsize;
	tb->img_mounted = 1<<dno;
	tick(1);
	tick(0);
	tb->img_mounted = 0;
	wait(1000);
}


int main(int argc, char **argv) {

	// Initialize test disk
	edsk=fopen("test.dsk", "rb");
	if (!edsk) {
		printf("Cannot open test.dsk.\n");
		return(-1);
	}

	// Initialize Verilators variables
	Verilated::commandArgs(argc, argv);
//	Verilated::debug(1);
	Verilated::traceEverOn(true);
	trace = new VerilatedVcdC;
	tickcount = 0;

	// Create an instance of our module under test
	tb = new Vu765_test;
	tb->trace(trace, 99);
	trace->open("u765.vcd");

	tb->reset = 1;
	tb->ce = 1;
	tb->nWR = 1;
	tb->nRD = 1;
	tick(1);
	tick(0);

	tick(1);
	tick(0);
	tick(1);
	tick(0);
	tb->reset = 0;

	reading = 0;
	mount(edsk, 0);

	tb->motor = 1;
	tb->ready = 1;
	tb->available = 1;

	wait(100000);

	cmd_recalibrate();
	wait(1000);
	cmd_read(0,0,0x41,2,0xff,2,0xff);
	cmd_seek(1);
	wait(1000);
	cmd_read(1,0,0,5,0xff,2,0xff);
	cmd_read(1,0,0x1d,2,0xff,2,0xff);
	cmd_read(1,0,0xff,0,0xff,2,1);

	for (int i=0;i<10;i++) {
		cmd_read_id(0);
		wait(1000);
	}

	fclose(edsk);
	trace->close();
}
