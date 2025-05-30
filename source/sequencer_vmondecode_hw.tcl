# TCL File Generated by Component Editor 18.0
# Wed Jan 09 16:24:37 CST 2019
# DO NOT MODIFY


# 
# sequencer_vmondecode "Sequencer ADC Decoder" v1.0
#  2019.01.09.16:24:37
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module sequencer_vmondecode
# 
set_module_property DESCRIPTION ""
set_module_property NAME sequencer_vmondecode
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME "Sequencer ADC Decoder"
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
set_fileset_property QUARTUS_SYNTH TOP_LEVEL sequencer_vmondecode
set_fileset_property SIM_VERILOG TOP_LEVEL sequencer_vmondecode
set_fileset_property SIM_VHDL TOP_LEVEL sequencer_vmondecode


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

add_parameter ADC_IFNUM INTEGER 1
set_parameter_property ADC_IFNUM DEFAULT_VALUE 1
set_parameter_property ADC_IFNUM DISPLAY_NAME "ADC Streaming Interfaces"
set_parameter_property ADC_IFNUM DESCRIPTION "The number of Max10 ADCs that are being interfaced to."
set_parameter_property ADC_IFNUM TYPE INTEGER
set_parameter_property ADC_IFNUM UNITS None
set_parameter_property ADC_IFNUM ALLOWED_RANGES {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16}
set_parameter_property ADC_IFNUM HDL_PARAMETER true

add_parameter PG_NUM INTEGER 0
set_parameter_property PG_NUM DEFAULT_VALUE 0
set_parameter_property PG_NUM DISPLAY_NAME "Power Good Inputs"
set_parameter_property PG_NUM DESCRIPTION "The number of power good inputs to be monitored."
set_parameter_property PG_NUM TYPE INTEGER
set_parameter_property PG_NUM UNITS None
set_parameter_property PG_NUM ALLOWED_RANGES 0:143
set_parameter_property PG_NUM HDL_PARAMETER true

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

add_parameter PG_DEBOUNCE INTEGER 1
set_parameter_property PG_DEBOUNCE DEFAULT_VALUE 1
set_parameter_property PG_DEBOUNCE DISPLAY_NAME "Power Good Debounce Setting"
set_parameter_property PG_DEBOUNCE DESCRIPTION "The number of clock cycles (2^n) that the PG input signal needs to be stable."
set_parameter_property PG_DEBOUNCE TYPE INTEGER
set_parameter_property PG_DEBOUNCE UNITS None
set_parameter_property PG_DEBOUNCE ALLOWED_RANGES {1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28}
set_parameter_property PG_DEBOUNCE HDL_PARAMETER true

add_parameter DV_PG_DEBOUNCE FLOAT 1
set_parameter_property DV_PG_DEBOUNCE DISPLAY_NAME "Power Good Debounce Interval"
set_parameter_property DV_PG_DEBOUNCE DESCRIPTION "Duration in useconds for which the PG input needs to be stable.  This value cannot be calculated when the input clock rate is unknown or unconnected to a clock signal."
set_parameter_property DV_PG_DEBOUNCE DISPLAY_UNITS "us"
set_parameter_property DV_PG_DEBOUNCE DERIVED true
set_parameter_property DV_PG_DEBOUNCE HDL_PARAMETER false

# 
# display items
# 


# Parameters relating to the VOUT output rails - loop through the number of rails and create a tab for each one
add_parameter VIN_ADC_IFNUM STRING PG_Input
set_parameter_property VIN_ADC_IFNUM DISPLAY_NAME "ADC Interface/PG for VIN"
set_parameter_property VIN_ADC_IFNUM DESCRIPTION "Indicates which Avalon-ST ADC interface is transmitting the voltage level for the VIN rail, or whether the Power Good (PG) will be used to monitor VIN."
set_parameter_property VIN_ADC_IFNUM ALLOWED_RANGES {PG_Input}

