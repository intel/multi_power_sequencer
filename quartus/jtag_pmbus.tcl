######################################################################
# Global settings
######################################################################
# Define the number of VOUT rails in the design
set G_VREF                    2.5
# Define the word-aligned addresses for the PMBus Commands 
set P_CMD_PAGE                [expr {4 * 0x00}]
set P_CMD_CLEAR_FAULTS        [expr {4 * 0x03}]
set P_CMD_VIN_ON              [expr {4 * 0x35}]
set P_CMD_VIN_OFF             [expr {4 * 0x36}]
set P_CMD_VOUT_OV_FAULT_LIMIT [expr {4 * 0x40}]
set P_CMD_VOUT_OV_FAULT_RESP  [expr {4 * 0x41}]
set P_CMD_VOUT_OV_WARN_LIMIT  [expr {4 * 0x42}]
set P_CMD_VOUT_UV_WARN_LIMIT  [expr {4 * 0x43}]
set P_CMD_VOUT_UV_FAULT_LIMIT [expr {4 * 0x44}]
set P_CMD_VOUT_UV_FAULT_RESP  [expr {4 * 0x45}]
set P_CMD_VIN_OV_FAULT_LIMIT  [expr {4 * 0x55}]
set P_CMD_VIN_OV_FAULT_RESP   [expr {4 * 0x56}]
set P_CMD_VIN_OV_WARN_LIMIT   [expr {4 * 0x57}]
set P_CMD_VIN_UV_WARN_LIMIT   [expr {4 * 0x58}]
set P_CMD_VIN_UV_FAULT_LIMIT  [expr {4 * 0x59}]
set P_CMD_VIN_UV_FAULT_RESP   [expr {4 * 0x5A}]
set P_CMD_POWER_GOOD_ON       [expr {4 * 0x5E}]
set P_CMD_POWER_GOOD_OFF      [expr {4 * 0x5F}]
set P_CMD_STATUS_BYTE         [expr {4 * 0x78}]
set P_CMD_STATUS_WORD         [expr {4 * 0x79}]
set P_CMD_STATUS_VOUT         [expr {4 * 0x7A}]
set P_CMD_STATUS_INPUT        [expr {4 * 0x7C}]
set P_CMD_STATUS_CML          [expr {4 * 0x7E}]
set P_CMD_STATUS_OTHER        [expr {4 * 0x7F}]
set P_CMD_READ_VIN            [expr {4 * 0x88}]
set P_CMD_READ_VOUT           [expr {4 * 0x8B}]
set P_CMD_MFR_TOD             [expr {4 * 0xC4}]
set P_CMD_MFR_TOD_ADJUST      [expr {4 * 0xC5}]
set P_CMD_MFR_NV_CONTROL      [expr {4 * 0xD0}]
set P_CMD_MFR_NV_MASTER_EN    [expr {4 * 0xD1}]
set P_CMD_MFR_NV_PAGE_EN      [expr {4 * 0xD2}]
set P_CMD_MFR_NV_ERRLOG_DAT   [expr {4 * 0xD4}]
set P_CMD_MFR_NV_ERRLOG_BBDAT [expr {4 * 0xD5}]
set P_CMD_MFR_NV_ERRLOG_TOD   [expr {4 * 0xD6}]

# Select the master service type and check for available service paths.
set jtag_master [lsearch -inline [get_service_paths master] *PM2AVMM_JTAG_Master*];
## Open the master service.
set mast [claim_service master $jtag_master mylib]
puts "\nInfo: Opened JTAG Master Service: $jtag_master\n"

######################################################################
# Procedure: SCAN
#   Identify the number of rails in the sequencer
######################################################################
proc SCAN {} {
  global mast
  global G_VOUT_NUM
  global G_LOGGING
  variable P_CMD_PAGE
  variable P_CMD_STATUS_WORD
  variable P_CMD_MFR_TOD_ADJUST

  # Scan through the pages.  Once an error is received, break loop and
  #   set index as the last valid page.
  for {set i 0} {$i < 255} {incr i} {
    CLEAR_STATUS
    master_write_32 $mast $P_CMD_PAGE $i
    if {[master_read_32 $mast $P_CMD_STATUS_WORD 1] != 0x0} {break}
  }
  CLEAR_STATUS
  set G_VOUT_NUM $i

  # Attempt a read of the TOD adjustment register to determine whether
  #   logging is enabled or not.
  set G_LOGGING 0
  master_read_32 $mast $P_CMD_MFR_TOD_ADJUST 1
  if {[master_read_32 $mast $P_CMD_STATUS_WORD 1] == 0x0} {set G_LOGGING 1}
  CLEAR_STATUS
}

