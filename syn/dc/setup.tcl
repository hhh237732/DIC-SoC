# ================================================================
# setup.tcl - DC environment setup
# Author: hhh237732
# ================================================================

# Paths
set RTL_DIR ../../rtl
set SYN_DIR [pwd]

# Target library (update for your PDK)
set target_library  [list your_stdcell_tt_0p9v_25c.db]
set link_library    [list * your_stdcell_tt_0p9v_25c.db]

# Search path
set search_path [list . ${RTL_DIR} ${RTL_DIR}/cache ${RTL_DIR}/mmio ${RTL_DIR}/intc]

# Synthesis effort
set_app_var compile_ultra_effort high

echo "Setup complete. RTL_DIR = ${RTL_DIR}"
