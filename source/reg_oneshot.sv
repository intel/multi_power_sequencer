////////////////////////////////////////////////////////////////////////////////////
//
// Module: reg_oneshot
//
// Description: This module implements a parameterizable one-shot register
//
////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024 Intel Corporation
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

module reg_oneshot #(
  parameter                P_WIDTH = 1
)(
	input                    CLOCK,
	input                    RESET_N,
	input                    REG_SELECT,
	input                    REG_WRITE,
	input      [P_WIDTH-1:0] REG_ENA,
	input      [P_WIDTH-1:0] DATA_IN,
	input      [P_WIDTH-1:0] ACK_IN,
	output reg [P_WIDTH-1:0] DATA_OUT_Q
);

  // Implement One-Shot (1S) register.
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_1SREG
    if (~RESET_N)
      DATA_OUT_Q <= 'b0;
    else if (CLOCK) begin
      for (int i=0; i<P_WIDTH; i++) begin
        // Once acknowledged, clear out the register bit.
        if (ACK_IN[i]) DATA_OUT_Q[i] <= 1'b0;
        else if (REG_WRITE && REG_SELECT && REG_ENA[i]) DATA_OUT_Q[i] <= DATA_IN[i];
      end
    end
  end: P_1SREG

endmodule


