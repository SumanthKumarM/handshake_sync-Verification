CC              = gcc
CFLAGS		= -Wall -O3 -fPIC
SEED            = 1

DFLAGS = -relocation-model=pic -w

LDC2BINDIR = $(dir $(shell which ldc2))
VLBINDIR = $(dir $(shell which verilator))
VERBOSITY = UVM_DEBUG

VLATOR_SRC = euvm_dir/Vhandshake_sync_euvm.d euvm_dir/Vhandshake_sync_euvm_funcs.cpp obj_dir/Vhandshake_sync.cpp obj_dir/Vhandshake_sync.h

all: handshake_sync

clean:
	rm -rf handshake_sync* euvm_dir obj_dir verilator.stamp

run: handshake_sync
	./handshake_sync +UVM_TESTNAME=handshake_sync.hs_test +UVM_VERBOSITY=$(VERBOSITY) +random_seed=$(SEED) # +UVM_OBJECTION_TRACE

verilator.stamp: ../rtl/handshake_sync.v
	touch verilator.stamp
	verilator --threads 1 --trace --cc --euvm $^
	(cd euvm_dir; g++ -c -I ../obj_dir/ -I $(VLBINDIR)/../share/verilator/include Vhandshake_sync_euvm_funcs.cpp)
	(cd euvm_dir; g++ -c -I ../obj_dir/ -I $(VLBINDIR)/../share/verilator/include $(LDC2BINDIR)/../import/esdl/intf/verilator/cpp/verilated_vcd_d.cpp -o verilated_vcd_d.o)
	(cd euvm_dir; g++ -c -I ../obj_dir/ -I $(VLBINDIR)/../share/verilator/include $(LDC2BINDIR)/../import/esdl/intf/verilator/cpp/verilated_d.cpp -o verilated_d.o)
	(cd obj_dir; make -f Vhandshake_sync.mk Vhandshake_sync__ALL.a verilated.o verilated_vcd_c.o verilated_threads.o)

euvm_dir/Vhandshake_sync_euvm.d euvm_dir/Vhandshake_sync_euvm_funcs.o euvm_dir/verilated_vcd_d.o obj_dir/Vhandshake_sync__ALL.a obj_dir/verilated.o: verilator.stamp


handshake_sync: ../testbench/handshake_sync.d euvm_dir/Vhandshake_sync_euvm.d  \
	   $(LDC2BINDIR)/../import/esdl/intf/verilator/trace.d \
	   euvm_dir/verilated_vcd_d.o euvm_dir/verilated_d.o \
	   euvm_dir/Vhandshake_sync_euvm_funcs.o  \
	   obj_dir/Vhandshake_sync__ALL.a \
	   obj_dir/verilated.o  obj_dir/verilated_threads.o obj_dir/verilated_vcd_c.o \
	   obj_dir/verilated_threads.o
	ldc2 $(DFLAGS) -Ieuvm_dir -link-defaultlib-shared -of$@ -L-luvm-ldc-shared -L-lesdl-ldc-shared -L-lz3 \
		-L-lphobos2-ldc-shared -L-ldl $^ -L-lstdc++
