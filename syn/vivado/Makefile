# ================================================================
# Makefile - Xilinx Vivado synthesis + implementation
# Author: hhh237732
# Usage: make syn | make impl | make bit | make clean
# ================================================================

VIVADO    ?= vivado
LOG_FILE   = vivado.log
JOU_FILE   = vivado.jou

.PHONY: syn impl bit clean

syn impl bit:
	$(VIVADO) -mode batch -source run_vivado.tcl \
	    -log $(LOG_FILE) -journal $(JOU_FILE)

clean:
	rm -f $(LOG_FILE) $(JOU_FILE)
	rm -rf reports/*.rpt reports/*.bit
	rm -rf .Xil vivado_pid*.str
