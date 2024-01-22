# TCL File Generated by Component Editor 18.0
# Tue Oct 02 20:23:12 CDT 2018
# DO NOT MODIFY


# 
# sequencer_top "Power Sequencer" v1.0
#  2018.10.02.20:23:12
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module sequencer_top
# 
set_module_property DESCRIPTION ""
set_module_property NAME sequencer_top
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME "Power Sequencer"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property ELABORATION_CALLBACK elaborate


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH generate
add_fileset SIM_VERILOG SIM_VERILOG generate
add_fileset SIM_VHDL SIM_VHDL generate
set_fileset_property QUARTUS_SYNTH TOP_LEVEL sequencer_top
set_fileset_property SIM_VERILOG TOP_LEVEL sequencer_top
set_fileset_property SIM_VHDL TOP_LEVEL sequencer_top


# 
# parameters
# 

add_parameter VRAILS INTEGER 4
set_parameter_property VRAILS DEFAULT_VALUE 4
set_parameter_property VRAILS DISPLAY_NAME "Output Voltage Rails"
set_parameter_property VRAILS DESCRIPTION "The number of output voltage rails being sequenced."
set_parameter_property VRAILS TYPE INTEGER
set_parameter_property VRAILS UNITS None
set_parameter_property VRAILS ALLOWED_RANGES 0:143
set_parameter_property VRAILS HDL_PARAMETER true

add_parameter USE_PWR_GROUPS BOOLEAN false
set_parameter_property USE_PWR_GROUPS DISPLAY_NAME "Combine rails into groups"
set_parameter_property USE_PWR_GROUPS DESCRIPTION "Group power rails with common enable signals, monitoring their status as a whole.  The power good status signals from all rails within the group are combined, to affect the enable signal."
set_parameter_update_callback USE_PWR_GROUPS param_adj_table_grps

add_parameter G_PWR_GROUPS INTEGER 1
set_parameter_property G_PWR_GROUPS DISPLAY_NAME "Number of Power Groups"
set_parameter_property G_PWR_GROUPS DESCRIPTION "Number of power groups implemented by the sequencer.  There will be one set of enable/discharge outputs per group."
set_parameter_property G_PWR_GROUPS HDL_PARAMETER false
set_parameter_property G_PWR_GROUPS VISIBLE false

add_parameter PWR_GROUPS INTEGER 1
set_parameter_property PWR_GROUPS DERIVED true
set_parameter_property PWR_GROUPS HDL_PARAMETER true
set_parameter_property PWR_GROUPS VISIBLE false

# Read the frequency of the input clock (in Hertz)
add_parameter CLOCK_RATE_CLK INTEGER 0
set_parameter_property CLOCK_RATE_CLK DISPLAY_NAME "Component's Clock Frequency"
set_parameter_property CLOCK_RATE_CLK DISPLAY_UNITS "Hz"
set_parameter_property CLOCK_RATE_CLK SYSTEM_INFO {CLOCK_RATE clock}
set_parameter_property CLOCK_RATE_CLK VISIBLE false

# Read the frequency of the input clock (in MHz)
add_parameter DV_CLOCK_RATE_CLK INTEGER 0
set_parameter_property DV_CLOCK_RATE_CLK DISPLAY_NAME "Component's Clock Frequency"
set_parameter_property DV_CLOCK_RATE_CLK DESCRIPTION "Input clock frequency.  This value cannot be calculated when the input clock rate is unknown or unconnected to a clock signal."
set_parameter_property DV_CLOCK_RATE_CLK DISPLAY_UNITS "MHz"
set_parameter_property DV_CLOCK_RATE_CLK DERIVED true

add_parameter DV_CLKPERIOD INTEGER 0
set_parameter_property DV_CLKPERIOD DISPLAY_NAME "Reference Clock Period"
set_parameter_property DV_CLKPERIOD DISPLAY_UNITS "ns"
set_parameter_property DV_CLKPERIOD DESCRIPTION "Clock period for the reference clock to the sequencer.  Units are specified in ns."
set_parameter_property DV_CLKPERIOD DERIVED true
set_parameter_property DV_CLKPERIOD VISIBLE false