######################################################################
# Procedure: CLEAR_STATUS
#   Clear out all latched status from the various status registers
######################################################################
proc CLEAR_STATUS {} {
  global mast
  variable P_CMD_CLEAR_FAULTS

  master_write_32 $mast $P_CMD_CLEAR_FAULTS 0
}

######################################################################
# Procedure: SET_PAGE
#   Specify the PMBus page register in the slave device
######################################################################
proc SET_PAGE {pagenum} {
  global mast
  variable P_CMD_PAGE
  variable P_CMD_VOUT_OV_FAULT_LIMIT

  master_write_32 $mast $P_CMD_PAGE $pagenum
}

######################################################################
# Procedure: SET_RETRIES
#   Set the number of retries after an error, in the global response
#   register
######################################################################
proc SET_RETRIES {retrynum} {
  global mast
  variable P_CMD_VOUT_UV_FAULT_RESP

  # Read/modify/write the masked value of the global response register
  #   (via the VOUT_UV_FAULT_RESP register)
  set var_default_uv_resp [master_read_32 $mast $P_CMD_VOUT_UV_FAULT_RESP 1]
  set var_default_uv_resp [expr ($var_default_uv_resp & 0xC7) | ($retrynum << 3)]
  master_write_32 $mast $P_CMD_VOUT_UV_FAULT_RESP $var_default_uv_resp
}

######################################################################
# Procedure: SET_DELAY
#   Enable/disable the timeout in the global response register
######################################################################
proc SET_DELAY {delaynum} {
  global mast
  variable P_CMD_VOUT_UV_FAULT_RESP

  # Read/modify/write the masked value of the global response register
  #   (via the VOUT_UV_FAULT_RESP register)
  set var_default_uv_resp [master_read_32 $mast $P_CMD_VOUT_UV_FAULT_RESP 1]
  set var_default_uv_resp [expr ($var_default_uv_resp & 0xF8) | $delaynum]
  master_write_32 $mast $P_CMD_VOUT_UV_FAULT_RESP $var_default_uv_resp
}

######################################################################
# Procedure: SET_TOD_ADJUST
#   Adjust the number of clock ticks per second to speed up/slow down
#   time-of-day clock
######################################################################
proc SET_TOD_ADJUST {value} {
  global mast
  variable P_CMD_MFR_TOD_ADJUST

  master_write_32 $mast $P_CMD_MFR_TOD_ADJUST $value
}

######################################################################
# Procedure: SET_TOD
#   Sets the current Time of Day counter to the system clock
######################################################################
proc SET_TOD {} {
  global mast
  variable P_CMD_MFR_TOD

  # Determine the current time from the system clock.  On Windows,
  #   the "epoch" is 1/1/1970 0:0:0 GMT, whereas I use 1/1/2020.
  #   The offset between these two times is 1577836800 seconds.
  set var_current_tod [expr [clock seconds] - 1577836800]
  master_write_32 $mast $P_CMD_MFR_TOD $var_current_tod
}

######################################################################
# Procedure: SET_RESPONSE
#   Set the VIN/VOUT over/undervoltage error condition response
######################################################################
proc SET_RESPONSE {pagenum vrail responsenum} {
  global mast
  variable P_CMD_PAGE
  variable P_CMD_VIN_UV_FAULT_RESP
  variable P_CMD_VIN_OV_FAULT_RESP
  variable P_CMD_VOUT_UV_FAULT_RESP
  variable P_CMD_VOUT_OV_FAULT_RESP

  master_write_32 $mast $P_CMD_PAGE $pagenum

  switch $vrail {
    VIN_UV {
      set var_default_resp [master_read_32 $mast $P_CMD_VIN_UV_FAULT_RESP 1]
      set var_default_resp [expr ($var_default_resp & 0x3F) | ($responsenum << 7)]
      master_write_32 $mast $P_CMD_VIN_UV_FAULT_RESP $var_default_resp
    }
    VIN_OV {
      set var_default_resp [master_read_32 $mast $P_CMD_VIN_OV_FAULT_RESP 1]
      set var_default_resp [expr ($var_default_resp & 0x3F) | ($responsenum << 7)]
      master_write_32 $mast $P_CMD_VIN_OV_FAULT_RESP $var_default_resp
    }
    VOUT_UV {
      set var_default_resp [master_read_32 $mast $P_CMD_VOUT_UV_FAULT_RESP 1]
      set var_default_resp [expr ($var_default_resp & 0x3F) | ($responsenum << 7)]
      master_write_32 $mast $P_CMD_VOUT_UV_FAULT_RESP $var_default_resp
    }
    VOUT_OV {
      set var_default_resp [master_read_32 $mast $P_CMD_VOUT_OV_FAULT_RESP 1]
      set var_default_resp [expr ($var_default_resp & 0x3F) | ($responsenum << 7)]
      master_write_32 $mast $P_CMD_VOUT_OV_FAULT_RESP $var_default_resp
    }
    default {
      puts "Error: Unknown rail $vrail"
    }
  }
}

