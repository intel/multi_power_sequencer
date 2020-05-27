////////////////////////////////////////////////////////////////////////////////////
//
// Module: sequencer_ctrl
//
// Description: This module contains the state machine for performing the
//   power rail sequencing.
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

module sequencer_ctrl #(
  parameter              DLY_EN2OE    =  5, // Programmable delay (in clock cycles) from the input enable, until output enable is asserted.
  parameter              DLY_OE2PG    = 10, // Qualification window (in clock cycles) from the output enable, until power good should be asserted.
  parameter              DLY_PNG2DCHG =  5, // Programmable delay (in clock cycles) from power good deasserted, until discharge is asserted.
  parameter              C_CNTRSIZE   =  4  // Width of the counter vector.
)(
	input                  CLOCK,
  input                  ENABLE,
  input                  KEEPALIVE,
  output reg             CNTR_EN,
  input [C_CNTRSIZE-1:0] CNTR,
	input                  GROUP_PWRGD_HI,
	input                  VRAIL_PWRGD,
	output reg             VRAIL_FAULT,
	output reg             VRAIL_ENA,
	output reg             VRAIL_DCHG,
	output reg             NEXT_OE
);

  // Enumerate a list of states for the FSM that performs the power sequencing
  typedef enum int unsigned {
    ST_WAIT4EN,
    ST_WAIT4PGMDLY,
    ST_WAIT4PWRGD,
    ST_ENABLED,
    ST_WAIT4PWRNOTGD,
    ST_WAIT4DCHGDLY,
    ST_DISCHARGE,
    ST_DISCHARGE_RST
  } t_seq_states;
  t_seq_states seq_state_q = ST_DISCHARGE_RST, seq_nextstate = ST_DISCHARGE_RST;

  // Sequential process that advances the state machine
  always_ff @(posedge CLOCK) begin : fsm_sequential
    // Advance state machine to the next state
    seq_state_q <= seq_nextstate;
  end: fsm_sequential

  // State machine that performs the power sequencing
  always @* begin : seq_combinatorial
    // Default inactive assignments
    seq_nextstate <= seq_state_q;
    CNTR_EN       <= 1'b0;
    VRAIL_FAULT   <= 1'b0;
    VRAIL_ENA     <= 1'b0;
    VRAIL_DCHG    <= 1'b0;
    NEXT_OE       <= 1'b0;

    case (seq_state_q)
      // Idle state.  We remain in this state until our ENABLE input is asserted
      ST_WAIT4EN: begin
        if (ENABLE) begin
          // If no delay is specified, bypass the input enable to output enable delay
          if (DLY_EN2OE == 0) begin
            VRAIL_ENA     <= 1'b1;
            seq_nextstate <= ST_WAIT4PWRGD;
          end
          else
            seq_nextstate <= ST_WAIT4PGMDLY;
        end
        else
          seq_nextstate   <= ST_DISCHARGE;
      end

      // Wait for a programmable delay before enabling the rail
      ST_WAIT4PGMDLY: begin
        CNTR_EN           <= 1'b1;
        // If ENABLE is removed, go back to the idle state
        if (!ENABLE)
          seq_nextstate   <= ST_DISCHARGE;
        // Once we have waited for the requested delay, enable the power rail
        else if (CNTR >= DLY_EN2OE) begin
          CNTR_EN         <= 1'b0;
          seq_nextstate   <= ST_WAIT4PWRGD;
        end
        else 
          seq_nextstate   <= ST_WAIT4PGMDLY;
      end

      // Assert enable and wait for Power Good to be asserted within the valid
      //   window of "DLY_OE2PG".  If this doesn't occur, sequence down and assert
      //   "fault".
      ST_WAIT4PWRGD: begin
        CNTR_EN           <= 1'b1;
        VRAIL_ENA         <= 1'b1;
        // If ENABLE is removed, go back to the idle state
        if (!ENABLE)
          seq_nextstate   <= ST_DISCHARGE;
        // If the timer expires, assert fault and sequence down
        else if (CNTR >= DLY_OE2PG) begin
          VRAIL_FAULT     <= 1'b1;
          seq_nextstate   <= ST_WAIT4PWRNOTGD;
        end
        // The power rail is good - move to next state
        else if (VRAIL_PWRGD)
          seq_nextstate   <= ST_ENABLED;
        else
          seq_nextstate   <= ST_WAIT4PWRGD;
      end

      // Assert output enable to the next rail.  If a disable signal
      //   is detected, sequence down.
      ST_ENABLED: begin
        VRAIL_ENA         <= 1'b1;
        NEXT_OE           <= 1'b1;
        // The board is being powered down - remove enable and wait for 
        if (!ENABLE && !KEEPALIVE) begin
          VRAIL_ENA       <= 1'b0;
          seq_nextstate   <= ST_WAIT4PWRNOTGD;
        end
        // The power good signal for this rail became deasserted - signal a
        //   flag, but keep the rail asserted until the other rails sequence down
        else if (!VRAIL_PWRGD) begin
          VRAIL_FAULT     <= 1'b1;
          if (!KEEPALIVE)
            seq_nextstate <= ST_WAIT4PWRNOTGD;
          else
            seq_nextstate <= ST_ENABLED;
        end
        else 
          seq_nextstate   <= ST_ENABLED;
      end

      // Wait for the power good signal to be deasserted before discharging
      //   the supply
      ST_WAIT4PWRNOTGD: begin
        if ((!VRAIL_PWRGD) && (!GROUP_PWRGD_HI)) begin
          // If no delay is specified, bypass the discharge delay
          if (DLY_PNG2DCHG == 0)
            seq_nextstate <= ST_DISCHARGE;
          else
            seq_nextstate <= ST_WAIT4DCHGDLY;
        end
        else
          seq_nextstate   <= ST_WAIT4PWRNOTGD;
      end

      // Wait for the delay interval of "DLY_PNG2DCHG" after power good has been deasserted
      //   to allow the rail to gracefully discharge before forcing it.
      ST_WAIT4DCHGDLY: begin
        CNTR_EN           <= 1'b1;
        // If the timer reaches its delay count, proceed to discharge state
        if (CNTR >= DLY_PNG2DCHG)
          seq_nextstate   <= ST_DISCHARGE;
        // Remain in this state until the specified delay interval
        else
          seq_nextstate   <= ST_WAIT4DCHGDLY;
      end

      // Assert discharge FET to bring rail down
      ST_DISCHARGE: begin
        VRAIL_DCHG        <= 1'b1;
        seq_nextstate     <= ST_DISCHARGE_RST;
      end

      // Assert discharge FET to bring rail down, wait for ENABLE to be re-asserted
      ST_DISCHARGE_RST: begin
        VRAIL_DCHG        <= 1'b1;
        // If we are re-enabled, return to idle state
        if (ENABLE)
          seq_nextstate   <= ST_WAIT4EN;
        // Remain in this state
        else
          seq_nextstate   <= ST_DISCHARGE_RST;
      end

    endcase
  end : seq_combinatorial
  
endmodule