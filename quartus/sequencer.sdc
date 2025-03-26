## Generated SDC file "sequencer.sdc"

## Copyright (C) 2017  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel MegaCore Function License Agreement, or other 
## applicable license agreement, including, without limitation, 
## that your use is for the sole purpose of programming logic 
## devices manufactured by Intel and sold by Intel or its 
## authorized distributors.  Please refer to the applicable 
## agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition"

## DATE    "Tue Dec 05 12:33:03 2017"

##
## DEVICE  "10M02DCU324A6G"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name clk_ref -period 50.0MHz [get_ports {clk}]


#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks
derive_clock_uncertainty
# Constrain the clock divider on the internal flash, if it's instantiated
if {[get_collection_size [get_registers *avmm_data_controller|flash_se_neg_reg -nowarn]] != 0} {
  create_generated_clock -name flash_se_neg_reg -divide_by 2 \
    -source [get_pins -compatibility_mode { *avmm_data_controller|flash_se_neg_reg|clk }] \
    [get_pins -compatibility_mode { *avmm_data_controller|flash_se_neg_reg|q } ]
}


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

