////////////////////////////////////////////////////////////////////////////////////
//
// Module: debounce.sv
//
// Description: This module debounces an input signal or bus
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

module debounce #(
  parameter                P_WIDTH = 8,
  parameter                P_DB_CLKS = 21
)(
  input                    CLOCK,
  input      [P_WIDTH-1:0] DATA_IN,
  output reg [P_WIDTH-1:0] DATA_OUT
);

  wire  [P_WIDTH-1:0] counter_rst;
  reg [P_DB_CLKS-1:0] counter [P_WIDTH-1:0] = '{default:'0};
  reg   [P_WIDTH-1:0] data_meta;
  reg   [P_WIDTH-1:0] data_q;
  reg   [P_WIDTH-1:0] data_2q;

	// Hold the debounce counter in reset, until the input stops changing
	assign counter_rst = data_q ^ data_2q;

  genvar gv_i;
  generate
    // Create unique debounce logic for each bit of the input vector
    for (gv_i=0; gv_i<P_WIDTH; gv_i=gv_i+1) begin: G_GenDebounce
      always_ff @(posedge CLOCK) begin : P_Debounce
        // Resample the input data for metastability
				data_meta[gv_i]   <= DATA_IN[gv_i];
				data_q[gv_i]      <= data_meta[gv_i];
				data_2q[gv_i]     <= data_q[gv_i];

				if (counter_rst[gv_i] == 1'b1)
					counter[gv_i] <= '0;
        // Once the input has been stable until the terminal count, pass it through to the output
				else if (counter[gv_i] == {(P_DB_CLKS){1'b1}}) begin
					DATA_OUT[gv_i]   <= data_2q[gv_i];
					counter[gv_i]    <= {(P_DB_CLKS){1'b1}};
				end else
					counter[gv_i]    <= counter[gv_i] + 1'b1;
			end
		end
	endgenerate

endmodule