######################################################################
# Procedure: NVLOG_ENABLE
#   Enables varying levels of non-volatile flash error logging
#
#   0 = disabled,
#   1 = enable logging,
#   3 = enable logging + blackbox
######################################################################
proc NVLOG_ENABLE {loglevel} {
  global mast
  variable P_CMD_MFR_NV_MASTER_EN

  # Read/modify/write the masked value of the master enable register
  set var_default_nvcfg [master_read_32 $mast $P_CMD_MFR_NV_MASTER_EN 1]
  set var_default_nvcfg [expr ($var_default_nvcfg & 0xFFFFFFFC | $loglevel)]
  master_write_32 $mast $P_CMD_MFR_NV_MASTER_EN $var_default_nvcfg
}

######################################################################
# Procedure: NVLOG_CLEAR
#   Clear out all NV Flash Entries
######################################################################
proc NVLOG_CLEAR {} {
  global mast
  variable P_CMD_MFR_NV_CONTROL

  # Read/modify/write the masked value of the global response register
  #   (via the VOUT_UV_FAULT_RESP register)
  set var_default_nvcfg [master_read_32 $mast $P_CMD_MFR_NV_CONTROL 1]
  set var_default_nvcfg [expr ($var_default_nvcfg | 0x01)]
  master_write_32 $mast $P_CMD_MFR_NV_CONTROL $var_default_nvcfg
}

######################################################################
# Procedure: READ_TOD
#   Read the current Time of Day counter
######################################################################
proc READ_TOD {} {
  global mast
  variable P_CMD_MFR_TOD

  # Read the "second" counter register
  set var_tod [master_read_32 $mast $P_CMD_MFR_TOD 1]
  # Add 1577836800 seconds (the difference between the Windows "epoch"
  #   and 1/1/2020, and print out the result as a formatted time
  set var_tod [expr $var_tod + 1577836800]
  clock format $var_tod
}

######################################################################
# Procedure: READ_TOD_ADJUST
#   Read the current Time of Day adjustment counter
######################################################################
proc READ_TOD_ADJUST {} {
  global mast
  variable P_CMD_MFR_TOD_ADJUST
  
  set var_tod [master_read_32 $mast $P_CMD_MFR_TOD_ADJUST 1]
  puts "TOD Adjustment: $var_tod"
}

