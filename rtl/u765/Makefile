OBJ_DIR=obj_dir
VERILATOR_DIR=/usr/local/share/verilator/include
#VERILATOR_DIR=/usr/share/verilator/include
VERILATOR_BIN=/usr/local/bin/verilator
#VERILATOR_BIN=/usr/bin/verilator
#VERILATOR_DIR=${HOME}/verilator/include
#VERILATOR_BIN=${HOME}/verilator/bin/verilator
HDL_FILES = u765_test.sv u765.sv

all: u765_tb

Vu765_tb.cpp: ${OBJ_DIR}/Vu765_tb.cpp


${OBJ_DIR}/Vu765_tb.cpp: ${HDL_FILES}
	${VERILATOR_BIN} --trace --top-module u765_test -cc ${HDL_FILES}

u765_tb: ${OBJ_DIR}/Vu765_tb.cpp u765_tb.cpp
	g++ -I $(OBJ_DIR) -I$(VERILATOR_DIR) $(VERILATOR_DIR)/verilated.cpp $(VERILATOR_DIR)/verilated_vcd_c.cpp u765_tb.cpp  $(OBJ_DIR)/Vu765_test__Trace.cpp $(OBJ_DIR)/Vu765_test__Trace__Slow.cpp $(OBJ_DIR)/Vu765_test.cpp $(OBJ_DIR)/Vu765_test__Syms.cpp -DOPT=-DVL_DEBUG -o u765_tb

