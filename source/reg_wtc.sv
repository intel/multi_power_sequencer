////////////////////////////////////////////////////////////////////////////////////
//
// Module: reg_wtc
//
// Description: This module implements a parameterizable Write To Clear register
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

module reg_wtc #(
  parameter                P_WIDTH = 1
)(
	input                    CLOCK,
	input                    RESET_N,
	input      [P_WIDTH-1:0] INIT,
	input                    REG_SELECT,
	input                    REG_WRITE,
	input      [P_WIDTH-1:0] DATA_IN,
	input      [P_WIDTH-1:0] ALARM_IN,
	output reg [P_WIDTH-1:0] DATA_OUT_Q
);

  // Implement Write To Clear (WTC) register.  If the bit is written, it is cleared.
  //   If the input alarm is asserted, the bit is set.
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_WTCREG
    if (~RESET_N)
      DATA_OUT_Q <= INIT;
    else if (CLOCK) begin
      for (int i=0; i<P_WIDTH; i++) begin
        if ((REG_WRITE && REG_SELECT) && (DATA_IN[i] == 1'b1))
          DATA_OUT_Q[i] <= 1'b0;
        else if (ALARM_IN[i] == 1'b1) 
          DATA_OUT_Q[i] <= 1'b1;
      end
    end
  end: P_WTCREG

endmodule