# Enable selection of open-drain or standard push-pull drivers
add_parameter T_USE_OPEN_DRAIN BOOLEAN true
set_parameter_property T_USE_OPEN_DRAIN DISPLAY_NAME "Use open-drain outputs"
set_parameter_property T_USE_OPEN_DRAIN DESCRIPTION "Controls whether open-drain or push-pull drivers are used for nFAULT, VRAIL_ENA, and VRAIL_DCHG."
add_parameter USE_OPEN_DRAIN INTEGER 1
set_parameter_property USE_OPEN_DRAIN TYPE INTEGER
set_parameter_property USE_OPEN_DRAIN DERIVED true
set_parameter_property USE_OPEN_DRAIN HDL_PARAMETER true
set_parameter_property USE_OPEN_DRAIN VISIBLE false

# Parameters relating to the VOUT output rails - loop through the number of rails and create a tab for each one
add_parameter VOUT_NAME STRING_LIST
set_parameter_property VOUT_NAME DISPLAY_NAME "Voltage Rail"
set_parameter_property VOUT_NAME AFFECTS_ELABORATION true
set_parameter_property VOUT_NAME HDL_PARAMETER false
set_parameter_property VOUT_NAME DERIVED true
set_parameter_property VOUT_NAME DISPLAY_HINT FIXED_SIZE
set_parameter_property VOUT_NAME DISPLAY_HINT WIDTH:75

# Initialize the table of entries for Sequencer Delay, Qualification Window, and Discharge Delay
set seqdly_list_init ""
set seqqual_list_init ""
set seqdchc_list_init ""
set pwrgrp_list_init ""
for { set i 0 } { $i < 143 } { incr i } {   
  lappend seqdly_list_init "1ms"
  lappend seqqual_list_init "10ms"
  lappend seqdchc_list_init "0us"
  lappend pwrgrp_list_init $i
}

add_parameter SEQDLY STRING_LIST $seqdly_list_init
set_parameter_property SEQDLY DISPLAY_NAME "Sequencer Delay (PG to next OE)"
set_parameter_property SEQDLY DESCRIPTION "Defines the delay from when the master enable is asserted before output enable is asserted, or from when power good is asserted until the next rail's output enable is asserted.  A value of \"0ns\" will bypass this delay.  Units can be specified as s, ms, us, and ns (e.g. 10ms)."
set_parameter_property SEQDLY DISPLAY_HINT FIXED_SIZE
set_parameter_property SEQDLY DISPLAY_HINT WIDTH:175

add_parameter QUALTIME STRING_LIST $seqqual_list_init
set_parameter_property QUALTIME DISPLAY_NAME "Qualification Window (OE to PG)"
set_parameter_property QUALTIME DESCRIPTION "Defines the qualification window for which power good must be asserted, after output enable is asserted.  If this time is violated, a fault will be indicated and the power rails will sequence down in reverse order.  Units can be specified as s, ms, us, and ns (e.g. 10ms)."
set_parameter_property QUALTIME DISPLAY_HINT FIXED_SIZE
set_parameter_property QUALTIME DISPLAY_HINT WIDTH:175

add_parameter DCHGDLY STRING_LIST $seqdchc_list_init
set_parameter_property DCHGDLY DISPLAY_NAME "Discharge Delay (!PG to DCHG)"
set_parameter_property DCHGDLY DESCRIPTION "Defines the delay that the sequence will wait while sequencing *down*, after power good is deasserted, to allow the rail to gracefully discharge before forcing it.  A value of \"0ns\" will assert the discharge output immediately after power good is deasserted.  Units can be specified as s, ms, us, and ns (e.g. 10ms)."
set_parameter_property DCHGDLY DISPLAY_HINT FIXED_SIZE
set_parameter_property DCHGDLY DISPLAY_HINT WIDTH:175
set_parameter_property DCHGDLY VISIBLE false

add_parameter PWR_GROUP_NUM INTEGER_LIST $pwrgrp_list_init
set_parameter_property PWR_GROUP_NUM DISPLAY_NAME "Power Group Number"
set_parameter_property PWR_GROUP_NUM DESCRIPTION "Defines which power group number (starting from '0') the rail belongs to.  All rails with the same group number should use the same enable/discharge signal, and their \"Power Good\" signals will be evaluated (ANDed) together."
set_parameter_property PWR_GROUP_NUM DISPLAY_HINT FIXED_SIZE
set_parameter_property PWR_GROUP_NUM DISPLAY_HINT WIDTH:125