######################################################################
# Procedure: READ_NVCFG
#   Read the configuration of NV Logging stats
######################################################################
proc READ_NVCFG {} {
  global mast
  variable G_VOUT_NUM
  variable G_VREF
  variable P_CMD_PAGE
  variable P_CMD_MFR_NV_CONTROL
  variable P_CMD_MFR_NV_MASTER_EN
  variable P_CMD_MFR_NV_PAGE_EN
  
  set var_nvcfg [master_read_32 $mast $P_CMD_MFR_NV_CONTROL 1]
  puts "NV Logging Configuration:"
  puts "  Total Log Entries: [expr ($var_nvcfg & 0xFF000000) >> 24]"
  puts "  Current index: [expr ($var_nvcfg & 0x00FF0000) >> 16]"
  puts "  Blackbox page offset: [expr ($var_nvcfg & 0x000000F0) >> 4]"
  set var_nvcfg [master_read_32 $mast $P_CMD_MFR_NV_MASTER_EN 1]
  if {[expr $var_nvcfg & 0x01] ne 0} { puts "  NV Logging Enabled"} else { puts "  NV Logging Disabled"}
  puts "  Error logging enabled for:"
  if {[expr $var_nvcfg & 0x04] ne 0} { puts "    VIN_OV"}
  if {[expr $var_nvcfg & 0x08] ne 0} { puts "    VIN_UV"}

  for {set i 0} {$i < $G_VOUT_NUM} {incr i} {
    master_write_32 $mast $P_CMD_PAGE $i
    set var_nvcfg [master_read_32 $mast $P_CMD_MFR_NV_PAGE_EN 1]
    if {[expr $var_nvcfg & 0x01] ne 0} { puts "    Page $i VOUT_OV"}
    if {[expr $var_nvcfg & 0x02] ne 0} { puts "    Page $i VOUT_UV"}
    if {[expr $var_nvcfg & 0x04] ne 0} { puts "    Page $i Qual Window Timeout"}
  }
  set var_nvcfg [master_read_32 $mast $P_CMD_MFR_NV_MASTER_EN 1]
  if {[expr $var_nvcfg & 0x02] ne 0} { puts "  Blackbox Enabled"} else { puts "  Blackbox Disabled"}
}

######################################################################
# Procedure: READ_NVLOG_ENTRY
#   Read an entry from the NV Log
######################################################################
proc READ_NVLOG_ENTRY {entrynum} {
  global mast
  variable G_VOUT_NUM
  variable P_CMD_PAGE
  variable P_CMD_MFR_NV_CONTROL
  variable P_CMD_MFR_NV_ERRLOG_DAT
  variable P_CMD_MFR_NV_ERRLOG_TOD
  variable P_CMD_MFR_NV_ERRLOG_BBDAT

  set var_nvctl [master_read_32 $mast $P_CMD_MFR_NV_CONTROL 1]
  set var_nvctl [expr (($var_nvctl & 0xFF00FFFF) | (($entrynum-1) << 16))]
  master_write_32 $mast $P_CMD_MFR_NV_CONTROL $var_nvctl
  set var_nvcfg [master_read_32 $mast $P_CMD_MFR_NV_ERRLOG_DAT 1]
  puts "NV Log Entry $entrynum:"
  if {[expr $var_nvcfg & 0xE000] ne 0} {
    puts -nonewline "  Blank entry"
  } else {
    set var_tod [master_read_32 $mast $P_CMD_MFR_NV_ERRLOG_TOD 1]
    set var_tod [expr $var_tod + 1577836800]
    puts "  Timestamp: [clock format $var_tod]"
    puts -nonewline "  Fault: ( "
    if {[expr $var_nvcfg & 0x0100] ne 0} { puts -nonewline "VOUT_OV "}
    if {[expr $var_nvcfg & 0x0200] ne 0} { puts -nonewline "VOUT_UV "}
    if {[expr $var_nvcfg & 0x0400] ne 0} { puts -nonewline "VIN_OV "}
    if {[expr $var_nvcfg & 0x0800] ne 0} { puts -nonewline "VIN_UV "}
    if {[expr $var_nvcfg & 0x1000] ne 0} { puts -nonewline "Qual Window Timeout "}
    puts ")"
    puts "  Page: [expr ($var_nvcfg & 0x00FF)]"
    for {set i 0} {$i < (($G_VOUT_NUM*2+2+31)/32)} {incr i} {
      set var_nvctl [expr (($var_nvctl & 0xFFFFFF0F) | ($i << 4))]
      master_write_32 $mast $P_CMD_MFR_NV_CONTROL $var_nvctl
      set var_nvcfg [master_read_32 $mast $P_CMD_MFR_NV_ERRLOG_BBDAT 1]
      puts "Blackbox Data Log:"
      for {set j 0} {$j < 16} {incr j} {
        if {(($i*16 + $j) > $G_VOUT_NUM)} {break}
        set var_page_status [expr (($var_nvcfg >> ($j*2)) & 0x3)]
        if {$i*16+$j == 0} { puts -nonewline "    VIN:"} else {
        puts -nonewline "  VOUT[expr $i*16+$j-1]:"}
        if       {$var_page_status == 0} {puts " OFF"
        } elseif {$var_page_status == 1} {puts " UV_ERR"
        } elseif {$var_page_status == 2} {puts " OV_ERR"
        } else                           {puts " ON"}
      }
    }
  }
}

