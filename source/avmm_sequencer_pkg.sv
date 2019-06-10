////////////////////////////////////////////////////////////////////////////////////
//
// Module: avmm_sequencer_pkg
//
// Description: This module contains the data structure and list of accesses for the
//    Avalon-MM sequencer.
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

package avmm_sequencer_pkg;
  // This structure is used by the command decode logic
  typedef struct packed
  {
    bit [ 7:0]  address;     // address - this can be expanded from 8 bits to the required width
    bit [31:0]  data;        // writedata OR expected readdata - this can be modified from the default 32-bits
    bit         read_writen; // operation - 1=read, 0=write
  } avmm_command_struct_t;

  // Initialize the structure with the desired read/write accesses, per the structure definition above.
  //   Operations will proceed sequentially from element 0 to element n.  Read accesses will continue
  //   to read the specified address until the data matches the expected value.  Bit masks are not
  //   currently supported, although it would be rather simple to add that support...  Write accesses
  //   are handled normally.
  localparam avmm_command_struct_t avmm_cmd_struct[0:0] = '{
    '{8'h00, 32'h00000001, 1'b0}
  };

endpackage