add_parameter VIN_ADC_CHANNEL INTEGER 0
set_parameter_property VIN_ADC_CHANNEL DISPLAY_NAME "ADC/PG Channel for VIN"
set_parameter_property VIN_ADC_CHANNEL DESCRIPTION "Defines which physical ADC channel (ADC0 - ADC16), or Power Good (PG) input should be mapped to VIN."
set_parameter_property VIN_ADC_CHANNEL ALLOWED_RANGES 0:143

add_parameter VOUT_NAME STRING_LIST
set_parameter_property VOUT_NAME DISPLAY_NAME "Voltage Rail"
set_parameter_property VOUT_NAME AFFECTS_ELABORATION true
set_parameter_property VOUT_NAME HDL_PARAMETER false
set_parameter_property VOUT_NAME DERIVED true
set_parameter_property VOUT_NAME DISPLAY_HINT FIXED_SIZE
set_parameter_property VOUT_NAME DISPLAY_HINT WIDTH:100

# Initialize the table of entries for ADC Interface Number/PG and ADC/PG Channel
set adc_if_list_init ""
set adc_ch_list_init ""
for { set i 0 } { $i < 143 } { incr i } {   
  lappend adc_if_list_init "PG_Input"
  lappend adc_ch_list_init "0"
}
add_parameter ADC_CHANNEL_IFNUM STRING_LIST $adc_if_list_init
set_parameter_property ADC_CHANNEL_IFNUM DEFAULT_VALUE $adc_if_list_init
set_parameter_property ADC_CHANNEL_IFNUM DISPLAY_NAME "ADC Interface Number/PG"
set_parameter_property ADC_CHANNEL_IFNUM ALLOWED_RANGES {PG_Input}
set_parameter_property ADC_CHANNEL_IFNUM DISPLAY_HINT FIXED_SIZE
set_parameter_property ADC_CHANNEL_IFNUM DISPLAY_HINT WIDTH:150

add_parameter ADC_CHANNEL_VOUTNUM INTEGER_LIST $adc_ch_list_init
set_parameter_property ADC_CHANNEL_VOUTNUM DEFAULT_VALUE $adc_ch_list_init
set_parameter_property ADC_CHANNEL_VOUTNUM DISPLAY_NAME "ADC/PG Channel"
set_parameter_property ADC_CHANNEL_VOUTNUM ALLOWED_RANGES 0:143
set_parameter_property ADC_CHANNEL_VOUTNUM DISPLAY_HINT FIXED_SIZE
set_parameter_property ADC_CHANNEL_VOUTNUM DISPLAY_HINT WIDTH:100

add_display_item "ADC Channel Mapping" id0 text "<html><dl>
<dt>ADC Interface Number/PG:</dt>
<dd>Indicates which Avalon-ST ADC interface is transmitting the voltage level for the specified VOUT rail, or <br>
whether the Power Good (PG) will be used to monitor a given VOUT rail.<br/><br/></dd>
<dt>ADC/PG Channel:</dt>
<dd>Defines which physical ADC channel (ADC0 - ADC16), or Power Good (PG) input should be mapped to VOUT.</dd>
</dl>"
add_display_item "ADC Channel Mapping" myTable GROUP TABLE
add_display_item myTable VOUT_NAME PARAMETER
add_display_item myTable ADC_CHANNEL_IFNUM PARAMETER
add_display_item myTable ADC_CHANNEL_VOUTNUM PARAMETER


# 
# connection point reset
# 
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""

add_interface_port reset RESET_N reset_n Input 1


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
# connection point vmon_conduit
# 
add_interface vmon_conduit conduit end
set_interface_property vmon_conduit associatedClock clock
set_interface_property vmon_conduit associatedReset reset
set_interface_property vmon_conduit ENABLED true
set_interface_property vmon_conduit EXPORT_OF ""
set_interface_property vmon_conduit PORT_NAME_MAP ""
set_interface_property vmon_conduit CMSIS_SVD_VARIABLES ""
set_interface_property vmon_conduit SVD_ADDRESS_GROUP ""

