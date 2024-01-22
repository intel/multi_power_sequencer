#Initialize signals
force -freeze sim:/sequencer_qsys_tb/pmbus_scl 1 0
force -freeze sim:/sequencer_qsys_tb/pmbus_sda 1 0

# PLL's control interface must be driven inactive
force -freeze sim:/sequencer_qsys_tb/qsys_0/pll_main/read 1'h0 0
force -freeze sim:/sequencer_qsys_tb/qsys_0/pll_main/write 1'h0 0
force -freeze sim:/sequencer_qsys_tb/qsys_0/pll_main/writedata 32'h00000000 0

run 800 us