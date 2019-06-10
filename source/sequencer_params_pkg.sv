
////////////////////////////////////////////////////////////////////////////////////
//
// Module: sequencer_params
//
// Description: This module contains the timing parameters for the power sequencer
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

package sequencer_params_pkg;
  // These lines are required for the tools to understand that we are calculating with units of time.
  timeunit 1ns;
  timeprecision 1ns;

  // Define the clock period of the clock input to the sequencer
  parameter time P_CLKPERIOD        = 20ns;
  
  // Map the voltage rails to "Power Group" values.  This array is only used when the "PWR_GROUPS" parameter on
  //   the module is less than the "VRAILS" parameter.  Valid groups range from 0 to PWR_GROUPS-1.
  parameter time P_PWRGROUP [0:5] = '{0, 1, 2, 3, 4, 5};

  // Defines the delay from when the master enable is asserted to when the first rail's output enable
  //   is asserted, or from when power good is asserted until the next rail's output enable is
  //   asserted.  A value of "0ns" will bypass this delay.
  parameter time P_SEQDLY [0:5]     = '{10us, 10us, 10us, 10us, 10us, 10us};
  //
  // Defines the qualification window for which power good must be asserted, after output enable is asserted.
  //   If this time is violated, a fault will be indicated and the power rails will sequence down in reverse order
  parameter time P_QUALTIME [0:5]   = '{10ms, 10ms, 10ms, 10ms, 10ms, 10ms};
  //
  // Define the delay that the sequence will wait while sequencing *down*, after power good is deasserted, to
  //   allow the rail to gracefully discharge before forcing it.  A value of "0ns" will assert the discharge output
  //   immediately after power good is deasserted.
   parameter time P_DCHGDLY [0:5]   = '{0us, 0us, 0us, 0us, 0us, 0us};
 
  // Define the delay interval between restart attempts for the sequencer.  Multiple delay times can be specified, and
  //   the interval used is determined by the REG_TIMEOUTDLY input.  Units can be specified as s, ms, us, and ns (e.g. 10ms).
  //   A value of "0ns" will bypass this delay.
  parameter time P_RESTARTDLY [0:7] = '{0ns, 200ms, 200ms, 200ms, 200ms, 200ms, 200ms, 200ms};
  //
  // Define the maximum delay interval for dynamically sizing the delay counter.  This should be the largest delay from
  //   P_SEQDLY, P_QUALTIME, P_DCHGDLY, or P_RESTARTDLY.  If this is set too small, the design will not behave correctly,
  //    and incorrect "optimizations" to the logic will occur.
  parameter time P_MAXDELAY         = 200ms;
endpackage