######################################################################
# Procedure: READ_VOUT
#   Read the current VOUT voltage levels for all output rails
######################################################################
proc READ_VOUT {} {
  global mast
  variable G_VOUT_NUM
  variable G_VREF
  variable P_CMD_PAGE
  variable P_CMD_STATUS_WORD
  variable P_CMD_READ_VOUT
  
  CLEAR_STATUS
  for {set i 0} {$i < $G_VOUT_NUM} {incr i} {
    master_write_32 $mast $P_CMD_PAGE $i
    set var_voltage [master_read_32 $mast $P_CMD_READ_VOUT 1]
    if {[master_read_32 $mast $P_CMD_STATUS_WORD 1] == 0x0} {
      puts "Page $i VOUT: [format {%0.3f} [expr ($var_voltage / 4095.0) * $G_VREF]] V"
    } else {
      puts "Page $i VOUT: Digital Rail"
      CLEAR_STATUS
    }
  }
}

######################################################################
# Procedure: READ_STATUS
#   Read the current error status, and decode values via masking
######################################################################
proc READ_STATUS {} {
  global mast
  variable G_VOUT_NUM
  variable P_CMD_PAGE
  variable P_CMD_STATUS_WORD
  variable P_CMD_STATUS_CML
  variable P_CMD_STATUS_OTHER
  variable P_CMD_STATUS_VIN
  variable P_CMD_STATUS_VOUT

  for {set i 0} {$i < $G_VOUT_NUM} {incr i} {
    master_write_32 $mast $P_CMD_PAGE $i
    set reg_status [master_read_32 $mast $P_CMD_STATUS_WORD 1]
    puts "PAGE $i STATUS= $reg_status"
  
    if {$reg_status == 0x0} { puts "No errors"} else {
      if {[expr $reg_status & 0x0002] ne 0} {
        puts "  CML Error"
        set reg_status_cml [master_read_32 $mast $P_CMD_STATUS_CML 1]
        if {[expr $reg_status_cml & 0x40] ne 0} { puts "    Invalid/Unsupported Data"}
        if {[expr $reg_status_cml & 0x80] ne 0} { puts "    Invalid/Unsupported Command"}
      }
      if {[expr $reg_status & 0x0008] ne 0} { puts "  VIN Undervoltage Fault"}
      if {[expr $reg_status & 0x0020] ne 0} { puts "  VOUT Overvoltage Fault"}
      if {[expr $reg_status & 0x0040] ne 0} { puts "  Sequencer Outputs OFF"}
      if {[expr $reg_status & 0x0080] ne 0} { puts "  Sequencer Busy/Non-responsive"}
      if {[expr $reg_status & 0x0100] ne 0} { puts "  Unknown Error"}
      if {[expr $reg_status & 0x0200] ne 0} {
        puts "  Other Error"
        set reg_status_other [master_read_32 $mast $P_CMD_STATUS_OTHER 1]
        if {[expr $reg_status_other & 0x01] ne 0} { puts "    First to Assert SMBALERT#"}
      }
      if {[expr $reg_status & 0x0800] ne 0} { puts "  Power NOT Good Error"}
      if {[expr $reg_status & 0x1000] ne 0} { puts "  Manufacturer Specific Error"}
      if {[expr $reg_status & 0x2000] ne 0} {
        puts "  VIN Error"
        set reg_status_vin [master_read_32 $mast $P_CMD_STATUS_VIN 1]
        if {[expr $reg_status_vin & 0x08] ne 0} { puts "    Unit off / Low VIN"}
        if {[expr $reg_status_vin & 0x10] ne 0} { puts "    Undervoltage Fault"}
        if {[expr $reg_status_vin & 0x20] ne 0} { puts "    Undervoltage Warning"}
        if {[expr $reg_status_vin & 0x40] ne 0} { puts "    Overvoltage Warning"}
        if {[expr $reg_status_vin & 0x80] ne 0} { puts "    Overvoltage Fault"}
      }
      if {[expr $reg_status & 0x8000] ne 0} {
        puts "  VOUT Error"
        set reg_status_vout [master_read_32 $mast $P_CMD_STATUS_VOUT 1]
        if {[expr $reg_status_vout & 0x10] ne 0} { puts "    Undervoltage Fault"}
        if {[expr $reg_status_vout & 0x20] ne 0} { puts "    Undervoltage Warning"}
        if {[expr $reg_status_vout & 0x40] ne 0} { puts "    Overvoltage Warning"}
        if {[expr $reg_status_vout & 0x80] ne 0} { puts "    Overvoltage Fault"}
      }
    }
  }
}