# Create global parameters that can be read by the parameter callback, since I couldn't seem to pass more than one
#   argument...
add_parameter PWR_GROUP_INIT INTEGER_LIST $pwrgrp_list_init
set_parameter_property PWR_GROUP_INIT DERIVED true
set_parameter_property PWR_GROUP_INIT VISIBLE false
#
add_parameter PWR_GROUP_LASTNUM INTEGER_LIST PWR_GROUP_NUM
set_parameter_property PWR_GROUP_LASTNUM DERIVED true
set_parameter_property PWR_GROUP_LASTNUM VISIBLE false

add_display_item "Sequencer Setup" id0 text "<html><dl>
<dt>Sequencer Delay (PG to next OE):</dt>
<dd>Defines the delay from when the master enable is asserted to when the first rail's output enable <br>
is asserted, or from when power good is asserted until the next rail's output enable is asserted.  A <br>
value of \"0ns\" will bypass this delay.  Units can be specified as s, ms, us, and ns (e.g. 1ms).<br/><br/></dd>
<dt>Qualification Window (OE to PG):</dt>
<dd>Defines the qualification window for which power good must be asserted, after output enable <br>
is asserted.  If this time is violated, a fault will be indicated and the power rails will  <br>
sequence down in reverse order.  Units can be specified as s, ms, us, and ns (e.g. 10ms).<br/><br/></dd>
<dt>Power Group Number:</dt>
<dd>Defines which power group number (starting from '0') the rail belongs to.  All rails with the<br>
same group number should use the same enable/discharge signal, and the \"Power Good\" <br>
signals will be evaluated (ANDed) together.</dd>
</dl>"
add_display_item "Sequencer Setup" myTableGrp GROUP TABLE
add_display_item myTableGrp VOUT_NAME PARAMETER ""
add_display_item myTableGrp SEQDLY PARAMETER ""
add_display_item myTableGrp QUALTIME PARAMETER ""
#add_display_item myTableGrp DCHGDLY PARAMETER ""
add_display_item myTableGrp PWR_GROUP_NUM PARAMETER ""

# This callback is run every time the Use Power Groups setting is toggled
proc param_adj_table_grps { arg } {
    # Power groups are being used - restore the last used list of power groups
    if {[get_parameter_value USE_PWR_GROUPS]} {
      set_parameter_property PWR_GROUP_NUM ENABLED true
      set_parameter_value PWR_GROUP_NUM [get_parameter_value PWR_GROUP_LASTNUM]
    # Power groups are not being used - disable that column in the table, and set each power group
    #   number to its VOUT number to make it clear to the user, since we can't seem remove the column.
    } else {
      set_parameter_value PWR_GROUP_LASTNUM [get_parameter_value PWR_GROUP_NUM]
      set_parameter_property PWR_GROUP_NUM ENABLED false
      set_parameter_value PWR_GROUP_NUM [get_parameter_value PWR_GROUP_INIT]
    }
}
add_parameter RESTARTDLY STRING "100ms"
set_parameter_property RESTARTDLY DISPLAY_NAME "Delay Time Between Restarts"
set_parameter_property RESTARTDLY DESCRIPTION "Define the delay interval between restart attempts for the sequencer.  Units can be specified as s, ms, us, and ns (e.g. 10ms)."
set_parameter_property RESTARTDLY DISPLAY_HINT FIXED_SIZE
set_parameter_property RESTARTDLY DISPLAY_HINT WIDTH:200

add_parameter MAXDELAY STRING "100ms"
set_parameter_property MAXDELAY DISPLAY_NAME "Maximum Specified Delay in Table Above"
set_parameter_property MAXDELAY DESCRIPTION "Define the maximum delay interval for dynamically sizing the delay counter.  This should be the largest delay from P_SEQDLY, P_QUALTIME, P_DCHGDLY, or P_RESTARTDLY.  If this is set too small, the design will not behave correctly, and incorrect \"optimizations\" to the logic will occur.  Units can be specified as s, ms, us, and ns (e.g. 10ms)."
set_parameter_property MAXDELAY DISPLAY_HINT FIXED_SIZE
set_parameter_property MAXDELAY DISPLAY_HINT WIDTH:200
set_parameter_property MAXDELAY DERIVED true

# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock CLOCK clk Input 1


# 
# connection point sequencer_control
# 
add_interface sequencer_control conduit end
set_interface_property sequencer_control associatedClock clock
set_interface_property sequencer_control associatedReset ""
set_interface_property sequencer_control ENABLED true
set_interface_property sequencer_control EXPORT_OF ""
set_interface_property sequencer_control PORT_NAME_MAP ""
set_interface_property sequencer_control CMSIS_SVD_VARIABLES ""
set_interface_property sequencer_control SVD_ADDRESS_GROUP ""

add_interface_port sequencer_control VRAIL_ENA vrail_ena Output PWR_GROUPS
add_interface_port sequencer_control VRAIL_DCHG vrail_dchg Output PWR_GROUPS


# 
# connection point sequencer_status
# 
add_interface sequencer_status conduit end
set_interface_property sequencer_status associatedClock clock
set_interface_property sequencer_status associatedReset ""
set_interface_property sequencer_status ENABLED true
set_interface_property sequencer_status EXPORT_OF ""
set_interface_property sequencer_status PORT_NAME_MAP ""
set_interface_property sequencer_status CMSIS_SVD_VARIABLES ""
set_interface_property sequencer_status SVD_ADDRESS_GROUP ""

add_interface_port sequencer_status nFAULT nfault Output 1


# 
# connection point sequencer_monitor
# 
add_interface sequencer_monitor conduit end
set_interface_property sequencer_monitor associatedClock ""
set_interface_property sequencer_monitor associatedReset ""
set_interface_property sequencer_monitor ENABLED true
set_interface_property sequencer_monitor EXPORT_OF ""
set_interface_property sequencer_monitor PORT_NAME_MAP ""
set_interface_property sequencer_monitor CMSIS_SVD_VARIABLES ""
set_interface_property sequencer_monitor SVD_ADDRESS_GROUP ""

add_interface_port sequencer_monitor ENABLE enable Input 1
add_interface_port sequencer_monitor VIN_FAULT vin_fault Input 1
add_interface_port sequencer_monitor VRAIL_PWRGD vrail_pwrgd Input VRAILS
add_interface_port sequencer_monitor VMON_ENA vmon_ena Output VRAILS
add_interface_port sequencer_monitor REG_RETRIES reg_retries Input 3
add_interface_port sequencer_monitor REG_TIMEOUTDLY reg_timeoutdly Input 3

