////////////////////////////////////////////////////////////////////////////////////
//
// Module: avmm_sequencer
//
// Description: This module contains the state machine for performing Avalon-MM
//   read/write accesses.
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
// Current Assumptions/Limitations: Neither byte enables nor bit masks are currently
//   supported, although it would be rather simple to add that support.
//
////////////////////////////////////////////////////////////////////////////////////

`timescale 1 ps / 1 ps
module avmm_sequencer #(
  parameter                     P_ADDRSIZE = 8,
  parameter                     P_DATASIZE = 32
)(
		input                       CLOCK,
		input                       RESET_N,
		output reg                  AVM_M0_READ,
		output reg                  AVM_M0_WRITE,
		input                       AVM_M0_WAITREQUEST,
		output reg [P_ADDRSIZE-1:0] AVM_M0_ADDRESS,
		input      [P_DATASIZE-1:0] AVM_M0_READDATA,
		output reg [P_DATASIZE-1:0] AVM_M0_WRITEDATA
);

  // Import the structure containing the data for the read/write accesses that need to be performed
  import avmm_sequencer_pkg::*;

  // Enumerate a list of states for the FSM that performs the instruction command sequencing
  typedef enum int unsigned {
    ST_RESET,
    ST_ASSERTCMD,
    ST_DONE
  } t_seq_states;
  t_seq_states seq_state_q, seq_nextstate;

  reg [$clog2($size(avmm_cmd_struct))-1:0] cntr_q;
  reg cntr_en;
  reg readdata_matched;
  
  // Implement command counter to sequence through transactions
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_counter
    if (~RESET_N) begin
      cntr_q <= 'b0;
    end
    else if (CLOCK) begin
      if (cntr_en == 1) cntr_q++;
      else              cntr_q <= cntr_q;
    end
  end: P_counter

  assign readdata_matched = ((AVM_M0_READDATA == avmm_cmd_struct[cntr_q][P_DATASIZE:1] ) | (avmm_cmd_struct[cntr_q][0] == 1'b0))? 1'b1 : 1'b0;

  // Sequential process that advances the state machine
  always_ff @(posedge CLOCK or negedge RESET_N) begin : fsm_sequential
    if (~RESET_N) begin
      seq_state_q <= ST_RESET;
    end
    else if (CLOCK) begin
      // Advance state machine to the next state
      seq_state_q <= seq_nextstate;
    end
  end: fsm_sequential

  // State machine that performs the instruction command sequencing
  always @* begin : seq_combinatorial
    // Default inactive assignments
    AVM_M0_READ      <= 1'b0;
    AVM_M0_WRITE     <= 1'b0;
    AVM_M0_ADDRESS   <= 'b0;
    AVM_M0_WRITEDATA <= 'b0;
    cntr_en          <= 1'b0;

    case (seq_state_q)
      // Idle state.  We remain in this state until we exit reset.
      ST_RESET: begin
        seq_nextstate <= ST_ASSERTCMD;
      end

      // Remain in this state until all accesses have completed.  
      ST_ASSERTCMD: begin
        AVM_M0_READ      <= avmm_cmd_struct[cntr_q][0];
        AVM_M0_WRITE     <= ~avmm_cmd_struct[cntr_q][0];
        AVM_M0_ADDRESS   <= avmm_cmd_struct[cntr_q][P_ADDRSIZE+P_DATASIZE:P_DATASIZE+1];
        AVM_M0_WRITEDATA <= avmm_cmd_struct[cntr_q][P_DATASIZE:1];
        // Increment to the next command when waitrequest is deasserted and, if we are
        //   performing a read, the readdata matches the expected data.
        cntr_en          <= ~AVM_M0_WAITREQUEST & readdata_matched;
        // The command has been executed when waitrequest is driven low.  We have completed
        //   the sequence of accesses when the counter has indexed through the list.
        if ((!AVM_M0_WAITREQUEST) && (cntr_q >= ($size(avmm_cmd_struct) - 1)))
          seq_nextstate   <= ST_DONE;
        else 
          seq_nextstate   <= ST_ASSERTCMD;
      end

      // Idle state.  We remain in this state, since we have completed our sequence of accesses
      ST_DONE: begin
        seq_nextstate <= ST_DONE;
      end

    endcase
  end : seq_combinatorial

endmodule
