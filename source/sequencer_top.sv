////////////////////////////////////////////////////////////////////////////////////
//
// Module: sequencer_top
//
// Description: This module performs voltage rail sequencing for power-up
//   and power-down conditions.  Delays and number of rails are parameterizable.
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

module sequencer_top #(
  parameter               VRAILS     = 4,
  parameter               PWR_GROUPS = 4,
  parameter               USE_EXTERNAL_IOBUF = 0
)(
	input                   CLOCK,
  input                   ENABLE,
  input                   VIN_FAULT,
	input  [VRAILS-1    :0] VRAIL_PWRGD,
	output [PWR_GROUPS-1:0] VRAIL_ENA,
	output reg [VRAILS-1:0] VMON_ENA,
	output [PWR_GROUPS-1:0] VRAIL_DCHG,
	output                  nFAULT,
  input             [2:0] REG_RETRIES,
  input             [2:0] REG_TIMEOUTDLY
);

  // This file contains the timing delays for the controller.  Timeunit and timeprecision appear to be needed
  //    by the tools to enable the time unit calculations to be performed.
  timeunit 1ns;
  timeprecision 1ns;
  import sequencer_params_pkg::*;

  reg  enable_q;
  wire [PWR_GROUPS-1:0] seq_enable;
  wire [PWR_GROUPS-1:0] seq_keepalive;
  wire [PWR_GROUPS-1:0] vrail_fault;
  wire [PWR_GROUPS-1:0] fault_pwrgd;
  reg  [PWR_GROUPS-1:0] fault_pwrgd_q;
  wire [PWR_GROUPS-1:0] next_oe;
  wire [PWR_GROUPS-1:0] vrail_ena_i;
  wire [PWR_GROUPS-1:0] vrail_dchg_i;
  reg  [PWR_GROUPS-1:0] group_pwrgd;
  reg  [PWR_GROUPS-1:0] group_pwrgd_hi;
  reg  nFault_q;
 
  // Counter to measure delay
  parameter C_CNTRSIZE = $clog2(int'(P_MAXDELAY/P_CLKPERIOD));
  reg [C_CNTRSIZE-1:0] cntr_q;
  wire      [PWR_GROUPS:0] cntr_en;
  reg            [2:0] cntr_rtry_q = 3'b0;
  reg                  cntr_rstrtdly_en;
  reg                  seq_restart_q = 1'b1;
  reg                  seq_restart_2q;
  reg                  init_seqdone_q;
  wire                 poks_low;

  // Implement shared counter for sequencer state machines for delay comparison
  always_ff @(posedge CLOCK) begin : P_counter
    if (cntr_en == 0) cntr_q <= 0;
    else cntr_q++;
  end: P_counter

  // Implement register to latch fault on pwrgd.
  always_ff @(posedge CLOCK or negedge ENABLE) begin : P_FaultReg
    if (!ENABLE) begin
      fault_pwrgd_q  <= {PWR_GROUPS{1'b0}};
      nFault_q       <= 1'b1;
    end
    else begin
      // If we have a rising edge on our Sequencer Restart signal (for retries), clear out any current faults.
      //   Clear out any initial faults that might have been present prior to the initial sequence.
      if (((seq_restart_q == 1'b1) && ( seq_restart_2q == 1'b0)) || (enable_q && !init_seqdone_q)) begin
        fault_pwrgd_q <= {PWR_GROUPS{1'b0}};
        nFault_q      <= 1'b1;
      end
      else begin
        fault_pwrgd_q <= fault_pwrgd_q | fault_pwrgd;
        nFault_q      <= nFault_q;
        if (VIN_FAULT || (fault_pwrgd_q != 0))
          nFault_q    <= 1'b0;
      end
    end
  end: P_FaultReg

  // Implement the retry counter as well as the logic to safely implement the restart process.
  always_ff @(posedge CLOCK) begin : P_RetryDelay
    // Default assignments
    cntr_rstrtdly_en <= 1'b0;
    // Synchronous reset
    if (!ENABLE) begin
      cntr_rtry_q     <= 0;
      seq_restart_q   <= 1'b1;
      init_seqdone_q  <= 1'b0;
    end

    // Reregister the sequencer restart signal (to generate a pulse)
    seq_restart_2q   <= seq_restart_q;

    // Flag that indicates whether the inital power up sequence has been started
    if (vrail_ena_i[0]) init_seqdone_q <= 1'b1;

    // If a POK fault is detected and we're not already waiting to restart the sequencer,
    //   initiate the restart process by driving restart low.
    if ((nFault_q == 1'b0) && (seq_restart_2q == 1'b1)) begin
       seq_restart_q     <= 1'b0;
    end
    // Start the delay counter only after all POKs are low and we are still allowed to retry
    if ((cntr_en[0] == 1'b0) && (poks_low == 1'b1) && ( seq_restart_q == 1'b0) && (cntr_rtry_q < REG_RETRIES)) begin
      cntr_rstrtdly_en <= 1'b1;
      // Has the delay counter reached the terminal count, if so send a restart pulse
      if (cntr_q >= P_RESTARTDLY[REG_TIMEOUTDLY]/P_CLKPERIOD) begin
        seq_restart_q    <= 1'b1;
        cntr_rstrtdly_en <= 1'b0;
        // The maximum number of retries for PMBus is 6.  Therefore, a 7 indicates infinite retries
        if (REG_RETRIES != 3'h7)
          cntr_rtry_q    <= cntr_rtry_q + 1'b1;
      end
    end
  end: P_RetryDelay

  // Generate the internal Power Good signal for the sequencer
  generate
    // AND together the Power Good signals that share the same Power Group
    if (VRAILS > PWR_GROUPS) begin
      always @(*) begin : P_BuildGroups
        automatic reg [PWR_GROUPS-1:0] tmp_pwrgd_and = '1; // local variable (scope limited to process)
        automatic reg [PWR_GROUPS-1:0] tmp_pwrgd_or = '0; // local variable (scope limited to process)
        for (int i=0; i<VRAILS; i=i+1) begin
          tmp_pwrgd_and[P_PWRGROUP[i]] = tmp_pwrgd_and[P_PWRGROUP[i]] & VRAIL_PWRGD[i];
          tmp_pwrgd_or [P_PWRGROUP[i]] = tmp_pwrgd_or [P_PWRGROUP[i]] | VRAIL_PWRGD[i];
          VMON_ENA[i]                  = vrail_ena_i[P_PWRGROUP[i]];
        end
        group_pwrgd    = tmp_pwrgd_and;
        group_pwrgd_hi = tmp_pwrgd_or;
      end
    end
    // Power Groups aren't being used, so pass the Power Good signal through to the sequencers
    else begin
      assign group_pwrgd    = VRAIL_PWRGD;
      assign group_pwrgd_hi = VRAIL_PWRGD;
      assign VMON_ENA       = vrail_ena_i;
    end
  endgenerate

  // Generate the enable signal to the sequencers
  always_ff @(posedge CLOCK) begin : P_SeqEnable
    // If we are currently not enabled, only sequence up once enable is asserted, we are allowed a restart, and all POKs are low.
    //   Bypass the restart logic and restart delay if this is the initial power-up sequence to eliminate any delays.
    if (!enable_q) begin
      if (ENABLE && poks_low && (seq_restart_q || !init_seqdone_q)) enable_q <= 1'b1;
    end
    // If we are currently enabled, sequence down if we receive a POK fault or ENABLE is deasserted.
    else begin
      if (!(nFault_q && ENABLE)) enable_q <= 1'b0;
    end
  end: P_SeqEnable

  // Perform OR reduction on VRAIL_PWRGD.  Sequencer cannot start unless all VOUT POK signals are low to ensure proper sequencing.
  assign poks_low = ((VIN_FAULT == 1'b0) && (VRAIL_PWRGD == 0)) ? 1'b1 : 1'b0;
  assign cntr_en[PWR_GROUPS] = cntr_rstrtdly_en;

  ////////////////////////////////////////////////////////////////////////////
  // Asynchronous signal assigments
  ////////////////////////////////////////////////////////////////////////////
  // Daisy chain outputs from one sequencer to the next sequencer downstream.
  assign seq_enable    = {PWR_GROUPS{enable_q}} & {next_oe[PWR_GROUPS-2:0],enable_q};
  // This signal will be asserted if pwrgd is deasserted after it had been asserted, or if the sequencer detects a fault
  assign fault_pwrgd   = (next_oe & ~group_pwrgd) | vrail_fault;
  // Keep upstream supplies enabled until downstream supplies have been discharged.
  assign seq_keepalive = {1'b0, ~(vrail_dchg_i[PWR_GROUPS-1:1])};
  // Open-drain drivers for all outputs
  generate
    if (!USE_EXTERNAL_IOBUF)
      assign nFAULT        = (nFault_q) ? 1'b1 : 1'bZ ;
    else
      assign nFAULT        = nFault_q;
  endgenerate


  // Instantiate a voltage controller per each power rail
  genvar gv_i;
  generate
    for (gv_i=0; gv_i<PWR_GROUPS; gv_i=gv_i+1) begin: G_SEQCTRL
      sequencer_ctrl #(.DLY_EN2OE(P_SEQDLY[gv_i]/P_CLKPERIOD),
                       .DLY_OE2PG(P_QUALTIME[gv_i]/P_CLKPERIOD),
                       .DLY_PNG2DCHG(P_DCHGDLY[gv_i]/P_CLKPERIOD),
                       .C_CNTRSIZE(C_CNTRSIZE)) U_SEQCTRL
                      (.CLOCK(CLOCK),
                       .ENABLE(seq_enable[gv_i]),
                       .KEEPALIVE(seq_keepalive[gv_i]),
                       .CNTR_EN(cntr_en[gv_i]),
                       .CNTR(cntr_q),
                       .GROUP_PWRGD_HI(group_pwrgd_hi[gv_i]),
                       .VRAIL_PWRGD(group_pwrgd[gv_i]),
                       .VRAIL_FAULT(vrail_fault[gv_i]),
                       .VRAIL_ENA(vrail_ena_i[gv_i]),
                       .VRAIL_DCHG(vrail_dchg_i[gv_i]),
                       .NEXT_OE(next_oe[gv_i]));
      // Open-drain drivers for all outputs
      if (!USE_EXTERNAL_IOBUF) begin
        assign VRAIL_ENA[gv_i]  = ( vrail_ena_i[gv_i]) ? 1'b1 : 1'bZ ;
        assign VRAIL_DCHG[gv_i] = (~vrail_ena_i[gv_i]) ? 1'b1 : 1'bZ ;
      end else begin
        assign VRAIL_ENA[gv_i]  = vrail_ena_i[gv_i];
        assign VRAIL_DCHG[gv_i] = ~vrail_ena_i[gv_i];
      end
    end
  endgenerate
endmodule