# +----------------------------------------------------------------------------
# | Elaboration callback
# +----------------------------------------------------------------------------
proc elaborate {} {
  if {[ get_parameter_value T_USE_OPEN_DRAIN ] } {
    set_parameter_value USE_OPEN_DRAIN 1
  } else {
    set_parameter_value USE_OPEN_DRAIN 0
  }
  # Generate VOUT names
  set vout_list ""
  for { set out 0 } { $out < [ get_parameter_value VRAILS ] } { incr out } {   
      lappend vout_list "VOUT$out"
  }    
  set_parameter_value VOUT_NAME $vout_list

  set P_CLOCK_RATE_CLK     [expr ([ get_parameter_value CLOCK_RATE_CLK ] / 1000000)]
  set P_CLKPERIOD          [expr (1000000000 / [ get_parameter_value CLOCK_RATE_CLK ])]
  set_parameter_value  DV_CLOCK_RATE_CLK $P_CLOCK_RATE_CLK
  set_parameter_value  DV_CLKPERIOD $P_CLKPERIOD

  # Optionally enable the Power Groups
  if {[get_parameter_value USE_PWR_GROUPS]} {
    # Make the PWR_GROUPS parameter visible
    set_parameter_property G_PWR_GROUPS VISIBLE true
    set_parameter_value PWR_GROUPS [get_parameter_value G_PWR_GROUPS]
  } else {
    # Make the PG parameters invisible
    set_parameter_property G_PWR_GROUPS VISIBLE false
    set_parameter_value PWR_GROUPS [get_parameter_value VRAILS]
  }

  # Dynamically resize the table, based on the number of user-entered VOUT rails
  set_display_item_property myTable DISPLAY_HINT ROWS:[ get_parameter_value VRAILS ]
  set_display_item_property myTable DISPLAY_HINT fixed_size

  #+---------------------------------------------------------------------------
  # Check for out of range entries in the table
  set max_groups [get_parameter_value G_PWR_GROUPS]
  if {[get_parameter_value USE_PWR_GROUPS]} {
    if { $max_groups >= [ get_parameter_value VRAILS ] } {
      send_message {error} "The number of power groups should be less than the number of total power rails!!!"
    }
    for { set idx_vrails 0 } { $idx_vrails < [ get_parameter_value VRAILS ] } { incr idx_vrails } {
      if { [ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ] >= $max_groups } {
        send_message {error} "Power Group setting for voltage rail $idx_vrails is out of range!!!"
      }
      set cmp_delays($idx_vrails) 0
    }
    
    for { set idx_vrails [ expr [ get_parameter_value VRAILS ] - 1 ] } { $idx_vrails >= 0 } { incr idx_vrails -1} {
      if { $cmp_delays([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ]) == 1 } {
        if { ($tmp_seqdly([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ])) ne [ lindex [ get_parameter_value SEQDLY ] $idx_vrails ]} {
          send_message {warning} "Sequencer Delay setting of [ lindex [ get_parameter_value SEQDLY ] $idx_vrails ] for voltage rail $idx_vrails in group [ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ] does not match the value for the last rail in the group ($tmp_seqdly([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ]))."
        }
        if { ($tmp_qualtime([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ])) ne [ lindex [ get_parameter_value QUALTIME ] $idx_vrails ]} {
          send_message {warning} "Qualification Window setting of [ lindex [ get_parameter_value QUALTIME ] $idx_vrails ] for voltage rail $idx_vrails in group [ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ] does not match the value for the last rail in the group ($tmp_qualtime([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ]))."
        }
      } else {
        set cmp_delays([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ]) 1
        set tmp_seqdly([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ])  [ lindex [ get_parameter_value SEQDLY ] $idx_vrails ]
        set tmp_qualtime([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx_vrails ])  [ lindex [ get_parameter_value QUALTIME ] $idx_vrails ]
      }
    }
  }

  #+---------------------------------------------------------------------------
  # Determine the largest time constant for sizing the width of the sequencer's counter
  set max_value [ regsub -all {[a-z]} [ get_parameter_value RESTARTDLY ] ""]
  set max_units [ regsub -all {[0-9]} [ get_parameter_value RESTARTDLY ] ""]
  if {$max_units != "s" && $max_units != "ms" && $max_units != "us" && $max_units != "ns"} {
    send_message {error} "Invalid unit specified: $max_units!!!"
  }
  # Loop through the table of sequencer delay values
  for { set idx_vrails 0 } { $idx_vrails < [ get_parameter_value VRAILS ] } { incr idx_vrails } {
    set tmp_value [ regsub -all {[a-z]} [ lindex [ get_parameter_value SEQDLY ] $idx_vrails ] ""]
    set tmp_units [ regsub -all {[0-9]} [ lindex [ get_parameter_value SEQDLY ] $idx_vrails ] ""]
    if {$tmp_units != "s" && $tmp_units != "ms" && $tmp_units != "us" && $tmp_units != "ns"} {
      send_message {error} "Invalid unit specified: $tmp_units!!!"
    }
    if { $max_units == "s" && $tmp_units == "s" } {
      set max_value [expr ($max_value > $tmp_value) ? $max_value : $tmp_value]
    } elseif {$max_units == "ms"} {
      if {$tmp_units == "s"} {
        set max_value $tmp_value
        set max_units $tmp_units
      } elseif {$tmp_units == "ms"} {
        set max_value [expr ($max_value > $tmp_value) ? $max_value : $tmp_value]
      }
    } elseif {$max_units == "us"} {
      if {$tmp_units == "s" || $tmp_units == "ms"} {
        set max_value $tmp_value
        set max_units $tmp_units
      } elseif {$tmp_units == "us"} {
        set max_value [expr ($max_value > $tmp_value) ? $max_value : $tmp_value]
      }
    } elseif {$max_units == "ns"} {
      if {$tmp_units == "s" || $tmp_units == "ms" || $tmp_units == "us"} {
        set max_value $tmp_value
        set max_units $tmp_units
      } elseif {$tmp_units == "ns"} {
        set max_value [expr ($max_value > $tmp_value) ? $max_value : $tmp_value]
      }
    }
  }
  # Loop through the table of qualification window values
  for { set idx_vrails 0 } { $idx_vrails < [ get_parameter_value VRAILS ] } { incr idx_vrails } {
    set tmp_value [ regsub -all {[a-z]} [ lindex [ get_parameter_value QUALTIME ] $idx_vrails ] ""]
    set tmp_units [ regsub -all {[0-9]} [ lindex [ get_parameter_value QUALTIME ] $idx_vrails ] ""]
    if {$tmp_units != "s" && $tmp_units != "ms" && $tmp_units != "us" && $tmp_units != "ns"} {
      send_message {error} "Invalid unit specified: $tmp_units!!!"
    }
    if { $max_units == "s" && $tmp_units == "s" } {
      set max_value [expr ($max_value > $tmp_value) ? $max_value : $tmp_value]
    } elseif {$max_units == "ms"} {
      if {$tmp_units == "s"} {
        set max_value $tmp_value
        set max_units $tmp_units
      } elseif {$tmp_units == "ms"} {
        set max_value [expr ($max_value > $tmp_value) ? $max_value : $tmp_value]
      }
    } elseif {$max_units == "us"} {
      if {$tmp_units == "s" || $tmp_units == "ms"} {
        set max_value $tmp_value
        set max_units $tmp_units
      } elseif {$tmp_units == "us"} {
        set max_value [expr ($max_value > $tmp_value) ? $max_value : $tmp_value]
      }
    } elseif {$max_units == "ns"} {
      if {$tmp_units == "s" || $tmp_units == "ms" || $tmp_units == "us"} {
        set max_value $tmp_value
        set max_units $tmp_units
      } elseif {$tmp_units == "ns"} {
        set max_value [expr ($max_value > $tmp_value) ? $max_value : $tmp_value]
      }
    }
  }
  set_parameter_value MAXDELAY ${max_value}${max_units}
  #+---------------------------------------------------------------------------

}

