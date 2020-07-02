OBJ_DIR=obj_dir
VERILATOR_DIR=/usr/local/share/verilator/include
VERILATOR_DIR=/usr/share/verilator/include
VERILATOR_BIN=/usr/local/bin/verilator
VERILATOR_BIN=/usr/bin/verilator
#VERILATOR_DIR=${HOME}/verilator/include
#VERILATOR_BIN=${HOME}/verilator/bin/verilator
HDL_FILES = ga40010_test.v ga40010.sv syncgen.v syncgen_sync.v casgen.v video.sv rslatch.v ../UM6845R.v

all: ga40010_tb

Vga40010_tb.cpp: ${OBJ_DIR}/Vg40010_tb.cpp


${OBJ_DIR}/Vga40010_tb.cpp: ${HDL_FILES}
	${VERILATOR_BIN} --trace --top-module ga40010_test -cc ${HDL_FILES}

ga40010_tb: ${OBJ_DIR}/Vga40010_tb.cpp ga40010_tb.cpp
	g++ -I $(OBJ_DIR) -I$(VERILATOR_DIR) $(VERILATOR_DIR)/verilated.cpp $(VERILATOR_DIR)/verilated_vcd_c.cpp ga40010_tb.cpp  $(OBJ_DIR)/Vga40010_test__Trace.cpp $(OBJ_DIR)/Vga40010_test__Trace__Slow.cpp $(OBJ_DIR)/Vga40010_test.cpp $(OBJ_DIR)/Vga40010_test__Syms.cpp -DOPT=-DVL_DEBUG -o ga40010_tb

video: video.png

video.png: video.rgb
	rm -f video.png
	ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb444 -s 1024x312 -i video.rgb -f image2 -vcodec png video.png
	display video.png
