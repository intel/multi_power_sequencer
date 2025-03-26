////////////////////////////////////////////////////////////////////////////////////
//
// Module: sequencer_vmonregs
//
// Description: This module implements the sequencer status registers and behavior for
//   voltage rail monitoring.
//
////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019 Intel Corporation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
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

module sequencer_vmonregs #(
  parameter                  VRAILS = 4,
  parameter                  PG_NUM = 0,
  parameter                  NV_AWIDTH = 12,
  parameter                  REQUIRE_WE_FOR_CLR = 0
)(
  input                      CLOCK,
  input                      RESET_N,
  input                      AVS_S0_READ,
  input                      AVS_S0_WRITE,
  input                [7:0] AVS_S0_ADDRESS,
  input                [3:0] AVS_S0_BYTEEN,
  output reg          [31:0] AVS_S0_READDATA,
  input               [31:0] AVS_S0_WRITEDATA,
  output reg                 AVS_S0_WAITREQUEST,
  // Optionally disable the PG Interface
  `ifndef DISABLE_PGBUS
  input         [PG_NUM-1:0] POWER_GOOD_IN,
  `endif        
  input               [13:0] ADC_VIN_LEVEL_Q,
  input      [VRAILS*14-1:0] ADC_VOUT_LEVEL_Q,
  // Optionally disable the Flash Interface
  `ifndef DISABLE_FLASH
  output reg                 NVLOG_ERROR,
  output reg                 NVLOG_BBENA,
  output reg           [7:0] NVLOG_FAULTTYPE,
  output reg           [7:0] NVLOG_FAULTPAGE,
  output reg          [31:0] NVLOG_TIMESTAMP,
  output reg  [VRAILS*2+1:0] NVLOG_BBDATA,
  input                [7:0] NVLOG_FLASHENTRIES_Q,
  output                     FLASH_ERASEPAGE,
  output reg                 FLASH_DATA_READ,
  output reg                 FLASH_DATA_WRITE,
  input                      FLASH_DATA_WAITREQUEST,
  output reg [NV_AWIDTH-1:0] FLASH_DATA_ADDRESS,
  input               [31:0] FLASH_DATA_READDATA,
  output reg          [31:0] FLASH_DATA_WRITEDATA,
  `endif        
  output                     SEQ_ENABLE,
  output                     SEQ_VIN_FAULT,
  input  reg    [VRAILS-1:0] SEQ_QUAL_FAULT,
  output reg    [VRAILS-1:0] SEQ_VRAIL_PWRGD,
  input  reg    [VRAILS-1:0] SEQ_VMON_ENA,
  output               [2:0] SEQ_RETRIES,
  output               [2:0] SEQ_TIMEOUTDLY,
  inout                      SMB_ALERTN
);

  // This file contains the thresholds and command information for the voltage monitor
  import sequencer_vmon_pkg::*;
  import sequencer_vmondecode_pkg::*;

  reg                sel_allregs;
  reg   [VRAILS-1:0] cmd_badcommand;
  reg   [VRAILS-1:0] cmd_baddata;
  reg                smbalertn_q;
  reg   [VRAILS-1:0] smbalertn_first_q;
  reg         [31:0] avs_bit_en;
  reg          [7:0] reg_page_q;
  reg                reg_page_err;
  wire  [VRAILS-1:0] reg_page_pagevalid;
  reg          [4:0] reg_clear_faults_q;
  reg                seq_vin_ready_q;
  reg   [VRAILS-1:0] seq_vout_ready_q;
  reg          [3:0] seq_qual_fault_q[VRAILS-1:0];
  reg                reg_global_resp_sel;
  reg          [5:0] reg_global_resp_q;
  reg         [11:0] reg_vin_on_q;
  reg         [11:0] reg_vin_off_q;
  reg         [11:0] reg_vout_ov_fault_limit_q[VRAILS-1:0];
  reg          [7:0] reg_vout_ov_fault_resp_q[VRAILS-1:0];
  reg         [11:0] reg_vout_ov_warn_limit_q[VRAILS-1:0];
  reg         [11:0] reg_vout_uv_warn_limit_q[VRAILS-1:0];
  reg         [11:0] reg_vout_uv_fault_limit_q[VRAILS-1:0];
  reg          [7:0] reg_vout_uv_fault_resp_q[VRAILS-1:0];
  reg         [11:0] reg_vin_ov_fault_limit_q;
  reg          [7:0] reg_vin_ov_fault_resp_q;
  reg         [11:0] reg_vin_ov_warn_limit_q;
  reg         [11:0] reg_vin_uv_warn_limit_q;
  reg         [11:0] reg_vin_uv_fault_limit_q;
  reg          [7:0] reg_vin_uv_fault_resp_q;
  reg         [11:0] reg_power_good_on_q[VRAILS-1:0];
  reg         [11:0] reg_power_good_off_q[VRAILS-1:0];
  reg   [VRAILS-1:0] reg_status_byte_unlisted;
  reg          [7:0] reg_status_byte_q[VRAILS-1:0];
  reg         [15:0] reg_status_word_q[VRAILS-1:0];
  reg   [VRAILS-1:0] reg_status_word_err;
  reg          [7:0] reg_status_vout_q[VRAILS-1:0];
  reg   [VRAILS-1:0] reg_status_vout_other_err;
  reg   [VRAILS-1:0] reg_status_vout_err;
  reg          [7:0] reg_status_input_q;
  reg                reg_status_input_other_err;
  reg                reg_status_input_err;
  reg          [7:0] reg_status_cml_q[VRAILS-1:0];
  reg   [VRAILS-1:0] reg_status_cml_err;
  reg          [7:0] reg_status_other_q[VRAILS-1:0];
  reg   [VRAILS-1:0] reg_status_other_err;
  reg         [15:0] reg_read_vin_q;
  reg         [15:0] reg_read_vout_q[VRAILS-1:0];  
  reg         [13:0] adc_vout_level_ary_q[VRAILS-1:0];
  reg  [P_SAMPLES:0] mon_vin_pwrgd;
  reg  [P_SAMPLES:0] mon_vout_pwrgd[VRAILS-1:0];
  reg  [P_SAMPLES:0] alarm_vin_ov_fault_limit_q;
  reg  [P_SAMPLES:0] alarm_vin_ov_warn_limit_q;
  reg  [P_SAMPLES:0] alarm_vin_uv_warn_limit_q;
  reg  [P_SAMPLES:0] alarm_vin_uv_fault_limit_q;
  reg  [P_SAMPLES:0] alarm_vout_ov_fault_limit_q[VRAILS-1:0];
  reg  [P_SAMPLES:0] alarm_vout_ov_warn_limit_q[VRAILS-1:0];
  reg  [P_SAMPLES:0] alarm_vout_uv_warn_limit_q[VRAILS-1:0];
  reg  [P_SAMPLES:0] alarm_vout_uv_fault_limit_q[VRAILS-1:0];
  reg         [31:0] cntr_tod_second_q;
  reg                cntr_tod_secondtc_q;
  reg         [31:0] cntr_tod_cntr_q;
  reg         [31:0] reg_mfr_tod_secondreg_q;
  reg         [31:0] reg_mfr_nv_control_q;
  reg         [ 3:0] reg_mfr_nv_master_en_q;
  reg         [ 2:0] reg_mfr_nv_page_en_q[VRAILS-1:0];
  reg         [ 4:0] nvlog_faulttype_q;
  reg                nvlog_error_2q;
  reg   [VRAILS-1:0] nvlog_error_page_ov_q;
  reg   [VRAILS-1:0] nvlog_error_page_uv_q;
  reg   [VRAILS-1:0] nvlog_error_page_qual_q;
  reg          [1:0] nvcap_error_q;
  reg          [7:0] nvcap_faultpage_q[1:0];
  reg [VRAILS*2+1:0] nvcap_bbdata;
  reg [VRAILS*2+1:0] nvcap_bbdata_q[1:0];
  reg         [31:0] flashdata_q;

  // This structure contains the supported commands and their associated data and select signals
  command_struct_t cmd_struct[P_NUMBER_COMMANDS-1:0];

  // Initialize the command structure, according to the desired level of functionality
  genvar gv_i;
  generate
    // Initialize the command structure, which is comprised of the supported commands, whether they are global or
    //   page-scoped, and deselect their address decode.
    initial begin
      cmd_struct[ 0] <= '{P_CMD_PAGE               ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[ 1] <= '{P_CMD_CLEAR_FAULTS       ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[ 2] <= '{P_CMD_VIN_ON             ,1'b1, 1'b0, 1'b0, 'b0};
      cmd_struct[ 3] <= '{P_CMD_VIN_OFF            ,1'b1, 1'b0, 1'b0, 'b0};
      cmd_struct[ 4] <= '{P_CMD_VOUT_OV_FAULT_LIMIT,1'b1, 1'b1, 1'b0, 'b0};
      cmd_struct[ 5] <= '{P_CMD_VOUT_OV_FAULT_RESP ,1'b1, 1'b1, 1'b0, 'b0};
      cmd_struct[ 6] <= '{P_CMD_VOUT_OV_WARN_LIMIT ,1'b1, 1'b1, 1'b0, 'b0};
      cmd_struct[ 7] <= '{P_CMD_VOUT_UV_WARN_LIMIT ,1'b1, 1'b1, 1'b0, 'b0};
      cmd_struct[ 8] <= '{P_CMD_VOUT_UV_FAULT_LIMIT,1'b1, 1'b1, 1'b0, 'b0};
      cmd_struct[ 9] <= '{P_CMD_VOUT_UV_FAULT_RESP ,1'b1, 1'b1, 1'b1, 'b0};
      cmd_struct[10] <= '{P_CMD_VIN_OV_FAULT_LIMIT ,1'b1, 1'b0, 1'b0, 'b0};
      cmd_struct[11] <= '{P_CMD_VIN_OV_FAULT_RESP  ,1'b1, 1'b0, 1'b0, 'b0};
      cmd_struct[12] <= '{P_CMD_VIN_OV_WARN_LIMIT  ,1'b1, 1'b0, 1'b0, 'b0};
      cmd_struct[13] <= '{P_CMD_VIN_UV_WARN_LIMIT  ,1'b1, 1'b0, 1'b0, 'b0};
      cmd_struct[14] <= '{P_CMD_VIN_UV_FAULT_LIMIT ,1'b1, 1'b0, 1'b0, 'b0};
      cmd_struct[15] <= '{P_CMD_VIN_UV_FAULT_RESP  ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[16] <= '{P_CMD_POWER_GOOD_ON      ,1'b1, 1'b1, 1'b0, 'b0};
      cmd_struct[17] <= '{P_CMD_POWER_GOOD_OFF     ,1'b1, 1'b1, 1'b0, 'b0};
      cmd_struct[18] <= '{P_CMD_STATUS_BYTE        ,1'b1, 1'b1, 1'b1, 'b0};
      cmd_struct[19] <= '{P_CMD_STATUS_WORD        ,1'b1, 1'b1, 1'b1, 'b0};
      cmd_struct[20] <= '{P_CMD_STATUS_VOUT        ,1'b1, 1'b1, 1'b1, 'b0};
      cmd_struct[21] <= '{P_CMD_STATUS_INPUT       ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[22] <= '{P_CMD_STATUS_CML         ,1'b1, 1'b1, 1'b1, 'b0};
      cmd_struct[23] <= '{P_CMD_STATUS_OTHER       ,1'b1, 1'b1, 1'b1, 'b0};
      cmd_struct[24] <= '{P_CMD_READ_VIN           ,1'b1, 1'b0, 1'b0, 'b0};
      cmd_struct[25] <= '{P_CMD_READ_VOUT          ,1'b1, 1'b1, 1'b0, 'b0};
      cmd_struct[26] <= '{P_CMD_MFR_TOD            ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[27] <= '{P_CMD_MFR_TOD_ADJUST     ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[28] <= '{P_CMD_MFR_NV_CONTROL     ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[29] <= '{P_CMD_MFR_NV_MASTER_EN   ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[30] <= '{P_CMD_MFR_NV_PAGE_EN     ,1'b1, 1'b1, 1'b1, 'b0};
      cmd_struct[31] <= '{P_CMD_MFR_NV_ERRLOG_DAT  ,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[32] <= '{P_CMD_MFR_NV_ERRLOG_BBDAT,1'b1, 1'b0, 1'b1, 'b0};
      cmd_struct[33] <= '{P_CMD_MFR_NV_ERRLOG_TOD  ,1'b1, 1'b0, 1'b1, 'b0};
      // If we are hard-coding the thresholds, we can disable these registers
      if (P_MONITOR_FUNCT_LEVEL == 1)
      begin
        cmd_struct[ 2].enable <= 1'b0; // Disable P_CMD_VIN_ON
        cmd_struct[ 3].enable <= 1'b0; // Disable P_CMD_VIN_OFF
        cmd_struct[ 4].enable <= 1'b0; // Disable P_CMD_VOUT_OV_FAULT_LIMIT
        cmd_struct[ 6].enable <= 1'b0; // Disable P_CMD_VOUT_OV_WARN_LIMIT
        cmd_struct[ 7].enable <= 1'b0; // Disable P_CMD_VOUT_UV_WARN_LIMIT
        cmd_struct[ 8].enable <= 1'b0; // Disable P_CMD_VOUT_UV_FAULT_LIMIT
        cmd_struct[10].enable <= 1'b0; // Disable P_CMD_VIN_OV_FAULT_LIMIT
        cmd_struct[12].enable <= 1'b0; // Disable P_CMD_VIN_OV_WARN_LIMIT
        cmd_struct[13].enable <= 1'b0; // Disable P_CMD_VIN_UV_WARN_LIMIT
        cmd_struct[14].enable <= 1'b0; // Disable P_CMD_VIN_UV_FAULT_LIMIT
        cmd_struct[16].enable <= 1'b0; // Disable P_CMD_POWER_GOOD_ON
        cmd_struct[17].enable <= 1'b0; // Disable P_CMD_POWER_GOOD_OFF
      end
      // If we are not logging any data, we can disable these registers
      if (P_LOGGING_FUNCT_LEVEL == 0)
      begin
        cmd_struct[26].enable <= 1'b0; //Disable P_CMD_MFR_TOD
        cmd_struct[27].enable <= 1'b0; //Disable P_CMD_MFR_TOD_ADJUST
        cmd_struct[28].enable <= 1'b0; //Disable P_CMD_MFR_NV_CONTROL
        cmd_struct[29].enable <= 1'b0; //Disable P_CMD_MFR_NV_MASTER_EN
        cmd_struct[30].enable <= 1'b0; //Disable P_CMD_MFR_NV_PAGE_EN
        cmd_struct[31].enable <= 1'b0; //Disable P_CMD_MFR_NV_ERRLOG_DAT
        cmd_struct[32].enable <= 1'b0; //Disable P_CMD_MFR_NV_ERRLOG_BBDAT
        cmd_struct[33].enable <= 1'b0; //Disable P_CMD_MFR_NV_ERRLOG_TOD
      end
      // If we are not recording blackbox data, we can disable these registers
      if (P_LOGGING_FUNCT_LEVEL == 1)
      begin
        cmd_struct[32].enable <= 1'b0; //Disable P_CMD_MFR_NV_ERRLOG_BBDAT
      end
      // Are we only monitoring VIN?  If so, disable VOUT commands.
      if ((P_VRAIL_SEL[1:VRAILS] == 0) && (P_VRAIL_SEL[0] == 1'b1))
      begin
        cmd_struct[ 5].enable <= 1'b0; // Disable P_CMD_VOUT_OV_FAULT_RESP 
        cmd_struct[25].enable <= 1'b0; // Disable P_CMD_READ_VOUT          
        cmd_struct[ 4].enable <= 1'b0; // Disable P_CMD_VOUT_OV_FAULT_LIMIT
        cmd_struct[ 6].enable <= 1'b0; // Disable P_CMD_VOUT_OV_WARN_LIMIT 
        cmd_struct[ 7].enable <= 1'b0; // Disable P_CMD_VOUT_UV_WARN_LIMIT 
        cmd_struct[ 8].enable <= 1'b0; // Disable P_CMD_VOUT_UV_FAULT_LIMIT
        cmd_struct[16].enable <= 1'b0; // Disable P_CMD_POWER_GOOD_ON      
        cmd_struct[17].enable <= 1'b0; // Disable P_CMD_POWER_GOOD_OFF     
      end
      // Are we only monitoring VOUT?  If so, disable VIN commands.
      if (P_VRAIL_SEL[0] == 1'b0)
      begin
        cmd_struct[11].enable <= 1'b0; // Disable P_CMD_VIN_OV_FAULT_RESP  
        cmd_struct[24].enable <= 1'b0; // Disable P_CMD_READ_VIN           
        cmd_struct[ 2].enable <= 1'b0; // Disable P_CMD_VIN_ON
        cmd_struct[ 3].enable <= 1'b0; // Disable P_CMD_VIN_OFF
        cmd_struct[10].enable <= 1'b0; // Disable P_CMD_VIN_OV_FAULT_LIMIT
        cmd_struct[12].enable <= 1'b0; // Disable P_CMD_VIN_OV_WARN_LIMIT
        cmd_struct[13].enable <= 1'b0; // Disable P_CMD_VIN_UV_WARN_LIMIT
        cmd_struct[14].enable <= 1'b0; // Disable P_CMD_VIN_UV_FAULT_LIMIT
      end
    end
  endgenerate

  // Functions to compare input address against a constant address and return the correct select signal
  function bit unsigned address_compare(input bit [7:0] ADDR_IN, VALUE);
    if (ADDR_IN == VALUE) return 1'b1; else return 1'b0;
  endfunction
  function bit unsigned [VRAILS-1:0] address_compare_page(input bit [7:0] PAGE, input bit [7:0] ADDR_IN, VALUE);
    if (ADDR_IN == VALUE) return 1'b1 << PAGE; else return 'b0;
  endfunction

  // Generate select signals for registers
  always @* begin : P_RegSelects
    sel_allregs = 1'b0;
    // Loop through all supported commands and generate the address selects
    for (int i=0; i<P_NUMBER_COMMANDS; i++) begin
      // By default, clear down all selects
      cmd_struct[i].select = 'b0;
      // Has the command been disabled for optimization?
      if (cmd_struct[i].enable == 1) begin
        // Is the command global in scope?
        if (cmd_struct[i].multipage == 0) begin
          cmd_struct[i].select[VRAILS-1:1] = 'b0;
          cmd_struct[i].select[0] = address_compare(AVS_S0_ADDRESS, cmd_struct[i].command);
          // Accumulate the select signals to determine if the command is decoded by the supported command set.
          sel_allregs             = sel_allregs || cmd_struct[i].select[0];
        end
        // The command multi-page in scope.  Loop through the number of VOUT rails
        else begin
          // Is the command applicable for this vrail type?
          if ((P_VRAIL_SEL[reg_page_q+1] == 1) | (cmd_struct[i].railtype == 1'b1))
            cmd_struct[i].select = address_compare_page(reg_page_q, AVS_S0_ADDRESS, cmd_struct[i].command);
          // Accumulate the select signals to determine if the command is decoded by the supported command set.
          sel_allregs             = sel_allregs || ((cmd_struct[i].select == 0) ? 1'b0 : 1'b1);
        end
      end
    end
  end : P_RegSelects

  // Assign the correct data to the AVMM readdata output
  always @* begin : avs_tx_combinatorial
    // Set default values for Flash data interface
    AVS_S0_WAITREQUEST <= 1'b0;
    `ifndef DISABLE_FLASH
    FLASH_DATA_READ    <= 1'b0;
    FLASH_DATA_ADDRESS <=  'b0;
    `endif        
    // Generate the output data for read accesses
    case (AVS_S0_ADDRESS)
      P_CMD_PAGE                : AVS_S0_READDATA    <= {24'b0, reg_page_q};
      P_CMD_VIN_ON              : AVS_S0_READDATA    <= {20'b0, reg_vin_on_q};
      P_CMD_VIN_OFF             : AVS_S0_READDATA    <= {20'b0, reg_vin_off_q};
      P_CMD_VOUT_OV_FAULT_LIMIT : AVS_S0_READDATA    <= {20'b0, reg_vout_ov_fault_limit_q[reg_page_q]};
      P_CMD_VOUT_OV_FAULT_RESP  : AVS_S0_READDATA    <= {24'b0, reg_vout_ov_fault_resp_q[reg_page_q][7:6], reg_global_resp_q[5:0]};
      P_CMD_VOUT_OV_WARN_LIMIT  : AVS_S0_READDATA    <= {20'b0, reg_vout_ov_warn_limit_q[reg_page_q]};
      P_CMD_VOUT_UV_WARN_LIMIT  : AVS_S0_READDATA    <= {20'b0, reg_vout_uv_warn_limit_q[reg_page_q]};
      P_CMD_VOUT_UV_FAULT_LIMIT : AVS_S0_READDATA    <= {20'b0, reg_vout_uv_fault_limit_q[reg_page_q]};
      P_CMD_VOUT_UV_FAULT_RESP  : AVS_S0_READDATA    <= {24'b0, reg_vout_uv_fault_resp_q[reg_page_q][7:6], reg_global_resp_q[5:0]};
      P_CMD_VIN_OV_FAULT_LIMIT  : AVS_S0_READDATA    <= {20'b0, reg_vin_ov_fault_limit_q};
      P_CMD_VIN_OV_FAULT_RESP   : AVS_S0_READDATA    <= {24'b0, reg_vin_ov_fault_resp_q[7:6], reg_global_resp_q[5:0]};
      P_CMD_VIN_OV_WARN_LIMIT   : AVS_S0_READDATA    <= {20'b0, reg_vin_ov_warn_limit_q};
      P_CMD_VIN_UV_WARN_LIMIT   : AVS_S0_READDATA    <= {20'b0, reg_vin_uv_warn_limit_q};
      P_CMD_VIN_UV_FAULT_LIMIT  : AVS_S0_READDATA    <= {20'b0, reg_vin_uv_fault_limit_q};
      P_CMD_VIN_UV_FAULT_RESP   : AVS_S0_READDATA    <= {24'b0, reg_vin_uv_fault_resp_q[7:6], reg_global_resp_q[5:0]};
      P_CMD_POWER_GOOD_ON       : AVS_S0_READDATA    <= {20'b0, reg_power_good_on_q[reg_page_q]};
      P_CMD_POWER_GOOD_OFF      : AVS_S0_READDATA    <= {20'b0, reg_power_good_off_q[reg_page_q]};
      P_CMD_STATUS_BYTE         : AVS_S0_READDATA    <= {24'b0, reg_status_byte_q[reg_page_q]};
      P_CMD_STATUS_WORD         : AVS_S0_READDATA    <= {16'b0, reg_status_word_q[reg_page_q]};
      P_CMD_STATUS_VOUT         : AVS_S0_READDATA    <= {16'b0, reg_status_vout_q[reg_page_q]};
      P_CMD_STATUS_INPUT        : AVS_S0_READDATA    <= {16'b0, reg_status_input_q};
      P_CMD_STATUS_CML          : AVS_S0_READDATA    <= {16'b0, reg_status_cml_q[reg_page_q]};
      P_CMD_STATUS_OTHER        : AVS_S0_READDATA    <= {16'b0, reg_status_other_q[reg_page_q]};
      P_CMD_READ_VIN            : AVS_S0_READDATA    <= {16'b0, reg_read_vin_q};
      P_CMD_READ_VOUT           : AVS_S0_READDATA    <= {16'b0, reg_read_vout_q[reg_page_q]};
      P_CMD_MFR_TOD             : AVS_S0_READDATA    <= {cntr_tod_cntr_q};
      P_CMD_MFR_TOD_ADJUST      : AVS_S0_READDATA    <= {reg_mfr_tod_secondreg_q};
      P_CMD_MFR_NV_CONTROL      : AVS_S0_READDATA    <= {reg_mfr_nv_control_q};
      P_CMD_MFR_NV_MASTER_EN    : AVS_S0_READDATA    <= {28'b0, reg_mfr_nv_master_en_q};
      P_CMD_MFR_NV_PAGE_EN      : AVS_S0_READDATA    <= {29'b0, reg_mfr_nv_page_en_q[reg_page_q]};
      `ifndef DISABLE_FLASH
      // This command reads data from flash, so we need to perform the read and pass
      //   through waitrequest to qualify readdata.
      P_CMD_MFR_NV_ERRLOG_DAT   : begin
                                  FLASH_DATA_READ    <= AVS_S0_READ;
                                  FLASH_DATA_ADDRESS <= (P_OFFSET_LOG | reg_mfr_nv_control_q[23:16] << 1) << 2;
                                  AVS_S0_READDATA    <= FLASH_DATA_READDATA;
                                  AVS_S0_WAITREQUEST <= FLASH_DATA_WAITREQUEST;
      end
      // This command reads data from flash, so we need to perform the read and pass
      //   through waitrequest to qualify readdata.
      P_CMD_MFR_NV_ERRLOG_BBDAT : begin
                                  FLASH_DATA_READ    <= AVS_S0_READ;
                                  FLASH_DATA_ADDRESS <= (P_OFFSET_BBDATA | (reg_mfr_nv_control_q[23:16] << 4) | reg_mfr_nv_control_q[7:4]) << 2;
                                  AVS_S0_READDATA    <= FLASH_DATA_READDATA;
                                  AVS_S0_WAITREQUEST <= FLASH_DATA_WAITREQUEST;
      end
      // This command reads data from flash, so we need to perform the read and pass
      //   through waitrequest to qualify readdata.
      P_CMD_MFR_NV_ERRLOG_TOD   : begin
                                  FLASH_DATA_READ    <= AVS_S0_READ;
                                  FLASH_DATA_ADDRESS <= (P_OFFSET_LOG | (reg_mfr_nv_control_q[23:16] << 1) | 1'b1) << 2;
                                  AVS_S0_READDATA    <= FLASH_DATA_READDATA;
                                  AVS_S0_WAITREQUEST <= FLASH_DATA_WAITREQUEST;
      end
      `endif        
      default                   : AVS_S0_READDATA    <= {32'b0};
    endcase
  end : avs_tx_combinatorial

  // Only generate the required registers for the desired level of functionality
  generate
    // Implement the page register for the reduced feature set ("Hard-Coded Thresholds), and full-featured design
    if ((P_MONITOR_FUNCT_LEVEL == 1) || (P_MONITOR_FUNCT_LEVEL == 2))
    begin
      // Instantiate VRAIL_PAGE register
      reg_rw_page #(.P_WIDTH(8),
                    .VRAILS(VRAILS))
      U_VRAIL_PAGE(
                    .CLOCK(CLOCK),
                    .RESET_N(RESET_N),
                    .INIT(P_DEFAULT_PAGE[7:0]),
                    .VALID_PAGE(reg_page_pagevalid),
                    .REG_SELECT(cmd_struct[ 0].select[0]),
                    .REG_WRITE(AVS_S0_WRITE),
                    .DATA_IN(AVS_S0_WRITEDATA[7:0]),
                    .ALARM_OUT(reg_page_err),
                    .DATA_OUT_Q(reg_page_q));

      // Send vector of valid values to page register.  Since the bus is 0:n instead of n:0, flip bits
      assign reg_page_pagevalid = {(VRAILS){1'b1}};
      // Create vector of bit enables for register accesses
      for (gv_i=0; gv_i<32; gv_i++) begin : P_GenBitEna
        assign avs_bit_en[gv_i] = AVS_S0_BYTEEN[gv_i/8];
      end

      // Instantiate Response Retry / Timeout register.  This is shared across ALL pages and responses
      reg_rw #(.P_WIDTH(6))
      U_GLOBAL_RESP(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT({P_RETRY_ATTEMPTS[2:0], P_RETRY_TIMEOUT[2:0]}),
               .REG_SELECT(reg_global_resp_sel),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[5:0]),
               .DATA_IN(AVS_S0_WRITEDATA[5:0]),
               .DATA_OUT_Q(reg_global_resp_q));
      // OR together the select lines from all response registers
      assign reg_global_resp_sel = (cmd_struct[ 5].select[reg_page_q] || cmd_struct[ 9].select[reg_page_q] || cmd_struct[11].select[0] || cmd_struct[15].select[0]) ? 1'b1 : 1'b0;
    end
    else begin
      assign reg_page_q        = 8'b0;
      assign reg_page_err      = 1'b0;
      assign reg_global_resp_q = {P_RETRY_ATTEMPTS, P_RETRY_TIMEOUT};
    end

    // Implement the threshold registers for the full-featured design
    if ((P_VRAIL_SEL[0] == 1) && (P_MONITOR_FUNCT_LEVEL == 2))
    begin
      // Instantiate VIN_ON register
      reg_rw #(.P_WIDTH(12))
      U_VIN_ON(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT(P_VIN_ON),
               .REG_SELECT(cmd_struct[ 2].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[11:0]),
               .DATA_IN(AVS_S0_WRITEDATA[11:0]),
               .DATA_OUT_Q(reg_vin_on_q));
    
      // Instantiate VIN_OFF register
      reg_rw #(.P_WIDTH(12))
      U_VIN_OFF(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT(P_VIN_OFF),
               .REG_SELECT(cmd_struct[ 3].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[11:0]),
               .DATA_IN(AVS_S0_WRITEDATA[11:0]),
               .DATA_OUT_Q(reg_vin_off_q));
    
      // Instantiate VIN_OV_FAULT_LIMIT register
      reg_rw #(.P_WIDTH(12))
      U_VIN_OV_FAULT_LIMIT(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT(P_VIN_OV_FAULT_LIMIT),
               .REG_SELECT(cmd_struct[10].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[11:0]),
               .DATA_IN(AVS_S0_WRITEDATA[11:0]),
               .DATA_OUT_Q(reg_vin_ov_fault_limit_q));
    
      // Instantiate VIN_OV_WARN_LIMIT register
      reg_rw #(.P_WIDTH(12))
      U_VIN_OV_WARN_LIMIT(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT(P_VIN_OV_WARN_LIMIT),
               .REG_SELECT(cmd_struct[12].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[11:0]),
               .DATA_IN(AVS_S0_WRITEDATA[11:0]),
               .DATA_OUT_Q(reg_vin_ov_warn_limit_q));
    
      // Instantiate VIN_UV_WARN_LIMIT register
      reg_rw #(.P_WIDTH(12))
      U_VIN_UV_WARN_LIMIT(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT(P_VIN_UV_WARN_LIMIT),
               .REG_SELECT(cmd_struct[13].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[11:0]),
               .DATA_IN(AVS_S0_WRITEDATA[11:0]),
               .DATA_OUT_Q(reg_vin_uv_warn_limit_q));
    
      // Instantiate VIN_UV_FAULT_LIMIT register
      reg_rw #(.P_WIDTH(12))
      U_VIN_UV_FAULT_LIMIT(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT(P_VIN_UV_FAULT_LIMIT),
               .REG_SELECT(cmd_struct[14].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[11:0]),
               .DATA_IN(AVS_S0_WRITEDATA[11:0]),
               .DATA_OUT_Q(reg_vin_uv_fault_limit_q));
    
    end
    // For the design with no PMBus interface, or the reduced feature set ("Hard-Coded Thresholds),
    //   hard-code the thresholds to the specified values in the package file
    else begin
      assign reg_vin_on_q             = P_VIN_ON;
      assign reg_vin_off_q            = P_VIN_OFF;
      assign reg_vin_ov_fault_limit_q = P_VIN_OV_FAULT_LIMIT;
      assign reg_vin_ov_warn_limit_q  = P_VIN_OV_WARN_LIMIT;
      assign reg_vin_uv_warn_limit_q  = P_VIN_UV_WARN_LIMIT;
      assign reg_vin_uv_fault_limit_q = P_VIN_UV_FAULT_LIMIT;
    end
    // Implement the response and status registers for the reduced feature set ("Hard-Coded Thresholds),
    //   and full-featured design
    if ((P_MONITOR_FUNCT_LEVEL == 1) || (P_MONITOR_FUNCT_LEVEL == 2))
    begin
      // Instantiate VIN_UV_FAULT_RESP register
      reg_rw #(.P_WIDTH(8))
      U_VIN_UV_FAULT_RESP(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT(P_VIN_UV_FAULT_RESP),
               .REG_SELECT(cmd_struct[15].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[7:0]),
               .DATA_IN(AVS_S0_WRITEDATA[7:0]),
               .DATA_OUT_Q(reg_vin_uv_fault_resp_q));
    
      // Instantiate STATUS_INPUT register
      reg_wtc #(.P_WIDTH(8))
      U_STATUS_INPUT(
               .CLOCK(CLOCK),
                .RESET_N(RESET_N && ~reg_clear_faults_q[4]),
                .INIT(8'b0),
                .REG_SELECT(cmd_struct[21].select[0]),
                .REG_WRITE(AVS_S0_WRITE),
                .DATA_IN(AVS_S0_WRITEDATA[7:0]),
                .ALARM_IN({alarm_vin_ov_fault_limit_q[P_SAMPLES], alarm_vin_ov_warn_limit_q[P_SAMPLES],
                           alarm_vin_uv_warn_limit_q[P_SAMPLES], alarm_vin_uv_fault_limit_q[P_SAMPLES],
                           ~mon_vin_pwrgd[P_SAMPLES], 3'b0}),
                .DATA_OUT_Q(reg_status_input_q));

      // Is the VIN rail being monitored by the ADC?  These are analog-only commands.
      if (P_VRAIL_SEL[0] == 1)
      begin
        // Instantiate VIN_OV_FAULT_RESP register
        reg_rw #(.P_WIDTH(8))
        U_VIN_OV_FAULT_RESP(
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(P_VIN_OV_FAULT_RESP),
                 .REG_SELECT(cmd_struct[11].select[0]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[7:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[7:0]),
                 .DATA_OUT_Q(reg_vin_ov_fault_resp_q));

        // Instantiate READ_VIN register
        reg_ro #(.P_WIDTH(16))
        U_READ_VIN(
                 .CLOCK(CLOCK),
                  .REG_SELECT(cmd_struct[24].select[0]),
                  .REG_READ(AVS_S0_READ),
                  .DATA_IN({4'b0,ADC_VIN_LEVEL_Q[11:0]}),
                  .DATA_OUT_Q(reg_read_vin_q));
      
      end
      else begin
        assign reg_read_vin_q          = 16'b0;
        assign reg_vin_ov_fault_resp_q = P_VIN_OV_FAULT_RESP;
      end
    end
    // For the design with no PMBus interface, or the reduced feature set ("Hard-Coded Thresholds),
    //   hard-code the responses to the specified values in the package file
    else begin
      assign reg_status_input_q      =  8'b0;
      assign reg_read_vin_q          = 16'b0;
      assign reg_vin_ov_fault_resp_q = P_VIN_OV_FAULT_RESP;
      assign reg_vin_uv_fault_resp_q = P_VIN_UV_FAULT_RESP;
    end
    assign reg_status_input_other_err = ((reg_status_input_q[7:5] == 3'b0 ) && (reg_status_input_q[3] == 1'b0 ))? 1'b0:1'b1;
    assign reg_status_input_err       = (reg_status_input_q      == 8'b0 )? 1'b0:1'b1;

    // Implement data logging functionality
    if ((P_LOGGING_FUNCT_LEVEL == 1) || (P_LOGGING_FUNCT_LEVEL == 2))
    begin
      // Implement Time of Day Counter
      reg_cntr_rw #(.P_WIDTH(32))
      U_MFR_TOD(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INCREMENT(cntr_tod_secondtc_q),
               .REG_SELECT(cmd_struct[26].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .DATA_IN(AVS_S0_WRITEDATA[31:0]),
               .DATA_OUT_Q(cntr_tod_cntr_q));
      // Implement Second Counter
      reg_rw #(.P_WIDTH(32))
      U_MFR_TOD_ADJUST(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT(P_CLOCK_RATE_CLK),
               .REG_SELECT(cmd_struct[27].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en),
               .DATA_IN(AVS_S0_WRITEDATA[31:0]),
               .DATA_OUT_Q(reg_mfr_tod_secondreg_q));
      // NV Flash Control, RW bits 23:16 and 7:4
      reg_rw #(.P_WIDTH(12))
      U_MFR_NV_CONTROL_RW(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT('0),
               .REG_SELECT(cmd_struct[28].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA({avs_bit_en[23:16],avs_bit_en[7:4]}),
               .DATA_IN({AVS_S0_WRITEDATA[23:16],AVS_S0_WRITEDATA[7:4]}),
               .DATA_OUT_Q({reg_mfr_nv_control_q[23:16],reg_mfr_nv_control_q[7:4]}));
      reg_oneshot #(.P_WIDTH(1))
      // NV Flash Control, 1S register bit 0 (for erasing flash error log)
      U_MFR_NV_CONTROL_1S(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .REG_SELECT(cmd_struct[28].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[0]),
               .DATA_IN(AVS_S0_WRITEDATA[0]),
               .ACK_IN(reg_mfr_nv_control_q[0]),
               .DATA_OUT_Q(reg_mfr_nv_control_q[0]));
     `ifndef DISABLE_FLASH
      assign reg_mfr_nv_control_q[31:24] = NVLOG_FLASHENTRIES_Q;
      assign FLASH_ERASEPAGE = reg_mfr_nv_control_q[0];
     `endif
      assign reg_mfr_nv_control_q[15: 8] = 8'h0;
      assign reg_mfr_nv_control_q[ 3: 1] = 3'h0;
      // NV Flash Master and Non-Paged Enable
      reg_rw #(.P_WIDTH(4))
      U_MFR_NV_MASTER_EN(
               .CLOCK(CLOCK),
               .RESET_N(RESET_N),
               .INIT({2'h3, P_LOGGING_ENA[1:0]}),
               .REG_SELECT(cmd_struct[29].select[0]),
               .REG_WRITE(AVS_S0_WRITE),
               .REG_ENA(avs_bit_en[3:0]),
               .DATA_IN(AVS_S0_WRITEDATA[3:0]),
               .DATA_OUT_Q(reg_mfr_nv_master_en_q));
    end
    else begin
      assign cntr_tod_cntr_q             = 'b0;
      assign reg_mfr_tod_secondreg_q     = 'b0;
      assign reg_mfr_nv_control_q        = 'b0;
      assign reg_mfr_nv_master_en_q      = 'b0;
    end

  endgenerate

  generate
    // Instantiate a PAGE of registers per power rail
    for (gv_i=0; gv_i<VRAILS; gv_i=gv_i+1) begin: G_PAGEREGS
      // Implement the threshold registers for the full-featured design
      if ((P_VRAIL_SEL[gv_i+1] == 1) && (P_MONITOR_FUNCT_LEVEL == 2))
      begin
        // Instantiate VOUT_OV_FAULT_LIMIT register
        reg_rw #(.P_WIDTH(12))
        U_VOUT_OV_FAULT_LIMIT(
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(P_VOUT_OV_FAULT_LIMIT[gv_i]),
                 .REG_SELECT(cmd_struct[ 4].select[gv_i]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[11:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[11:0]),
                 .DATA_OUT_Q(reg_vout_ov_fault_limit_q[gv_i]));
  
        // Instantiate VOUT_OV_WARN_LIMIT register
        reg_rw #(.P_WIDTH(12))
        U_VOUT_OV_WARN_LIMIT(
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(P_VOUT_OV_WARN_LIMIT[gv_i]),
                 .REG_SELECT(cmd_struct[ 6].select[gv_i]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[11:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[11:0]),
                 .DATA_OUT_Q(reg_vout_ov_warn_limit_q[gv_i]));
  
        // Instantiate VOUT_UV_WARN_LIMIT register
        reg_rw #(.P_WIDTH(12))
        U_VOUT_UV_WARN_LIMIT(
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(P_VOUT_UV_WARN_LIMIT[gv_i]),
                 .REG_SELECT(cmd_struct[ 7].select[gv_i]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[11:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[11:0]),
                 .DATA_OUT_Q(reg_vout_uv_warn_limit_q[gv_i]));
  
        // Instantiate VOUT_UV_FAULT_LIMIT register
        reg_rw #(.P_WIDTH(12))
        U_VOUT_UV_FAULT_LIMIT(
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(P_VOUT_UV_FAULT_LIMIT[gv_i]),
                 .REG_SELECT(cmd_struct[ 8].select[gv_i]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[11:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[11:0]),
                 .DATA_OUT_Q(reg_vout_uv_fault_limit_q[gv_i]));
  
        // Instantiate POWER_GOOD_ON register
        reg_rw #(.P_WIDTH(12))
        U_POWER_GOOD_ON(
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(P_POWER_GOOD_ON[gv_i]),
                 .REG_SELECT(cmd_struct[16].select[gv_i]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[11:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[11:0]),
                 .DATA_OUT_Q(reg_power_good_on_q[gv_i]));
  
        // Instantiate POWER_GOOD_OFF register
        reg_rw #(.P_WIDTH(12))
        U_POWER_GOOD_OFF(
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(P_POWER_GOOD_OFF[gv_i]),
                 .REG_SELECT(cmd_struct[17].select[gv_i]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[11:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[11:0]),
                 .DATA_OUT_Q(reg_power_good_off_q[gv_i]));
      end
      // For the design with no PMBus interface, or the reduced feature set ("Hard-Coded Thresholds),
      //   hard-code the thresholds to the specified values in the package file
      else begin
        assign reg_vout_ov_fault_limit_q[gv_i] = P_VOUT_OV_FAULT_LIMIT[gv_i];
        assign reg_vout_ov_warn_limit_q[gv_i]  = P_VOUT_OV_WARN_LIMIT[gv_i];
        assign reg_vout_uv_warn_limit_q[gv_i]  = P_VOUT_UV_WARN_LIMIT[gv_i];
        assign reg_vout_uv_fault_limit_q[gv_i] = P_VOUT_UV_FAULT_LIMIT[gv_i];
        assign reg_power_good_on_q[gv_i]       = P_POWER_GOOD_ON[gv_i];
        assign reg_power_good_off_q[gv_i]      = P_POWER_GOOD_OFF[gv_i];
      end

      // Implement the VOUT response and status registers for the reduced feature set ("Hard-Coded Thresholds),
      //   and full-featured design
      if (((P_MONITOR_FUNCT_LEVEL == 1) || (P_MONITOR_FUNCT_LEVEL == 2)))
      begin
        // Instantiate VOUT_UV_FAULT_RESP register - this should be present for both
        //   digital and analog modes
        reg_rw #(.P_WIDTH(8))
        U_VOUT_UV_FAULT_RESP(
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(P_VOUT_UV_FAULT_RESP[gv_i]),
                 .REG_SELECT(cmd_struct[ 9].select[gv_i]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[7:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[7:0]),
                 .DATA_OUT_Q(reg_vout_uv_fault_resp_q[gv_i]));

        // Instantiate STATUS_VOUT register
        reg_wtc #(.P_WIDTH(8))
        U_STATUS_VOUT(
                  .CLOCK(CLOCK),
                  .RESET_N(RESET_N && ~reg_clear_faults_q[4]),
                  .INIT(8'b0),
                  .REG_SELECT(cmd_struct[20].select[gv_i]),
                  .REG_WRITE(AVS_S0_WRITE),
                  .DATA_IN(AVS_S0_WRITEDATA[7:0]),
                  .ALARM_IN({alarm_vout_ov_fault_limit_q[gv_i][P_SAMPLES], alarm_vout_ov_warn_limit_q[gv_i][P_SAMPLES],
                             alarm_vout_uv_warn_limit_q[gv_i][P_SAMPLES], alarm_vout_uv_fault_limit_q[gv_i][P_SAMPLES],
                             4'b0}),
                  .DATA_OUT_Q(reg_status_vout_q[gv_i]));
        assign reg_status_vout_other_err[gv_i] = (reg_status_vout_q[gv_i][6:4] == 3'b0 )? 1'b0:1'b1;
        assign reg_status_vout_err[gv_i]       = (reg_status_vout_q[gv_i]      == 8'b0 )? 1'b0:1'b1;

        // Is the VOUT rail being monitored by the ADC?
        if (P_VRAIL_SEL[gv_i+1] == 1)
        begin
          // Instantiate VOUT_OV_FAULT_RESP register
          reg_rw #(.P_WIDTH(8))
          U_VOUT_OV_FAULT_RESP(
                   .CLOCK(CLOCK),
                   .RESET_N(RESET_N),
                   .INIT(P_VOUT_OV_FAULT_RESP[gv_i]),
                   .REG_SELECT(cmd_struct[ 5].select[gv_i]),
                   .REG_WRITE(AVS_S0_WRITE),
                   .REG_ENA(avs_bit_en[7:0]),
                   .DATA_IN(AVS_S0_WRITEDATA[7:0]),
                   .DATA_OUT_Q(reg_vout_ov_fault_resp_q[gv_i]));

          // Instantiate READ_VOUT register
          reg_ro #(.P_WIDTH(16))
          U_READ_VOUT(
                   .CLOCK(CLOCK),
                    .REG_SELECT(cmd_struct[25].select[gv_i]),
                    .REG_READ(AVS_S0_READ),
                    .DATA_IN({4'b0,adc_vout_level_ary_q[gv_i][11:0]}),
                    .DATA_OUT_Q(reg_read_vout_q[gv_i]));

        end
        else begin
          assign reg_read_vout_q[gv_i]          = 16'b0;
          assign reg_vout_ov_fault_resp_q[gv_i] = P_VOUT_OV_FAULT_RESP[gv_i];
        end
      end
      // For the design with no PMBus interface, or the reduced feature set ("Hard-Coded Thresholds),
      //   hard-code the responses to the specified values in the package file
      else begin
        assign reg_status_vout_q[gv_i]        =  8'b0;
        assign reg_read_vout_q[gv_i]          = 16'b0;
        assign reg_vout_ov_fault_resp_q[gv_i] = P_VOUT_OV_FAULT_RESP[gv_i];
        assign reg_vout_uv_fault_resp_q[gv_i] = P_VOUT_UV_FAULT_RESP[gv_i];
      end

      // Implement the status registers for the reduced feature set ("Hard-Coded Thresholds),
      //   and full-featured design
      if ((P_MONITOR_FUNCT_LEVEL == 1) || (P_MONITOR_FUNCT_LEVEL == 2))
      begin
        // Instantiate STATUS_BYTE register
        reg_ro #(.P_WIDTH(8))
        U_STATUS_BYTE(
                 .CLOCK(CLOCK),
                  .REG_SELECT(cmd_struct[18].select[gv_i]),
                  .REG_READ(AVS_S0_READ),
                  .DATA_IN({1'b0, ~SEQ_VMON_ENA[gv_i], reg_status_vout_q[gv_i][7], 1'b0, reg_status_input_q[4], 1'b0, reg_status_cml_err[gv_i], reg_status_byte_unlisted[gv_i]}),
                  .DATA_OUT_Q(reg_status_byte_q[gv_i]));
        assign reg_status_byte_unlisted[gv_i] = reg_status_vout_other_err[gv_i] || reg_status_other_err[gv_i] || reg_status_input_other_err;

        // Instantiate STATUS_WORD register
        reg_ro #(.P_WIDTH(16))
        U_STATUS_WORD(
                 .CLOCK(CLOCK),
                  .REG_SELECT(cmd_struct[19].select[gv_i]),
                  .REG_READ(AVS_S0_READ),
                  .DATA_IN({reg_status_vout_err[gv_i], 1'b0, reg_status_input_err, 1'b0, ~mon_vout_pwrgd[gv_i][P_SAMPLES], 1'b0, reg_status_other_err[gv_i], 1'b0,
                            1'b0, ~SEQ_VMON_ENA[gv_i], reg_status_vout_q[gv_i][7], 1'b0, reg_status_input_q[4], 1'b0, reg_status_cml_err[gv_i], reg_status_byte_unlisted[gv_i]}),
                  .DATA_OUT_Q(reg_status_word_q[gv_i]));
        // Declare an error for the page if one is identified in anything other than status-only or reserved bits
        assign reg_status_word_err[gv_i] = ((reg_status_word_q[gv_i] & 16'hB3AB) == 16'b0 )? 1'b0:1'b1;

        // Instantiate STATUS_CML register
        reg_wtc #(.P_WIDTH(8))
        U_STATUS_CML(
                 .CLOCK(CLOCK),
                  .RESET_N(RESET_N && ~reg_clear_faults_q[4]),
                  .INIT(8'b0),
                  .REG_SELECT(cmd_struct[22].select[gv_i]),
                  .REG_WRITE(AVS_S0_WRITE),
                  .DATA_IN(AVS_S0_WRITEDATA[7:0]),
                  .ALARM_IN({cmd_badcommand[gv_i], cmd_baddata[gv_i], 6'b0}),
                  .DATA_OUT_Q(reg_status_cml_q[gv_i]));
        assign reg_status_cml_err[gv_i] = (reg_status_cml_q[gv_i] == 8'b0 )? 1'b0:1'b1;

        // Instantiate STATUS_OTHER register
        reg_wtc #(.P_WIDTH(8))
        U_STATUS_OTHER(
                 .CLOCK(CLOCK),
                  .RESET_N(RESET_N && ~reg_clear_faults_q[4]),
                  .INIT(8'b0),
                  .REG_SELECT(cmd_struct[23].select[gv_i]),
                  .REG_WRITE(AVS_S0_WRITE),
                  .DATA_IN(AVS_S0_WRITEDATA[7:0]),
                  .ALARM_IN({7'b0, smbalertn_first_q[gv_i]}),
                  .DATA_OUT_Q(reg_status_other_q[gv_i]));
        assign reg_status_other_err[gv_i] = (reg_status_other_q[gv_i] == 8'b0 )? 1'b0:1'b1;

      end
      // For the design with no PMBus interface, or the reduced feature set ("Hard-Coded Thresholds),
      //   hard-code the responses to the specified values in the package file
      else begin
        assign reg_status_byte_q[gv_i]        =  8'b0;
        assign reg_status_word_q[gv_i]        = 16'b0;
        assign reg_status_word_err[gv_i]      =  1'b0;
        assign reg_status_cml_q[gv_i]         =  8'b0;
        assign reg_status_other_q[gv_i]       =  8'b0;
      end
 
      // Implement data logging functionality
      if ((P_LOGGING_FUNCT_LEVEL == 1) || (P_LOGGING_FUNCT_LEVEL == 2))
      begin
        // Instantiate MFR_NV_PAGE_EN register
        reg_rw #(.P_WIDTH(3))
        U_MFR_NV_PAGE_EN (
                 .CLOCK(CLOCK),
                 .RESET_N(RESET_N),
                 .INIT(3'h7),
                 .REG_SELECT(cmd_struct[30].select[gv_i]),
                 .REG_WRITE(AVS_S0_WRITE),
                 .REG_ENA(avs_bit_en[2:0]),
                 .DATA_IN(AVS_S0_WRITEDATA[2:0]),
                 .DATA_OUT_Q(reg_mfr_nv_page_en_q[gv_i]));
      end
      else begin
        assign reg_mfr_nv_page_en_q[gv_i]    = 3'b0;
      end
   end
  endgenerate


  // Respond to "CLEAR_FAULTS" command
  always_ff @(posedge CLOCK) begin : P_ClearFaults
    if (CLOCK) begin
      reg_clear_faults_q[4]   <= (reg_clear_faults_q[3:0] == 4'b0111 )? 1'b1:1'b0;
      // This is for non-PMBus applications.  In order to prevent random accesses from
      //   clearing out faults, we can qualify this access with write-enable.
      if (REQUIRE_WE_FOR_CLR) 
        reg_clear_faults_q[3:0] <= {reg_clear_faults_q[2], {(3){(cmd_struct[ 1].select[0] & AVS_S0_WRITE)}}};
      else
        reg_clear_faults_q[3:0] <= {reg_clear_faults_q[2:0], cmd_struct[ 1].select[0]};
    end
  end: P_ClearFaults

  // Check to see if we have been sent a command that we don't support.
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_FlagBadCommand
    if (~RESET_N) begin
      cmd_badcommand <= {(VRAILS){1'b0}};
    end
    else if (CLOCK) begin
      if ((sel_allregs == 0) && (AVS_S0_READ || AVS_S0_WRITE))
           // Capture the bad command error on the currently selected page
           cmd_badcommand <= 1'b1 << reg_page_q;
      else cmd_badcommand <= {(VRAILS){1'b0}};
    end
  end: P_FlagBadCommand


  generate
    // Remap vector to 2D array, since Platform Designer doesn't support SystemVerilog interfaces
    for (gv_i=0; gv_i<VRAILS; gv_i=gv_i+1) begin: G_VOUTARRAY
      assign adc_vout_level_ary_q[gv_i] = ADC_VOUT_LEVEL_Q[gv_i*14 +:14];
    end
  endgenerate

  // Evaluate alarm conditions on captured ADC data
  always_ff @(posedge CLOCK) begin : P_ADC_EvalAlarms
    if (CLOCK) begin
      // Is VIN being monitored by the ADC?
      if (P_VRAIL_SEL[0] == 1) begin
        // Wait until a valid measurement is received from the ADC
        if (ADC_VIN_LEVEL_Q[13]) begin
          // Only declare a warning or fault if "power good" is first detected.
          if(mon_vin_pwrgd[P_SAMPLES]) begin
            // By default, set alarms to '0'
            alarm_vin_ov_fault_limit_q[0] <= 1'b0;
            alarm_vin_ov_warn_limit_q[0]  <= 1'b0;
            alarm_vin_uv_warn_limit_q[0]  <= 1'b0;
            alarm_vin_uv_fault_limit_q[0] <= 1'b0;
            // Check for overvoltage fault condition
            if (ADC_VIN_LEVEL_Q[11:0] >= reg_vin_ov_fault_limit_q) begin
              alarm_vin_ov_fault_limit_q[0] <= 1'b1;
            end
            // Check for overvoltage warning condition
            else if (ADC_VIN_LEVEL_Q[11:0] >= reg_vin_ov_warn_limit_q) begin
              alarm_vin_ov_warn_limit_q[0]  <= 1'b1;
            end
            // Check for undervoltage fault condition
            else if (ADC_VIN_LEVEL_Q[11:0] <= reg_vin_uv_fault_limit_q) begin
              alarm_vin_uv_fault_limit_q[0] <= 1'b1;
            end
            // Check for undervoltage warning condition
            else if (ADC_VIN_LEVEL_Q[11:0] <= reg_vin_uv_warn_limit_q) begin
              alarm_vin_uv_warn_limit_q[0]  <= 1'b1;
            end
            // Store the alarm condition for the previous set of samples.  Only set the alarm when all previous samples
            //   have alarmed.
            if (ADC_VIN_LEVEL_Q[12] == 1'b1) begin
              if (P_SAMPLES > 1) begin
                alarm_vin_ov_fault_limit_q[P_SAMPLES-1:1] <= alarm_vin_ov_fault_limit_q[P_SAMPLES-2:0];
                alarm_vin_ov_warn_limit_q[P_SAMPLES-1:1]  <= alarm_vin_ov_warn_limit_q[P_SAMPLES-2:0];
                alarm_vin_uv_warn_limit_q[P_SAMPLES-1:1]  <= alarm_vin_uv_warn_limit_q[P_SAMPLES-2:0];
                alarm_vin_uv_fault_limit_q[P_SAMPLES-1:1] <= alarm_vin_uv_fault_limit_q[P_SAMPLES-2:0];
              end
              alarm_vin_ov_fault_limit_q[P_SAMPLES]       <= (alarm_vin_ov_fault_limit_q[P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
              alarm_vin_ov_warn_limit_q[P_SAMPLES]        <= (alarm_vin_ov_warn_limit_q[P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
              alarm_vin_uv_warn_limit_q[P_SAMPLES]        <= (alarm_vin_uv_warn_limit_q[P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
              alarm_vin_uv_fault_limit_q[P_SAMPLES]       <= (alarm_vin_uv_fault_limit_q[P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
            end
          end
          else begin
            // Clear alarms if power is not at a good level
            alarm_vin_ov_fault_limit_q <= '0;
            alarm_vin_ov_warn_limit_q  <= '0;
            alarm_vin_uv_warn_limit_q  <= '0;
            alarm_vin_uv_fault_limit_q <= '0;
          end
        
          // Check for power good condition
          if (ADC_VIN_LEVEL_Q[11:0] >= reg_vin_on_q) begin
            mon_vin_pwrgd[0] <= 1'b1;
          end
          // Check for power not good condition
          else if (ADC_VIN_LEVEL_Q[11:0] <= reg_vin_off_q) begin
            mon_vin_pwrgd[0]  <= 1'b0;
          end
          if (ADC_VIN_LEVEL_Q[12] == 1'b1) begin
            if (P_SAMPLES > 1) begin
              mon_vin_pwrgd[P_SAMPLES-1:1] <= mon_vin_pwrgd[P_SAMPLES-2:0];
              // Check for transition from #PG to PG
              if (mon_vin_pwrgd[P_SAMPLES] == 1'b0)
                mon_vin_pwrgd[P_SAMPLES] <= (mon_vin_pwrgd[P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
              // Check for transition from PG to #PG
              else
                mon_vin_pwrgd[P_SAMPLES] <= (mon_vin_pwrgd[P_SAMPLES-1:0] == {(P_SAMPLES){1'b0}})? 1'b0:1'b1;
            end
            else
              mon_vin_pwrgd[P_SAMPLES]       <= (mon_vin_pwrgd[P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
          end
        end
        else begin
          // Set default values for alarm signals
          mon_vin_pwrgd              <= '0;
          alarm_vin_ov_fault_limit_q <= '0;
          alarm_vin_ov_warn_limit_q  <= '0;
          alarm_vin_uv_warn_limit_q  <= '0;
          alarm_vin_uv_fault_limit_q <= '0;
        end
      end
      // Use PG signal from Voltage Rail
      else begin
        `ifndef DISABLE_PGBUS
          mon_vin_pwrgd            <= {(P_SAMPLES+1){POWER_GOOD_IN[P_VRAIL_PG_MAP[0]]}};
        `endif
        alarm_vin_ov_fault_limit_q <= '0;
        alarm_vin_ov_warn_limit_q  <= '0;
        alarm_vin_uv_warn_limit_q  <= '0;
        // Declare UV alarm on digital monitored rail if PG drops while enabled
        alarm_vin_uv_fault_limit_q <= (POWER_GOOD_IN[P_VRAIL_PG_MAP[0]])? '0:{(P_SAMPLES+1){RESET_N}} ;
      end        

      // Loop through the VOUT rails to check their voltage levels against thresholds
      for (int i=0; i<VRAILS; i++) begin
        // Is the VOUT rail being monitored by the ADC?
        if (P_VRAIL_SEL[i+1] == 1) begin
          // Wait until a valid measurement is received from the ADC
          if (adc_vout_level_ary_q[i][13]) begin
            // Only declare a warning or fault if "power good" is first detected.
            if(mon_vout_pwrgd[i][P_SAMPLES]) begin
              // By default, set alarms to '0'
              alarm_vout_ov_fault_limit_q[i][0] <= 1'b0;
              alarm_vout_ov_warn_limit_q[i][0]  <= 1'b0;
              alarm_vout_uv_warn_limit_q[i][0]  <= 1'b0;
              alarm_vout_uv_fault_limit_q[i][0] <= 1'b0;
              // Check for overvoltage fault condition
              if (adc_vout_level_ary_q[i][11:0] >= reg_vout_ov_fault_limit_q[i]) begin
                alarm_vout_ov_fault_limit_q[i][0] <= 1'b1;
              end
              // Check for overvoltage warning condition
              else if (adc_vout_level_ary_q[i][11:0] >= reg_vout_ov_warn_limit_q[i]) begin
                alarm_vout_ov_warn_limit_q[i][0]  <= 1'b1;
              end
              // Check for undervoltage fault condition only when the rail is enabled
              else if (adc_vout_level_ary_q[i][11:0] <= reg_vout_uv_fault_limit_q[i]) begin
                alarm_vout_uv_fault_limit_q[i][0]  <= SEQ_VMON_ENA[i];
              end
              // Check for undervoltage warning condition only when the rail is enabled
              else if (adc_vout_level_ary_q[i][11:0] <= reg_vout_uv_warn_limit_q[i]) begin
                alarm_vout_uv_warn_limit_q[i][0]  <= SEQ_VMON_ENA[i];
              end
              // Store the alarm condition for the previous set of samples.  Only set the alarm when all previous samples
              //   have alarmed.
              if (adc_vout_level_ary_q[i][12] == 1'b1) begin
                if (P_SAMPLES > 1) begin
                  alarm_vout_ov_fault_limit_q[i][P_SAMPLES-1:1] <= alarm_vout_ov_fault_limit_q[i][P_SAMPLES-2:0];
                  alarm_vout_ov_warn_limit_q[i][P_SAMPLES-1:1]  <= alarm_vout_ov_warn_limit_q[i][P_SAMPLES-2:0];
                  alarm_vout_uv_warn_limit_q[i][P_SAMPLES-1:1]  <= alarm_vout_uv_warn_limit_q[i][P_SAMPLES-2:0];
                  alarm_vout_uv_fault_limit_q[i][P_SAMPLES-1:1] <= alarm_vout_uv_fault_limit_q[i][P_SAMPLES-2:0];
                end
                alarm_vout_ov_fault_limit_q[i][P_SAMPLES]       <= (alarm_vout_ov_fault_limit_q[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
                alarm_vout_ov_warn_limit_q[i][P_SAMPLES]        <= (alarm_vout_ov_warn_limit_q[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
                alarm_vout_uv_warn_limit_q[i][P_SAMPLES]        <= (alarm_vout_uv_warn_limit_q[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
                alarm_vout_uv_fault_limit_q[i][P_SAMPLES]       <= (alarm_vout_uv_fault_limit_q[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
              end
            end
            else begin
              // Clear alarms if power is not at a good level
              alarm_vout_ov_fault_limit_q[i] <= '0;
              alarm_vout_ov_warn_limit_q[i]  <= '0;
              alarm_vout_uv_warn_limit_q[i]  <= '0;
              alarm_vout_uv_fault_limit_q[i] <= '0;
            end
          
            // Check for power good condition
            if (adc_vout_level_ary_q[i][11:0] >= reg_power_good_on_q[i]) begin
              mon_vout_pwrgd[i][0] <= 1'b1;
            end
            // Check for power not good condition
            else if (adc_vout_level_ary_q[i][11:0] <= reg_power_good_off_q[i]) begin
              mon_vout_pwrgd[i][0]  <= 1'b0;
            end
            if (adc_vout_level_ary_q[i][12] == 1'b1) begin
              if (P_SAMPLES > 1) begin
                mon_vout_pwrgd[i][P_SAMPLES-1:1] <= mon_vout_pwrgd[i][P_SAMPLES-2:0];
                // Check for transition from #PG to PG
                if (mon_vout_pwrgd[i][P_SAMPLES] == 1'b0)
                  mon_vout_pwrgd[i][P_SAMPLES] <= (mon_vout_pwrgd[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
                // Check for transition from PG to #PG
                else
                  mon_vout_pwrgd[i][P_SAMPLES] <= (mon_vout_pwrgd[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b0}})? 1'b0:1'b1;
              end
              else
                mon_vout_pwrgd[i][P_SAMPLES]       <= (mon_vout_pwrgd[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
            end
          end
          else begin
            // Set default values for alarm signals
            mon_vout_pwrgd[i]              <= '0;
            alarm_vout_ov_fault_limit_q[i] <= '0;
            alarm_vout_ov_warn_limit_q[i]  <= '0;
            alarm_vout_uv_warn_limit_q[i]  <= '0;
            alarm_vout_uv_fault_limit_q[i] <= '0;
          end
          // Assert "power good" to the sequencer only if the voltage is above the power good threshold and
          //   no overvoltage or undervoltage alarms are present
          SEQ_VRAIL_PWRGD[i] <= mon_vout_pwrgd[i][P_SAMPLES] && 
                                !((alarm_vout_ov_fault_limit_q[i][P_SAMPLES] && (reg_vout_ov_fault_resp_q[i][7:6] == 2'b10)) || 
                                  (alarm_vout_uv_fault_limit_q[i][P_SAMPLES] && (reg_vout_uv_fault_resp_q[i][7:6] == 2'b10)));
        end
        // Use PG signal from Voltage Rail
        else begin
          // PG monitor should reflect the current state of the digital PG input
          mon_vout_pwrgd[i][0] <= POWER_GOOD_IN[P_VRAIL_PG_MAP[i+1]];
          if (P_SAMPLES > 1) begin
            mon_vout_pwrgd[i][P_SAMPLES-1:1] <= mon_vout_pwrgd[i][P_SAMPLES-2:0];
            // Check for transition from #PG to PG
            if (mon_vout_pwrgd[i][P_SAMPLES] == 1'b0)
              mon_vout_pwrgd[i][P_SAMPLES] <= (mon_vout_pwrgd[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
            // Check for transition from PG to #PG
            else
              mon_vout_pwrgd[i][P_SAMPLES] <= (mon_vout_pwrgd[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b0}})? 1'b0:1'b1;
          end
          else
            mon_vout_pwrgd[i][P_SAMPLES]       <= (mon_vout_pwrgd[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b1}})? 1'b1:1'b0;
          alarm_vout_ov_fault_limit_q[i] <= '0;
          alarm_vout_ov_warn_limit_q[i]  <= '0;
          alarm_vout_uv_warn_limit_q[i]  <= '0;
          // Declare UV alarm on digital monitored rail if PG drops while enabled
          alarm_vout_uv_fault_limit_q[i] <= (mon_vout_pwrgd[i][P_SAMPLES] & (mon_vout_pwrgd[i][P_SAMPLES-1:0] == {(P_SAMPLES){1'b0}}))? {(P_SAMPLES+1){SEQ_VMON_ENA[i]}}:{(P_SAMPLES+1){1'b0}};
          `ifndef DISABLE_PGBUS
            SEQ_VRAIL_PWRGD[i]           <= POWER_GOOD_IN[P_VRAIL_PG_MAP[i+1]];
          `endif
        end
      end
    end
  end: P_ADC_EvalAlarms

  // Generate SMB_ALERTN output.
  always_ff @(posedge CLOCK) begin : P_SMB_Alertn
    if (CLOCK) begin
      // Has an error been flagged in the status registers?
      if (reg_status_word_err != {(VRAILS){1'b0}} ) begin
        smbalertn_q <= 1'b0;
        // Is this the first SMB ALERT asserted, or has one already been flagged?
        if (SMB_ALERTN) begin
          for (int i=0; i<VRAILS; i++) begin
            if (reg_status_word_err[i] == 1'b1) smbalertn_first_q[i] <= 1'b1;
          end
        end
  else smbalertn_first_q <= {(VRAILS){1'b0}} ;
      end
      // Is there are no errors, clear out the interrupt
      else begin
        smbalertn_q       <= 1'b1;
        smbalertn_first_q <= {(VRAILS){1'b0}} ;
      end
    end
  end: P_SMB_Alertn

  // Capture error data for logging to flash, if the error logging feature is enabled
  `ifndef DISABLE_FLASH
  always_ff @(posedge CLOCK) begin : P_DataError
    // Register the data, to correlate with the error
    if (CLOCK) begin
      nvcap_error_q           <= 'b0;
      nvcap_bbdata_q          <= '{'b0,'b0};
      // Store the qualification window fault from the sequencer
      for (int i=0; i<VRAILS; i++) begin
        seq_qual_fault_q[i]   <= {seq_qual_fault_q[i][2:0], SEQ_QUAL_FAULT[i]};
      end
      // Capture a snapshot of the vrail status for blackbox data
      nvcap_bbdata_q          <= '{nvcap_bbdata_q[0],nvcap_bbdata};
      // Strobe the NVLOG_ERROR output at a change in status
      NVLOG_ERROR             <= nvcap_error_q[0] & !nvcap_error_q[1];
      // Capture a snapshot of all data for flash, aligning all data to the error
      if (nvcap_error_q[1:0] == 2'b01) begin
        NVLOG_FAULTTYPE       <= {3'b0, nvlog_faulttype_q};
        NVLOG_FAULTPAGE       <= nvcap_faultpage_q[0];
        NVLOG_TIMESTAMP       <= cntr_tod_cntr_q;
        NVLOG_BBDATA          <= nvcap_bbdata_q[1];
      end
      // Is the Global Log Enable set?
      if (reg_mfr_nv_master_en_q[0]) begin
        // Did we receive a VOUT_OV error?
        if (nvlog_error_page_ov_q != {(VRAILS){1'b0}} ) begin
            nvcap_error_q         <= {nvcap_error_q[0],1'b1};
            nvlog_faulttype_q[0]  <= 1'b1;
        end
        else nvlog_faulttype_q[0] <= 1'b0;
        // Did we receive a VOUT_UV error?
        if (nvlog_error_page_uv_q != {(VRAILS){1'b0}} ) begin
            nvcap_error_q         <= {nvcap_error_q[0],1'b1};
            nvlog_faulttype_q[1]  <= 1'b1;
        end
        else nvlog_faulttype_q[1] <= 1'b0;
        // Did we receive a VIN_OV error, and is it not masked?
        if (alarm_vin_ov_fault_limit_q[P_SAMPLES] & reg_mfr_nv_master_en_q[2]) begin
            nvcap_error_q         <= {nvcap_error_q[0],1'b1};
            nvlog_faulttype_q[2]  <= 1'b1;
        end
        else nvlog_faulttype_q[2] <= 1'b0;
        // Did we receive a VIN_UV error, and is it not masked?
        if (alarm_vin_uv_fault_limit_q[P_SAMPLES] & reg_mfr_nv_master_en_q[3]) begin
            nvcap_error_q         <= {nvcap_error_q[0],1'b1};
            nvlog_faulttype_q[3]  <= 1'b1;
        end
        else nvlog_faulttype_q[3] <= 1'b0;
        // Did we receive a Qualification Window error?
        if (nvlog_error_page_qual_q != {(VRAILS){1'b0}} ) begin
            nvcap_error_q         <= {nvcap_error_q[0],1'b1};
            nvlog_faulttype_q[4]  <= 1'b1;
        end
        else nvlog_faulttype_q[4] <= 1'b0;
        // Loop through the VOUT rails to see if an error is reported
        for (int i=0; i<VRAILS; i++) begin
          // Did we receive a VOUT_OV error, and is it not masked?
          if (alarm_vout_ov_fault_limit_q[i][P_SAMPLES]  & reg_mfr_nv_page_en_q[i][0]) begin
              nvlog_error_page_ov_q[i] <= 1'b1;
              nvcap_faultpage_q        <= '{nvcap_faultpage_q[0],i};
          end
          else nvlog_error_page_ov_q[i] <= 1'b0;
          // Did we receive a VOUT_UV error, and is it not masked?
          if (alarm_vout_uv_fault_limit_q[i][P_SAMPLES]  & reg_mfr_nv_page_en_q[i][1]) begin
              nvlog_error_page_uv_q[i]  <= 1'b1;
              nvcap_faultpage_q        <= '{nvcap_faultpage_q[0],i};
          end
          else nvlog_error_page_uv_q[i] <= 1'b0;
          // Did we receive a Qualification Window error, and is it not masked?
          if ((seq_qual_fault_q[i] != 4'h0) & reg_mfr_nv_page_en_q[i][2]) begin
              nvlog_error_page_qual_q[i]  <= 1'b1;
              nvcap_faultpage_q        <= '{nvcap_faultpage_q[0],i};
          end
          else nvlog_error_page_qual_q[i] <= 1'b0;
        end
      end
    end
  end: P_DataError
  assign NVLOG_BBENA          = reg_mfr_nv_master_en_q[1];
  assign FLASH_DATA_WRITE     = 1'b0;
  assign FLASH_DATA_WRITEDATA =  'b0;
  `endif

  // Capture blackbox data of the current state for the various voltage rails
  generate
    // Implement the blackbox output for full-featured data logging
    if ((P_LOGGING_FUNCT_LEVEL == 2)) begin
      // Assign vector of VOUT status to BBDATA
      assign nvcap_bbdata[1] = alarm_vin_ov_fault_limit_q[P_SAMPLES] | (mon_vin_pwrgd[P_SAMPLES] & ~alarm_vin_uv_fault_limit_q[P_SAMPLES]);
      assign nvcap_bbdata[0] = alarm_vin_uv_fault_limit_q[P_SAMPLES] | (mon_vin_pwrgd[P_SAMPLES] & ~alarm_vin_ov_fault_limit_q[P_SAMPLES]);
      for (gv_i=1; gv_i<=VRAILS; gv_i++) begin : P_CaptureBB_Data
        assign nvcap_bbdata[gv_i*2+1] = alarm_vout_ov_fault_limit_q[gv_i-1][P_SAMPLES] | (SEQ_VMON_ENA[gv_i-1] & ~alarm_vout_uv_fault_limit_q[gv_i-1][P_SAMPLES]);
        assign nvcap_bbdata[gv_i*2]   = alarm_vout_uv_fault_limit_q[gv_i-1][P_SAMPLES] | (SEQ_VMON_ENA[gv_i-1] & ~alarm_vout_ov_fault_limit_q[gv_i-1][P_SAMPLES]);
      end
    end
    else begin
      assign nvcap_bbdata = 'b0;
    end
  endgenerate

  `ifndef DISABLE_FLASH
  // Generate the Second Counter Tick for the TOD clock
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_TOD_SecondCntr
    if (~RESET_N) begin
      cntr_tod_second_q   <= '0;
      cntr_tod_secondtc_q <= '0;
    end
    else if (CLOCK) begin
      if (cntr_tod_second_q == reg_mfr_tod_secondreg_q) begin
        cntr_tod_second_q   <= 1;
        cntr_tod_secondtc_q <= 1'b1;
      end
      else begin
        cntr_tod_second_q   <= cntr_tod_second_q + 1;
        cntr_tod_secondtc_q <= 1'b0;
      end
    end
  end: P_TOD_SecondCntr
  `endif

  // When invalid data is attempted to be written, latch the error on the currently selected page
  assign cmd_baddata = reg_page_err << reg_page_q;

  // Assign logical expressions to Voltage Sequencer inputs
  assign SEQ_ENABLE     = RESET_N;
  assign SEQ_VIN_FAULT  = ~mon_vin_pwrgd[P_SAMPLES] || 
                          (alarm_vin_ov_fault_limit_q[P_SAMPLES] && (reg_vin_ov_fault_resp_q[7:6] == 2'b10)) || 
                          (alarm_vin_uv_fault_limit_q[P_SAMPLES] && (reg_vin_uv_fault_resp_q[7:6] == 2'b10));
  assign SEQ_RETRIES    = reg_global_resp_q[5:3];
  assign SEQ_TIMEOUTDLY = reg_global_resp_q[2:0];
  assign SMB_ALERTN     = (smbalertn_q == 1'b0) ? 1'b0 : 1'bZ;
  
endmodule