# +----------------------------------------------------------------------------
# |
# | Generation callback routine:
# |   This process creates the package of parameters for the voltage sequencer,
# |   and adds it as well as all sub-blocks to the project.
# +----------------------------------------------------------------------------
proc generate { entity_name } {
  set P_CLKPERIOD   [get_parameter_value DV_CLKPERIOD]
  set P_MAXDELAY    [get_parameter_value MAXDELAY]
  set P_VRAILS      [expr [get_parameter_value VRAILS] - 1]
  if {[get_parameter_value USE_PWR_GROUPS]} {
    set P_PWR_GROUPS  [expr [get_parameter_value PWR_GROUPS] - 1]
  } else {
    set P_PWR_GROUPS  [expr [get_parameter_value VRAILS] - 1]
  } 
  set P_PWRGROUP ""
  for { set idx 0 } { $idx <= $P_VRAILS } { incr idx } {
    if { $idx == $P_VRAILS } {
      append P_PWRGROUP "[ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx ]"
    } else {
      append P_PWRGROUP "[ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx ], "
    }
    set TMP_SEQDLY([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx ])  [ lindex [ get_parameter_value SEQDLY ] $idx ]
    set TMP_QUALTIME([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx ])  [ lindex [ get_parameter_value QUALTIME ] $idx ]
    #set TMP_DCHGDLY([ lindex [ get_parameter_value PWR_GROUP_NUM ] $idx ])  [ lindex [ get_parameter_value DCHGDLY ] $idx ]
  }
  set P_SEQDLY ""
  set P_QUALTIME ""
  set P_DCHGDLY ""
  for { set idx 0 } { $idx <= $P_PWR_GROUPS } { incr idx } {
    if { $idx == $P_PWR_GROUPS } {
      append P_SEQDLY "$TMP_SEQDLY($idx)"
      append P_QUALTIME "$TMP_QUALTIME($idx)"
      #append P_DCHGDLY "$TMP_DCHGDLY($idx)"
      append P_DCHGDLY "0us"
    } else {
      append P_SEQDLY "$TMP_SEQDLY($idx), "
      append P_QUALTIME "$TMP_QUALTIME($idx), "
      #append P_DCHGDLY "$TMP_DCHGDLY($idx), "
      append P_DCHGDLY "0us, "
    }
  }
  set P_RESTARTDLY "0ns, "
  for { set idx 1 } { $idx <= 7 } { incr idx } {
    if { $idx == 7 } {
      append P_RESTARTDLY "[ get_parameter_value RESTARTDLY ]"
    } else {
      append P_RESTARTDLY "[ get_parameter_value RESTARTDLY ], "
    }
  }
  # Create a file descriptor to a temporary file that will contain the parameters used by the MegaWizard.
#  set output_dir [create_temp_file ""]
#  set seq_pkg_file_path [file join $output_dir "sequencer_params_pkg.sv"]
  set seq_pkg_file_path "sequencer_params_pkg.sv"
  set f_handle [open $seq_pkg_file_path w+]
  # Generate the package file with the various constants for the Voltage Monitor
  puts $f_handle "
////////////////////////////////////////////////////////////////////////////////////
//
// Module: sequencer_params
//
// Description: This module contains the timing parameters for the power sequencer
//
////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019 Intel Corporation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the \"Software\"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////////
//
// Current Assumptions/Limitations:
//
////////////////////////////////////////////////////////////////////////////////////

package sequencer_params_pkg;
  // These lines are required for the tools to understand that we are calculating with units of time.
  timeunit 1ns;
  timeprecision 1ns;

  // Define the clock period of the clock input to the sequencer
  parameter time P_CLKPERIOD        = ${P_CLKPERIOD}ns;
  
  // Map the voltage rails to \"Power Group\" values.  This array is only used when the \"PWR_GROUPS\" parameter on
  //   the module is less than the \"VRAILS\" parameter.  Valid groups range from 0 to PWR_GROUPS-1.
  parameter time P_PWRGROUP \[0:$P_VRAILS\] = '{$P_PWRGROUP};

  // Defines the delay from when the master enable is asserted to when the first rail's output enable
  //   is asserted, or from when power good is asserted until the next rail's output enable is
  //   asserted.  A value of \"0ns\" will bypass this delay.
  parameter time P_SEQDLY \[0:$P_PWR_GROUPS\]     = '{$P_SEQDLY};
  //
  // Defines the qualification window for which power good must be asserted, after output enable is asserted.
  //   If this time is violated, a fault will be indicated and the power rails will sequence down in reverse order
  parameter time P_QUALTIME \[0:$P_PWR_GROUPS\]   = '{$P_QUALTIME};
  //
  // Define the delay that the sequence will wait while sequencing *down*, after power good is deasserted, to
  //   allow the rail to gracefully discharge before forcing it.  A value of \"0ns\" will assert the discharge output
  //   immediately after power good is deasserted.
   parameter time P_DCHGDLY \[0:$P_PWR_GROUPS\]   = '{$P_DCHGDLY};
 
  // Define the delay interval between restart attempts for the sequencer.  Multiple delay times can be specified, and
  //   the interval used is determined by the REG_TIMEOUTDLY input.  Units can be specified as s, ms, us, and ns (e.g. 10ms).
  //   A value of \"0ns\" will bypass this delay.
  parameter time P_RESTARTDLY \[0:7\] = '{$P_RESTARTDLY};
  //
  // Define the maximum delay interval for dynamically sizing the delay counter.  This should be the largest delay from
  //   P_SEQDLY, P_QUALTIME, P_DCHGDLY, or P_RESTARTDLY.  If this is set too small, the design will not behave correctly,
  //    and incorrect \"optimizations\" to the logic will occur.
  parameter time P_MAXDELAY         = $P_MAXDELAY;
endpackage
"
  close $f_handle
  # Add the IP file generated above to the fileset for the TX OpenLDI IP
  add_fileset_file sequencer_params_pkg.sv SYSTEM_VERILOG PATH $seq_pkg_file_path
  add_fileset_file sequencer_ctrl.sv SYSTEM_VERILOG PATH sequencer_ctrl.sv
  add_fileset_file sequencer_top.sv SYSTEM_VERILOG PATH sequencer_top.sv TOP_LEVEL_FILE
}