######################################################################
# Procedure: READ_RESPONSE
#   Display how the sequencer will respond to various error conditions
######################################################################
proc READ_RESPONSE {} {
  global mast
  variable G_VOUT_NUM
  variable P_CMD_PAGE
  variable P_CMD_VIN_UV_FAULT_RESP
  variable P_CMD_VIN_OV_FAULT_RESP
  variable P_CMD_VOUT_UV_FAULT_RESP
  variable P_CMD_VOUT_OV_FAULT_RESP

  set reg_response [master_read_32 $mast $P_CMD_VIN_UV_FAULT_RESP 1]
  set reg_retry [expr ($reg_response & 0x38) >> 3]
  set reg_delay [expr $reg_response & 0x07]
  puts "Response register values:"
  if {$reg_delay ne 0} { puts "  Use sequencer-specified delay between restarts" } else { puts "  No delay between restarts" }
  if {$reg_retry eq 0} { puts "  No retries - remain disabled after error" } elseif {$reg_retry eq 7} {
                         puts "  Retry infinitely after error" } else {
                         puts "  Retry for $reg_retry attempts after error"
  }

  if {[expr $reg_response & 0xC0] eq 0} { puts "  VIN UV Response: Continue operation without interruption" } else {
                                          puts "  VIN UV Response: Sequence down in reverse order" }
  set reg_response [master_read_32 $mast $P_CMD_VIN_OV_FAULT_RESP 1]
  if {[expr $reg_response & 0xC0] eq 0} { puts "  VIN OV Response: Continue operation without interruption" } else {
                                          puts "  VIN OV Response: Sequence down in reverse order" }
  for {set i 0} {$i < $G_VOUT_NUM} {incr i} {
    master_write_32 $mast $P_CMD_PAGE $i
    set reg_response [master_read_32 $mast $P_CMD_VOUT_UV_FAULT_RESP 1]
    if {[expr $reg_response & 0xC0] eq 0} { puts "  Page $i VOUT UV Response: Continue operation without interruption" } else {
                                            puts "  Page $i VOUT UV Response: Sequence down in reverse order" }
    set reg_response [master_read_32 $mast $P_CMD_VOUT_OV_FAULT_RESP 1]
    if {[expr $reg_response & 0xC0] eq 0} { puts "  Page $i VOUT OV Response: Continue operation without interruption" } else {
                                            puts "  Page $i VOUT OV Response: Sequence down in reverse order" }
  }
}

######################################################################
# Procedure: ERROR_VOUT_UV
#   By adjusting the threshold from its current value and back,
#   create an undervoltage error on VOUT for the specified page
######################################################################
proc ERROR_VOUT_UV {pagenum} {
  global mast
  variable P_CMD_PAGE
  variable P_CMD_VOUT_UV_FAULT_LIMIT

  master_write_32 $mast $P_CMD_PAGE $pagenum
  set var_default_uv_limit [master_read_32 $mast $P_CMD_VOUT_UV_FAULT_LIMIT 1]
  master_write_32 $mast $P_CMD_VOUT_UV_FAULT_LIMIT 0xFF0
  master_write_32 $mast $P_CMD_VOUT_UV_FAULT_LIMIT $var_default_uv_limit
}

######################################################################
# Procedure: WARN_VOUT_UV
#   By adjusting the threshold from its current value and back,
#   create an undervoltage warning on VOUT for the specified page
######################################################################
proc WARN_VOUT_UV {pagenum} {
  global mast
  variable P_CMD_PAGE
  variable P_CMD_VOUT_UV_WARN_LIMIT

  master_write_32 $mast $P_CMD_PAGE $pagenum
  set var_default_uv_limit [master_read_32 $mast $P_CMD_VOUT_UV_WARN_LIMIT 1]
  master_write_32 $mast $P_CMD_VOUT_UV_WARN_LIMIT 0xFFF
  master_write_32 $mast $P_CMD_VOUT_UV_WARN_LIMIT $var_default_uv_limit
}

