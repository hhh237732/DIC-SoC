##############################################################
# tb/Makefile - SoC testbench build and simulation
# Simulator: iverilog + vvp  (SystemVerilog: -g2012)
##############################################################

RTL_DIR  := ../rtl
TB_DIR   := .

IVFLAGS  := -g2012 \
            -I $(RTL_DIR) \
            -I $(RTL_DIR)/cache \
            -I $(RTL_DIR)/mmio \
            -I $(RTL_DIR)/intc

RTL_SRCS := \
  $(RTL_DIR)/l1_icache.v \
  $(RTL_DIR)/l1_dcache.v \
  $(RTL_DIR)/l2_cache.v \
  $(RTL_DIR)/cache/l2_arbiter.v \
  $(RTL_DIR)/dma_ctrl.v \
  $(RTL_DIR)/dma_regfile.v \
  $(RTL_DIR)/dma_master.v \
  $(RTL_DIR)/dma_intr.v \
  $(RTL_DIR)/sync_fifo.v \
  $(RTL_DIR)/main_mem.v \
  $(RTL_DIR)/axi4_interconnect.v \
  $(RTL_DIR)/mmio/mmio_regfile.v \
  $(RTL_DIR)/intc/plic_lite.v \
  $(RTL_DIR)/soc_top.v

.PHONY: all soc_top l1_dcache l2_cache dma_engine clean

all: soc_top l1_dcache l2_cache dma_engine

# ---- SoC end-to-end (uses legacy .v tb) ----
soc_top: sim_soc_top
	vvp sim_soc_top

sim_soc_top: $(RTL_SRCS) $(TB_DIR)/tb_soc_top.sv
	iverilog $(IVFLAGS) -o $@ $^

# ---- L1 DCache unit ----
l1_dcache: sim_l1_dcache
	vvp sim_l1_dcache

sim_l1_dcache: $(RTL_DIR)/l1_dcache.v $(TB_DIR)/tb_l1_dcache.sv
	iverilog $(IVFLAGS) -o $@ $^

# ---- L2 Cache unit ----
l2_cache: sim_l2_cache
	vvp sim_l2_cache

sim_l2_cache: $(RTL_DIR)/l2_cache.v $(TB_DIR)/tb_l2_cache.sv
	iverilog $(IVFLAGS) -o $@ $^

# ---- DMA engine unit ----
dma_engine: sim_dma_engine
	vvp sim_dma_engine

sim_dma_engine: \
  $(RTL_DIR)/dma_ctrl.v \
  $(RTL_DIR)/dma_regfile.v \
  $(RTL_DIR)/dma_master.v \
  $(RTL_DIR)/dma_intr.v \
  $(RTL_DIR)/sync_fifo.v \
  $(TB_DIR)/tb_dma_engine.sv
	iverilog $(IVFLAGS) -o $@ $^

clean:
	rm -f sim_soc_top sim_l1_dcache sim_l2_cache sim_dma_engine *.vcd
