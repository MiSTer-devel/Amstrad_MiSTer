#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>
#include "Vga40010_test.h"
#include "verilated.h"
#include "verilated_vcd_c.h"


static Vga40010_test *tb;
static VerilatedVcdC *trace;
static int tickcount;
static int phase;

static unsigned char ram[64*1024];

void initram() {
	FILE *file=fopen("cpcram.bin", "rb");
	fread(&ram, 64, 1024, file);
	fclose(file);
}

void tick(int c) {
	static char cas_old;
	static char bs;

	tb->clk = c;
	tb->eval();
	trace->dump(tickcount++);

	// VRAM read
	if (!tb->CPU_N) bs = 0;
	if (c && !tb->RAS_N && tb->CPU_N) {
		if (!cas_old && tb->CAS_N) bs = 1-bs;
		if (!tb->CAS_N) tb->RAM_DIN = ram[(tb->VRAM_ADDR << 1) + bs];
	}
	if (!c) cas_old = tb->CAS_N;
}

void check_int(int sync) {
	static int int_steps = 0;
	if (!tb->INT_N && !int_steps) int_steps = 50;
	if (int_steps == 20) {
		// ack
		tb->M1_N = 0;
		tb->IORQ_N = 0;
	}
	if (int_steps == 1) {
		//acked
		tb->M1_N = 1;
		tb->IORQ_N = 1;
	}
	if (int_steps > 0 && sync) int_steps--;
}

void write(int addr, char data, bool io) {
	//T1
	while (!tb->PHI_N) {
		tick(1);
		tick(0);
	}
	tb->A = addr & 0xffff;
	while (tb->PHI_N) {
		tick(1);
		tick(0);
	}
	tb->CPU_DIN = data;
	if (!io) tb->MREQ_N = 0;
	//T2
	while (!tb->PHI_N) {
		tick(1);
		tick(0);
	}
	if (io) tb->IORQ_N = 0;
	tb->WR_N = 0;
	while ((!io && !tb->READY) || tb->PHI_N) {
		tick(1);
		tick(0);
	}
	//TW
	if (io) {
		while (!tb->READY || !tb->PHI_N) {
			tick(1);
			tick(0);
		}
		while (tb->PHI_N) {
			tick(1);
			tick(0);
		}
	}
	//T3
	while (!tb->PHI_N) {
		tick(1);
		tick(0);
	}
	while (tb->PHI_N) {
		tick(1);
		tick(0);
	}
	tb->IORQ_N = 1;
	tb->MREQ_N = 1;
	tb->WR_N = 1;
}

void write_crtc(int reg, int val) {
	write(0xbc00, reg, true);
	write(0xbd00, val, true);
}

void write_pen(int pen, int val) {
	write(0x7fff, pen, true); //select pen 1
	write(0x7fff, 0x40 | val, true); //write color 0x14
}

int main(int argc, char **argv) {

	int frames = 0;
	int steps = 250;
	int line_steps = 4000;
	int hsync_len = 600;
	int vsync_steps = 80;
	int hsync,vsync;
	int mode;

	// Initialize Verilators variables
	Verilated::commandArgs(argc, argv);
//	Verilated::debug(1);
	Verilated::traceEverOn(true);
	trace = new VerilatedVcdC;
	tickcount = 0;
	phase = 0;

	// Initialize RAM
	initram();

	// Create an instance of our module under test
	tb = new Vga40010_test;
	tb->trace(trace, 99);
	trace->open("ga40010.vcd");

	tb->RESET_N = 0;
	tick(1);
	tick(0);

	tb->M1_N = 1;
	tb->IORQ_N = 1;
	tb->RD_N = 1;
	tb->MREQ_N = 1;

	tick(1);
	tick(0);
	tick(1);
	tick(0);
	tb->RESET_N = 1;

	// GA setup
	write_pen(0,0x04);
	write_pen(1,0x0a);
	write_pen(2,0x13);
	write_pen(3,0x0c);
	write_pen(4,0x0b);
	write_pen(5,0x14);
	write_pen(6,0x15);
	write_pen(7,0x0d);
	write_pen(8,0x06);
	write_pen(9,0x1e);
	write_pen(10,0x1f);
	write_pen(11,0x07);
	write_pen(12,0x12);
	write_pen(13,0x19);
	write_pen(14,0x0a);
	write_pen(15,0x07);
	write_pen(16,0x5c); //border

	write(0x7fff, 0x81, true); // Mode 1

	// CRTC setup
	write_crtc(0,63);
	write_crtc(1,40);
	write_crtc(2,46);
	write_crtc(3,128+14);
//	write_crtc(3,128+2);
	write_crtc(4,38);
	write_crtc(5,0);
	write_crtc(6,25);
	write_crtc(7,30);
	write_crtc(8,0);
	write_crtc(9,7);
	write_crtc(10,0);
	write_crtc(11,0);
	write_crtc(12,48);
	write_crtc(13,0);

	write(0xaaaa, 0xaa, false); // memory write test

	FILE *file=fopen("video.rgb", "wb");
	unsigned short rgb;

	mode = 0x8e;

	while(frames<5) {
		vsync = tb->VSYNC;
		hsync = tb->HSYNC;
		tick(1);
		check_int(tb->HSYNC);
		tick(0);

		// mode switch/scanline test (creates 1002x312 image - border is zigzagged)
#if 0
		if (!hsync && tb->HSYNC) {
			mode = mode ^ 0x02;
			write(0x77ff, mode, true);
		};
#endif
		if (!tb->VSYNC && vsync) {
			frames++;
//			write_crtc(3,128+2+frames);
		}
		if (frames == 3 && tb->CEN_16) {
			if (tb->VSYNC) rgb = 0x00f0;
			else if (tb->HSYNC) rgb = 0x0f00;
			else rgb = tb->RED*15*256 + tb->RED_OE_N*8*256 + tb->GREEN*15*16 + tb->GREEN_OE_N*8*16 + tb->BLUE*15 + tb->BLUE_OE_N*8;
			fwrite(&rgb, 1, sizeof(rgb), file);
		};
	};

	fclose(file);
	trace->close();
}