######################################################################
# Procedure: WARN_VOUT_OV
#   By adjusting the threshold from its current value and back,
#   create an overvoltage warning on VOUT for the specified page
######################################################################
proc WARN_VOUT_OV {pagenum} {
  global mast
  variable P_CMD_PAGE
  variable P_CMD_VOUT_OV_WARN_LIMIT

  master_write_32 $mast $P_CMD_PAGE $pagenum
  set var_default_uv_limit [master_read_32 $mast $P_CMD_VOUT_OV_WARN_LIMIT 1]
  master_write_32 $mast $P_CMD_VOUT_OV_WARN_LIMIT 0x001
  master_write_32 $mast $P_CMD_VOUT_OV_WARN_LIMIT $var_default_uv_limit
}

######################################################################
# Procedure: ERROR_VOUT_OV
#   By adjusting the threshold from its current value and back,
#   create an overvoltage error on VOUT for the specified page
######################################################################
proc ERROR_VOUT_OV {pagenum} {
  global mast
  variable P_CMD_PAGE
  variable P_CMD_VOUT_OV_FAULT_LIMIT

  master_write_32 $mast $P_CMD_PAGE $pagenum
  set var_default_uv_limit [master_read_32 $mast $P_CMD_VOUT_OV_FAULT_LIMIT 1]
  master_write_32 $mast $P_CMD_VOUT_OV_FAULT_LIMIT 0x002
  master_write_32 $mast $P_CMD_VOUT_OV_FAULT_LIMIT $var_default_uv_limit
}

######################################################################
# Procedure: HELP
#   Print available commands and description
######################################################################
proc help {} {
  HELP
}
proc HELP {} {

  puts "Available commands:"
  puts "  SCAN :"
  puts "     Inspect the PMBus register space for the sequencer's configuration."
  puts "  CLEAR_STATUS :"
  puts "     Clear out all latched status from the various status registers."
  puts "  SET_PAGE <page> :"
  puts "     Specify the PMBus page register in the slave device."
  puts "  SET_RETRIES <retries> :"
  puts "     Set the number of retries after an error (0-7,7=infinite)."
  puts "  SET_DELAY <delay> :"
  puts "     Enable/disable the timeout in the global response register."
  puts "  SET_TOD_ADJUST <value> :"
  puts "     Adjust the number of clock ticks per second."
  puts "  SET_TOD :"
  puts "     Sets the current Time of Day counter to system clock."
  puts "  SET_RESPONSE <page> <condition> <response>:"
  puts "     Set the VIN/VOUT over/undervoltage error condition response."
  puts "     (condition=VIN_UV|VIN_OV|VOUT_UV|VOUT_OV)"
  puts "     (response=0:continue without interruption, 2: sequence down)"
  puts "  NVLOG_ENABLE <log_level>:"
  puts "     Enables varying levels of non-volatile flash error logging"
  puts "     (0=disabled, 1=errors logged, 3= errors & blackbox status)."
  puts "  NVLOG_CLEAR :"
  puts "     Clear out all NV Flash Entries."
  puts "  READ_TOD :"
  puts "     Read the current Time of Day counter."
  puts "  READ_TOD_ADJUST :"
  puts "     Read the current Time of Day adjustment counter."
  puts "  READ_NVCFG :"
  puts "     Read the configuration of NV Logging stats."
  puts "  READ_NVLOG_ENTRY <entry> :"
  puts "     Read an entry from the NV Log."
  puts "  READ_VOUT :"
  puts "     Read the current VOUT voltage levels for all output rails."
  puts "  READ_STATUS :"
  puts "     Read the current error status, and decode values via masking."
  puts "  READ_RESPONSE :"
  puts "     Display how the sequencer will respond to various error conditions."
  puts "  ERROR_VOUT_UV <page> :"
  puts "     Send vout undervoltage error to specified page."
  puts "  WARN_VOUT_UV <page> :"
  puts "     Send vout undervoltage warning to specified page."
  puts "  WARN_VOUT_OV <page> :"
  puts "     Send vout overvoltage warning to specified page."
  puts "  ERROR_VOUT_OV <page> :"
  puts "     Send vout overvoltage error to specified page."
}


######################################################################
# STARTUP COMMANDS
######################################################################
# Scan through the pages to determine the number of rails implemented
#   by the sequencer
SCAN
puts "Info: Detected $G_VOUT_NUM sequencer output rails."
# Set the sequencer TOD clock to the system clock, if logging is enabled
if {$G_LOGGING} {
  SET_TOD
  puts "Info: Set Sequencer internal clock to system clock."
}
