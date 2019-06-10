
////////////////////////////////////////////////////////////////////////////////////
//
// Module: sequencer_vmondecode_pkg.sv
//
// Description: This module contains the  parameters for the ADC voltage decoder
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

package sequencer_vmondecode_pkg;

  // Set the default PMBus page to the lowest used rail (VIN or VOUT) that uses an ADC-monitored
  //   input to monitor the voltage level (i.e. not a PG input).  Page 0 is used for VIN or VOUT0,
  //   and the remaining pages correspond to whether VOUT is an ADC-monitored rail.
  localparam int P_DEFAULT_PAGE            = 0;
  // Indicate whether the VRAIL should be qualified by the voltage monitor or by its own PG
  //   signal.  A value of '0' indicates PG, whereas '1' indicates the monitored ADC level.
  localparam bit [0:6] P_VRAIL_SEL         = 7'b1111111;
  // Map physical ADC channel to logical channel number.  Array element 0 maps to ADCIN0,
  //   1 to ADCIN1, and so on.  The value at each location relates to the voltage rail
  //   being monitored.  "0" indicates VIN and the VOUT rails are indicated in increasing
  //   value, up to the "VRAILS" parameter.  Any number greater than "VRAILS" (such as 199)
  //   is ignored, indicating that the channel is not utilized by the sequencer.
  localparam int P_ADC_CHAN_MAP[0:0][0:8]  = '{'{199, 0, 1, 2, 3, 4, 5, 199, 6}};
  // When the Power Good (PG) Inputs are not being used, the following define disables the interface
  //`define DISABLE_PGBUS
  // Map physical PG input to logical channel number.  Array element "0" is for VIN, and the
  //   VOUT rails are indicated in increasing value, up to the "VRAILS" parameter.  Any number
  //   greater than "VRAILS" (such as 199) is ignored, indicating that the Voltage Rail is
  //   not using the PG input.
  localparam int P_VRAIL_PG_MAP[0:6]       = '{199, 199, 199, 199, 199, 199, 199};

endpackage

