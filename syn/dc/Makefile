# ================================================================
# Makefile - Synopsys DC synthesis
# Author: hhh237732
# Usage: make syn | make clean
# ================================================================

DC_SHELL  ?= dc_shell
LOG_FILE   = dc_syn.log

.PHONY: syn clean

syn:
	$(DC_SHELL) -f run_dc.tcl | tee $(LOG_FILE)

clean:
	rm -f $(LOG_FILE)
	rm -rf reports/*.rpt reports/*_netlist.v reports/*.sdc
	rm -rf work WORK *.mr command.log default.svf
