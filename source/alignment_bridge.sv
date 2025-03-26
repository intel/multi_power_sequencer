////////////////////////////////////////////////////////////////////////////////////
//
// Module: alignment_bridge
//
// Description: This module is a simple pass-through bridge that shifts off the
//   lower two address bits.  This is for byte-aligning the PMBus commands to
//   word addresses for control plane access.
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

module alignment_bridge (
  input                    CLOCK,
  input                    RESET_N,
  // AVMM Master
  output                   AVM_S0_READ,
  output                   AVM_S0_WRITE,
  output             [7:0] AVM_S0_ADDRESS,
  output             [3:0] AVM_S0_BYTEEN,
  input             [31:0] AVM_S0_READDATA,
  output            [31:0] AVM_S0_WRITEDATA,
  input                    AVM_S0_WAITREQUEST,
  // AVMM Slave
  input                    AVS_S0_READ,
  input                    AVS_S0_WRITE,
  input              [9:0] AVS_S0_ADDRESS,
  input              [3:0] AVS_S0_BYTEEN,
  output            [31:0] AVS_S0_READDATA,
  input             [31:0] AVS_S0_WRITEDATA,
  output                   AVS_S0_WAITREQUEST
);

  assign AVM_S0_READ        = AVS_S0_READ;
  assign AVM_S0_WRITE       = AVS_S0_WRITE;
  assign AVM_S0_ADDRESS     = AVS_S0_ADDRESS[$size(AVS_S0_ADDRESS)-1:2];
  assign AVM_S0_BYTEEN      = AVS_S0_BYTEEN;
  assign AVS_S0_READDATA    = AVM_S0_READDATA;
  assign AVM_S0_WRITEDATA   = AVS_S0_WRITEDATA;
  assign AVS_S0_WAITREQUEST = AVM_S0_WAITREQUEST;
  
endmodule