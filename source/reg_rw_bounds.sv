////////////////////////////////////////////////////////////////////////////////////
//
// Module: reg_rw_bounds
//
// Description: This module implements a parameterizable Read/Write register
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

module reg_rw_bounds #(
  parameter                P_WIDTH = 1
)(
	input                    CLOCK,
	input                    RESET_N,
	input      [P_WIDTH-1:0] INIT,
	input      [P_WIDTH-1:0] BOUND_MIN,
	input      [P_WIDTH-1:0] BOUND_MAX,
	input                    REG_SELECT,
	input                    REG_WRITE,
	input      [P_WIDTH-1:0] DATA_IN,
	output reg               ALARM_OUT,
	output reg [P_WIDTH-1:0] DATA_OUT_Q
);

  // Implement Read/Write (RW) register.
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_RWREG_BND
    if (~RESET_N)
      DATA_OUT_Q <= INIT;
    else if (CLOCK) begin
      if (REG_WRITE && REG_SELECT && (DATA_IN > BOUND_MAX)) begin
        ALARM_OUT <= 1'b1;
        DATA_OUT_Q <= DATA_OUT_Q;
      end
      else if (REG_WRITE && REG_SELECT && (DATA_IN < BOUND_MIN)) begin
        ALARM_OUT <= 1'b1;
        DATA_OUT_Q <= DATA_OUT_Q;
      end
      else if (REG_WRITE && REG_SELECT) begin
        ALARM_OUT <= 1'b0;
        DATA_OUT_Q <= DATA_IN;
      end
      else begin
        ALARM_OUT <= 1'b0;
        DATA_OUT_Q <= DATA_OUT_Q;
      end
    end
  end: P_RWREG_BND

endmodule