add_interface_port vmon_conduit ADC_VIN_LEVEL_Q vin_level Output 14
add_interface_port vmon_conduit ADC_VOUT_LEVEL_Q vout_level Output VRAILS*14


# +----------------------------------------------------------------------------
# | Elaboration callback
# +----------------------------------------------------------------------------
proc elaborate {} {
  set ifnum [get_parameter_value ADC_IFNUM]
  set pgnum [get_parameter_value PG_NUM]

  #+---------------------------------------------------------------------------
  # Check for duplicate entries in the table
  set max_chan [expr ($pgnum > 16) ? $pgnum : 16]
  for { set idx_ifs 0 } { $idx_ifs <= $ifnum } { incr idx_ifs } {
    for { set idx_chs 0 } { $idx_chs <= $max_chan } { incr idx_chs } {
      set chk_if($idx_ifs,$idx_chs) 0
    }
  }
  set idx_ifs [ get_parameter_value VIN_ADC_IFNUM ]
  set idx_chs [ get_parameter_value VIN_ADC_CHANNEL ]
  if { $idx_ifs == "PG_Input" } { 
    if { ($idx_chs > $pgnum) } {
      send_message {error} "Specified PG Input bit $idx_chs is higher than the number of PG Inputs ($pgnum)!!!"
    }
    set chk_if(0,$idx_chs) 1
  } else {
    if { ($idx_chs > 16) } {
      send_message {error} "Specified ADC Channel $idx_chs is not valid!!!"
    }
    set chk_if($idx_ifs,$idx_chs) 1
  }  
  # Loop through the channels of the ADC Interfaces, mapping the correct VOUT rails to the channels
  for { set idx_vout 0 } { $idx_vout < [ get_parameter_value VRAILS ] } { incr idx_vout } {
    set idx_ifs [ lindex [ get_parameter_value ADC_CHANNEL_IFNUM ] $idx_vout ]
    set idx_chs [ lindex [ get_parameter_value ADC_CHANNEL_VOUTNUM ] $idx_vout ]
    if { $idx_ifs == "PG_Input" } {
      if { ($idx_chs > $pgnum) } {
        send_message {error} "Specified PG Input bit $idx_chs is higher than the number of PG Inputs ($pgnum)!!!"
      } else {
        if { $chk_if(0,$idx_chs) == 1 } {
          send_message {warning} "PG Input bit $idx_chs is used for multiple rails!!!"
        } else {
          set chk_if(0,$idx_chs) 1
        }
      }
    } else {
      if { $idx_ifs > $ifnum } {
        send_message {error} "Specified ADC Interface $idx_ifs is not valid!!!"
      } else {
        if { ($idx_chs > 16) } {
          send_message {error} "Specified ADC Channel $idx_chs is not valid!!!"
        } else {
          if { $chk_if($idx_ifs,$idx_chs) == 1 } {
            send_message {warning} "ADC Interface $idx_ifs channel $idx_chs is used for multiple rails!!!"
          } else {
            set chk_if($idx_ifs,$idx_chs) 1
          }
        }
      }
    }
  }
  #+---------------------------------------------------------------------------

  #+---------------------------------------------------------------------------
  # Optionally enable the Power Good (PG) interface
  if {[get_parameter_value PG_NUM] > "0" } {
    # Make the PG parameters visible
    set_parameter_property DV_CLOCK_RATE_CLK VISIBLE true
    set_parameter_property PG_DEBOUNCE VISIBLE true
    set_parameter_property DV_PG_DEBOUNCE VISIBLE true
    # Add PG output to Voltage Monitor conduit
    add_interface_port vmon_conduit POWER_GOOD_OUT power_good Output PG_NUM
    # Add PG input conduit (which is currently passed through to the VMON conduit)
    add_interface pg_input conduit end
    set_interface_property pg_input associatedClock ""
    set_interface_property pg_input associatedReset ""
    set_interface_property pg_input ENABLED true
    set_interface_property pg_input EXPORT_OF ""
    set_interface_property pg_input PORT_NAME_MAP ""
    set_interface_property pg_input CMSIS_SVD_VARIABLES ""
    set_interface_property pg_input SVD_ADDRESS_GROUP ""
    add_interface_port pg_input POWER_GOOD_IN power_good Input PG_NUM 
  } else {
    # Make the PG parameters invisible
    set_parameter_property DV_CLOCK_RATE_CLK VISIBLE false
    set_parameter_property PG_DEBOUNCE VISIBLE false
    set_parameter_property DV_PG_DEBOUNCE VISIBLE false
  }
  #+---------------------------------------------------------------------------

  #+---------------------------------------------------------------------------
  # Create the ADC interface
  #   Note: This is done by fracturing a single vector set into multiple 
  #   interfaces, each of which can be connected to an ADC AVST interface.
  #   This is to work around the limitation of no SV support in Qsys Std, and
  #   no multi-dimensional array support for ports in Verilog.
  set adc_channel_list "PG_Input"
  for { set s 0 } { $s < $ifnum } { incr s } {
    set ch_hi [expr ${s}*5+4]
    set ch_lo [expr ${s}*5]
    set data_hi [expr ${s}*12+11]
    set data_lo [expr ${s}*12]
    add_interface "adc_in${s}" avalon_streaming end
    set_interface_property "adc_in${s}" associatedClock clock
    set_interface_property "adc_in${s}" associatedReset reset
    set_interface_property "adc_in${s}" dataBitsPerSymbol 12
    set_interface_property "adc_in${s}" maxChannel 31
    add_interface_port "adc_in${s}" adc_sop${s} startofpacket Input 1
    add_interface_port "adc_in${s}" adc_eop${s} endofpacket Input 1
    add_interface_port "adc_in${s}" adc_valid${s} valid Input 1
    add_interface_port "adc_in${s}" adc_channel${s} channel Input 5
    add_interface_port "adc_in${s}" adc_data${s} data Input 12
    set_port_property  adc_sop${s} fragment_list "adc_sop(${s})"
    set_port_property  adc_eop${s} fragment_list "adc_eop(${s})"
    set_port_property  adc_valid${s} fragment_list "adc_valid(${s})"
    set_port_property  adc_channel${s} fragment_list "adc_channel(${ch_hi}:${ch_lo})"
    set_port_property  adc_data${s} fragment_list "adc_data(${data_hi}:${data_lo})"
    lappend adc_channel_list "[expr $s+1]"
  }
  set_parameter_property VIN_ADC_IFNUM ALLOWED_RANGES $adc_channel_list
  set_parameter_property ADC_CHANNEL_IFNUM ALLOWED_RANGES $adc_channel_list
  ## FIX UI VOUT name and #
  set vout_list ""
  for { set out 0 } { $out < [ get_parameter_value VRAILS ] } { incr out } {   
      lappend vout_list "VOUT$out"
  }    
  set_parameter_value VOUT_NAME $vout_list
  #+---------------------------------------------------------------------------

  # Dynamically resize the table, based on the number of user-entered VOUT rails
  set_display_item_property myTable DISPLAY_HINT ROWS:[ get_parameter_value VRAILS ]
  set_display_item_property myTable DISPLAY_HINT COLUMNS:3
  set P_CLOCK_RATE_CLK          [expr ([ get_parameter_value CLOCK_RATE_CLK ] / 1000000)]
  set_parameter_value  DV_CLOCK_RATE_CLK $P_CLOCK_RATE_CLK
  set_parameter_value  DV_PG_DEBOUNCE [expr (pow(2,[ get_parameter_value PG_DEBOUNCE ])-1)/$P_CLOCK_RATE_CLK]
}


