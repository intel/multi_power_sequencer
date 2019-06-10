////////////////////////////////////////////////////////////////////////////////////
//
// Module: sequencer_vmondecode
//
// Description: This module latches the voltage levels from the ADC
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

module sequencer_vmondecode #(
  parameter                  VRAILS = 4,
  parameter                  PG_NUM = 3,
  parameter                  PG_DEBOUNCE = 5,
  parameter                  ADC_IFNUM = 1
)(
  input                      CLOCK,
  input                      RESET_N,
  input      [ADC_IFNUM-1:0] adc_sop,
  input      [ADC_IFNUM-1:0] adc_eop,
  input      [ADC_IFNUM-1:0] adc_valid,
  input    [ADC_IFNUM*5-1:0] adc_channel,
  input   [ADC_IFNUM*12-1:0] adc_data,
  // Optionally disable the PG Interface
  `ifndef DISABLE_PGBUS
  input  wire   [PG_NUM-1:0] POWER_GOOD_IN,
  output wire   [PG_NUM-1:0] POWER_GOOD_OUT,
  `endif
  output reg          [13:0] ADC_VIN_LEVEL_Q,
  output reg [VRAILS*14-1:0] ADC_VOUT_LEVEL_Q
);

  // This file contains the thresholds and command information for the voltage monitor
  import sequencer_vmondecode_pkg::*;

  // Store ADC data for analysis
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_ADC_Storage
    if (~RESET_N) begin
      ADC_VIN_LEVEL_Q  <= '0;
      ADC_VOUT_LEVEL_Q <= '{default:'0};
    end
    else if (CLOCK) begin
      ADC_VIN_LEVEL_Q[12] <= 1'b0;
      for (int i=0; i<VRAILS; i=i+1) begin: G_INITSTROBE
        ADC_VOUT_LEVEL_Q[14*i+12] <= 1'b0;
      end
      // Loop through all of the ADC interfaces
      for (int i=0; i<ADC_IFNUM; i=i+1) begin: G_ADC_IFNUM
        // Is the ADC sending us valid data for capture?
        if (adc_valid[i] == 1'b1) begin
          // Only look at data that is for a valid voltage rail.  Unmonitored channels should be set to a value
          //   higher than the number of voltage rails (such as "99").
          if (P_ADC_CHAN_MAP[i][adc_channel[i*5 +:5]] <= VRAILS+1) begin
            // Channel 0 is mapped to VIN
            if (P_ADC_CHAN_MAP[i][adc_channel[i*5 +:5]] == 0) ADC_VIN_LEVEL_Q <= {2'b11,adc_data[i*12 +:12]};
            // Channels 1-n are mapped to VOUT
            else ADC_VOUT_LEVEL_Q[(P_ADC_CHAN_MAP[i][adc_channel[i*5 +:5]]-1)*14 +:14] <= {2'b11,adc_data[i*12 +:12]};
          end
        end
      end
    end
  end: P_ADC_Storage

  `ifndef DISABLE_PGBUS
  // Debounce the Power Good signals
  debounce #(.P_WIDTH(PG_NUM),
             .P_DB_CLKS(PG_DEBOUNCE)) U_DEBOUNCE_PG
            (.CLOCK(CLOCK),
             .DATA_IN(POWER_GOOD_IN),
             .DATA_OUT(POWER_GOOD_OUT));
  `endif

endmodule