////////////////////////////////////////////////////////////////////////////////////
//
// Module: por_pulse.sv
//
// Description: This module creates a power-on reset pulse
//
////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023 Intel Corporation
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

module por_pulse #(
  parameter                P_WIDTH = 8
)(
  input                    CLOCK,
	output                   RESET_N
);

  reg   [P_WIDTH-1:0] por_reset_q = 0;

	// Assign the reset to the output of the shift register
	assign RESET_N = por_reset_q[0];

	// Implement the shift register
  always_ff @(posedge CLOCK) begin : P_POR_SR
    por_reset_q <= {1'b1, por_reset_q[P_WIDTH-1:1]};
	end

endmodule