# +----------------------------------------------------------------------------
# |
# | Generation callback routine:
# |   This process creates the package of parameters for the voltage monitor
# |   interface decoder, and adds it as well as all sub-blocks to the project.
# +----------------------------------------------------------------------------
proc generate { entity_name } {
  set P_PGNUM [ get_parameter_value PG_NUM ]
  # Initialize the PG Channel Map Array to an unused VOUT rail (199)
  for { set i 0 } { $i < $P_PGNUM } { incr i } {   
    set array_pg_map($i) 199
  }
  # Initialize the ADC Channel Map Array to an unused VOUT rail (199)
  send_message {info} "Generating file: sequencer_vmondecode_pkg.sv"
  for { set i 1 } { $i <= [ get_parameter_value ADC_IFNUM ] } { incr i } {   
    for { set j 0 } { $j <= 16 } { incr j } {   
      set array_chan_map($i,$j) 199
    }
  }
  # Set the VIN rail (0)
  set P_ADC_IFNUM [expr [ get_parameter_value ADC_IFNUM ] -1 ]
  set P_VRAILSm1  [expr [ get_parameter_value VRAILS ] -1 ]
  set P_VRAILS          [ get_parameter_value VRAILS ]
  set P_VRAILSp1  [expr [ get_parameter_value VRAILS ] +1 ]
  set idx_if [ get_parameter_value VIN_ADC_IFNUM ]
  set idx_ch [ get_parameter_value VIN_ADC_CHANNEL ]
  set array_chan_map($idx_if,$idx_ch) 0
  set P_DEFAULT_PAGE 199
  if { $idx_if == "PG_Input" } { 
    set P_VRAIL_SEL "$P_VRAILSp1'b0"
    set P_VRAIL_PG_MAP "$idx_ch, "
  } else {
    set P_DEFAULT_PAGE 0
    set P_VRAIL_SEL "$P_VRAILSp1'b1"
    set P_VRAIL_PG_MAP "199, "
  }
  # Loop through the channels of the ADC Interfaces, mapping the correct VOUT rails to the channels
  for { set i 0 } { $i < [ get_parameter_value VRAILS ] } { incr i } {
    set idx_if [ lindex [ get_parameter_value ADC_CHANNEL_IFNUM ] $i ]
    set idx_ch [ lindex [ get_parameter_value ADC_CHANNEL_VOUTNUM ] $i ]
    if { $idx_if == "PG_Input" } {
      set array_pg_map($idx_ch) $i
      append P_VRAIL_SEL "0"
      if { $i == [expr [ get_parameter_value VRAILS ] -1 ] } {
          append P_VRAIL_PG_MAP "$idx_ch"
      } else {
          append P_VRAIL_PG_MAP "$idx_ch, "
      }
    } else {
      set array_chan_map($idx_if,$idx_ch) [expr $i+1]
      append P_VRAIL_SEL "1"
      if { $i == [expr [ get_parameter_value VRAILS ] -1 ] } {
          append P_VRAIL_PG_MAP "199"
      } else {
          append P_VRAIL_PG_MAP "199, "
      }
      # Determine the first PMBus page register
      if { $P_DEFAULT_PAGE == 199 } {
          set P_DEFAULT_PAGE $i
      }
    }
  }
  # Create the string list that will be used to create the verilog parameter for the ADC channel mapping
  set P_ADC_CHAN_MAP ""
  for { set i 1 } { $i <= [ get_parameter_value ADC_IFNUM ] } { incr i } {
    if { $i == 1 } { append P_ADC_CHAN_MAP "'\{" }
    append P_ADC_CHAN_MAP "'\{"
    for { set j 0 } { $j <= 16 } { incr j } {
      if { $j == 16 } {
        append P_ADC_CHAN_MAP "$array_chan_map($i,$j)"
      } else {
        append P_ADC_CHAN_MAP "$array_chan_map($i,$j), "
      }
    }
    if { $i == [ get_parameter_value ADC_IFNUM ] } {
      append P_ADC_CHAN_MAP "\}"
    } else {
      append P_ADC_CHAN_MAP "\},"
    }
  }
  append P_ADC_CHAN_MAP "\}"
  # Create the string list that will be used to create the verilog parameter for the PG channel mapping
  set P_PG_CHAN_MAP ""
  # Loop through the channels of the PG Interfaces, mapping the correct VOUT rails to the channels
  for { set i 0 } { $i < $P_PGNUM } { incr i } {
    if { $i == [expr [ get_parameter_value PG_NUM ] -1 ] } {
        append P_PG_CHAN_MAP "$array_pg_map($i)"
    } else {
        append P_PG_CHAN_MAP "$array_pg_map($i), "
    }
  }

  # Create a file descriptor to a temporary file that will contain the parameters used by the MegaWizard.
#  set output_dir [create_temp_file ""]
#  set vmondecode_pkg_file_path [file join $output_dir "sequencer_vmondecode_pkg.sv"]
  set vmondecode_pkg_file_path "sequencer_vmondecode_pkg.sv"
  set f_handle [open $vmondecode_pkg_file_path w+]
  # Generate the package file with the various constants for the Voltage Monitor
  puts $f_handle "
////////////////////////////////////////////////////////////////////////////////////
//
// Module: sequencer_vmondecode_pkg.sv
//
// Description: This module contains the  parameters for the ADC voltage decoder
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

package sequencer_vmondecode_pkg;

  // Set the default PMBus page to the lowest used rail (VIN or VOUT) that uses an ADC-monitored
  //   input to monitor the voltage level (i.e. not a PG input).  Page 0 is used for VIN or VOUT0,
  //   and the remaining pages correspond to whether VOUT is an ADC-monitored rail.
  localparam int P_DEFAULT_PAGE            = $P_DEFAULT_PAGE;
  // Indicate whether the VRAIL should be qualified by the voltage monitor or by its own PG
  //   signal.  A value of '0' indicates PG, whereas '1' indicates the monitored ADC level.
  localparam bit \[0:$P_VRAILS\] P_VRAIL_SEL         = $P_VRAIL_SEL;
  // Map physical ADC channel to logical channel number.  Array element 0 maps to ADCIN0,
  //   1 to ADCIN1, and so on.  The value at each location relates to the voltage rail
  //   being monitored.  \"0\" indicates VIN and the VOUT rails are indicated in increasing
  //   value, up to the \"VRAILS\" parameter.  Any number greater than \"VRAILS\" (such as 199)
  //   is ignored, indicating that the channel is not utilized by the sequencer."
  if {$P_ADC_IFNUM == -1} {
    puts $f_handle "  localparam int P_ADC_CHAN_MAP\[0:0\]\[0:0\]  = '{'{0}};"
  } else {
    puts $f_handle "  localparam int P_ADC_CHAN_MAP\[0:$P_ADC_IFNUM\]\[0:16\]  = $P_ADC_CHAN_MAP;"
  }
  puts $f_handle "  // When the Power Good (PG) Inputs are not being used, the following define disables the interface"
  if {$P_PGNUM != 0} {
    puts $f_handle "  //`define DISABLE_PGBUS"
  } else {
    puts $f_handle "  `define DISABLE_PGBUS"
  }
  puts $f_handle "  // Map physical PG input to logical channel number.  Array element \"0\" is for VIN, and the
  //   VOUT rails are indicated in increasing value, up to the \"VRAILS\" parameter.  Any number
  //   greater than \"VRAILS\" (such as 199) is ignored, indicating that the Voltage Rail is
  //   not using the PG input.
  localparam int P_VRAIL_PG_MAP\[0:$P_VRAILS\]       = '{$P_VRAIL_PG_MAP};

endpackage
"
  close $f_handle
  # Add the IP file generated above to the fileset for the Voltage Monitor Decoder
  add_fileset_file sequencer_vmondecode_pkg.sv SYSTEM_VERILOG PATH $vmondecode_pkg_file_path
  add_fileset_file debounce.sv SYSTEM_VERILOG PATH debounce.sv
  add_fileset_file sequencer_vmondecode.sv SYSTEM_VERILOG PATH sequencer_vmondecode.sv TOP_LEVEL_FILE
}