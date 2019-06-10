////////////////////////////////////////////////////////////////////////////////////
//
// Module: pmbus_slave
//
// Description: Slave PMBus to Avalon-MM Bridge.  This component translates the
//   PMBus commands to simple Avalon-MM localbus transactions.
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
//   1) This interface is a simple PMBus slave, which does not support the extensions
//      to the spec.
//   2) It assumes that the interfacing component or components will respond to
//      read/write accesses within one PMBus clock period.
//   3) It does not support the transfer of data (either read or write word commands)
//      that require the transfer of more than "MAX_BYTES" bytes.
//
////////////////////////////////////////////////////////////////////////////////////


module pmbus_slave #(
	parameter                     PMB_SLAVE_ADDR  = 7'h55,
  parameter                     MAX_BYTES       = 2
)(
  input  wire                   CLOCK,
  input  wire                   RESET_N,
  input  wire                   SCL,
  inout  wire logic             SDA,
  output wire [7:0]             SMB_COMMAND,
  output wire [MAX_BYTES-1:0]   SMB_BYTEEN,
  output wire                   SMB_STOP,
  output wire                   SMB_READ,
  output wire                   SMB_WRITE,
  input  wire                   SMB_WAITREQUEST,
  input  wire [MAX_BYTES*8-1:0] SMB_READDATA,
  output wire [MAX_BYTES*8-1:0] SMB_WRITEDATA
);

  // Enumerate a list of states for the FSM that will translate the
  //   incoming PMBus command to Avalon-MM transactions.
  typedef enum int unsigned {
    ST_IDLE,
    ST_SLAVE_ADDR,
    ST_SLAVE_ACK,
    ST_COMMAND,
    ST_DATA_ACK,
    ST_DATA_RX,
    ST_DATA_TX,
    ST_MASTER_ACK
  } t_pmb_states;
  t_pmb_states pmbus_currstate, pmbus_nextstate;

  // Define the local signals that will be used within the module
  logic                   [1:0] pmbus_debounce_q;
  logic                         sda_tx;
  wire                          sda_rx;
  logic                   [1:0] sda_q;
  logic                   [1:0] scl_q;
  logic                         sda_rise;
  logic                         sda_fall;
  logic                         scl_rise;
  logic                         scl_fall;

  logic                         flag_start_q;
  logic                         flag_stop_q;
  logic                         flag_cmd_latched_q;
  logic                         store_slave_addr;
  logic                         store_command;
  logic                         store_data;
  logic                         store_readdata;
  logic                         bitcounter_rst;
  logic                         bitcounter_en;
  logic [$clog2(MAX_BYTES)+3:0] bitcounter_q;

  logic   [$clog2(MAX_BYTES):0] smb_addr_q;
  logic                         smb_read_q;
  logic                         smb_write_q;
  logic                   [7:0] smb_byte_q;
  logic                   [7:0] cmd_slave_addr_q;
  logic                   [7:0] cmd_command_q;
  logic         [MAX_BYTES-1:0] smb_writedata_en_q;
  logic   [MAX_BYTES-1:0] [7:0] smb_readdata_q;
  logic   [MAX_BYTES-1:0] [7:0] smb_writedata_q;

  // Debounce the I2C signals
  debounce #(.P_WIDTH(2),
             .P_DB_CLKS(2)) U_DEBOUNCE_I2C
            (.CLOCK(CLOCK),
             .DATA_IN({sda_rx, SCL}),
             .DATA_OUT(pmbus_debounce_q));

  // Assign internal signals to component ports
  assign SDA           = (sda_tx == 1'b0) ? 1'b0 : 1'bZ;
  assign SMB_COMMAND   = cmd_command_q;
  assign SMB_STOP      = flag_stop_q & flag_cmd_latched_q;
  assign SMB_READ      = smb_read_q;
  assign SMB_WRITE     = smb_write_q;
  assign SMB_BYTEEN    = smb_writedata_en_q;
  assign SMB_WRITEDATA = smb_writedata_q;
  assign sda_rx        = SDA;

  // Look for rising/falling edges on SCL and SDA
  assign sda_rise = ~sda_q[1] &  sda_q[0];
  assign sda_fall =  sda_q[1] & ~sda_q[0];
  assign scl_rise = ~scl_q[1] &  scl_q[0];
  assign scl_fall =  scl_q[1] & ~scl_q[0];

  // Registers for localbus interface
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_SMB_Local
    if (~RESET_N) begin
      bitcounter_q         <= '0;
      smb_addr_q           <= '0;
      smb_read_q           <= '0;
      smb_write_q          <= '0;
    end
    else begin
      // Count the bits transferred in each state across the PMBus interface
      if (bitcounter_rst || flag_start_q)
        bitcounter_q       <= '0;
      else if (scl_rise && bitcounter_en)
        bitcounter_q       <= bitcounter_q + 1'b1;

      // Latch the current byte offset for the command being processed.  This is
      //   used to select the byte from the SMB_READDATA or SMB_WRITEDATA bus to
      //   be transferred or written to.
      if (~bitcounter_en)
        smb_addr_q         <= bitcounter_q[$high(bitcounter_q):3];

      // Continually shift data into the byte register on the rising edge of SCL
      if (scl_rise)
        smb_byte_q         <= {smb_byte_q[6:0], sda_q[0]};

      // Store the PMBus slave address for the current command.  Clear out the
      //   Avalon-MM writedata and writeenable signals, since this indicates
      //   the start of a new command.
      if (store_slave_addr) begin
        cmd_slave_addr_q   <= smb_byte_q;
        smb_writedata_q    <= {(MAX_BYTES*8){1'b0}};
        smb_writedata_en_q <= {MAX_BYTES{flag_cmd_latched_q & smb_byte_q[0]}};
      end

      // Store the PMBus command for the current command
      if (store_command)
        cmd_command_q      <= smb_byte_q;

      // Store the PMBus writedata for the current command into the appropriate
      //   byte of the Avalon-MM writedata bus, and assert the corresponding writeenable.
      if (store_data) begin
        smb_writedata_q[smb_addr_q]    <= smb_byte_q;
        smb_writedata_en_q[smb_addr_q] <= 1'b1;
      end

      // Assert read request once the slave address has been transferred.  This will
      //   latch in the complete set of data for the command to the shadow register,
      //   providing ample setup time for data transmission.
      if (store_slave_addr)
        smb_read_q         <= flag_cmd_latched_q & smb_byte_q[0];
      // Continue to assert the read request until SMB_WAITREQUEST is deasserted.
      if (smb_read_q && ~SMB_WAITREQUEST)
        smb_read_q         <= 1'b0;

      // Assert write request once the PMBus has completed transferring data for the
      //   current command.
      if (flag_cmd_latched_q)
        smb_write_q        <= flag_stop_q & ~cmd_slave_addr_q[0];
      // Continue to assert the write request until SMB_WAITREQUEST is deasserted.
      if (smb_write_q && ~SMB_WAITREQUEST)
        smb_write_q        <= 1'b0;

    end
  end: P_SMB_Local


  // This process implements a shadow register for the Avalon-MM readdata.  Shift the
  //   output readdata for the PMBus on the falling edge of SCL.
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_ShiftReadData
    if (~RESET_N) begin
      smb_readdata_q                 <= {(MAX_BYTES*8){1'b0}};
    end
    else begin
      // Capture the data that was read from the Avalon-MM interface the previous
      //   PMBus cycle earlier into the shadow register.
      if (store_readdata == 1'b1)
        smb_readdata_q <= SMB_READDATA;
      // Shift the data for each byte that is being transferred out to the left (MSB to LSB)
      else if (pmbus_currstate == ST_DATA_TX)
        if (scl_fall)
          smb_readdata_q[smb_addr_q] <= {smb_readdata_q[smb_addr_q][6:0], 1'b0};
    end
  end: P_ShiftReadData


  // Logic to detect START and STOP conditions as well as other events
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_StartStop
    if (~RESET_N) begin
      sda_q                <= 2'b1;
      scl_q                <= 2'b1;
      flag_start_q         <= 1'b0;
      flag_stop_q          <= 1'b0;
      flag_cmd_latched_q   <= 1'b0;
    end
    else begin
      sda_q                <= {sda_q[0], pmbus_debounce_q[1]};
      scl_q                <= {scl_q[0], pmbus_debounce_q[0]};
      flag_start_q         <= scl_q[0] & sda_fall;
      flag_stop_q          <= scl_q[0] & sda_rise;

      // Count the bits transferred in each subcycle across the PMBus interface
      if (flag_stop_q)
        flag_cmd_latched_q <= 1'b0;
      else if (store_command)
        flag_cmd_latched_q <= 1'b1;

    end
  end: P_StartStop


  // Sequential process that advances the PMBus state machine
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_SMB_SM_Sequential
    if (~RESET_N) begin
      pmbus_currstate   <= ST_IDLE;
    end
    else begin
      // When we detect a start condition, move to the address state
      if (flag_start_q)
        pmbus_currstate <= ST_SLAVE_ADDR;
      // When we detect a stop condition, move to the idle state
      else if (flag_stop_q)
        pmbus_currstate <= ST_IDLE;
      // Advance the state machine on the system clock boundary
      else
        pmbus_currstate <= pmbus_nextstate;
    end
  end: P_SMB_SM_Sequential

  // State machine that processes the incoming PMBus commands
  always @* begin : P_SMB_SM_Combinational
    // Default inactive assignments
    pmbus_nextstate           <= pmbus_currstate;
    store_slave_addr          <= 1'b0;
    store_command             <= 1'b0;
    store_readdata            <= 1'b0;
    store_data                <= 1'b0;
    bitcounter_rst            <= 1'b0;
    bitcounter_en             <= 1'b1;
    sda_tx                    <= 1'b1;

    case (pmbus_currstate)
      // Idle state.
      ST_IDLE: begin
        bitcounter_rst        <= 1'b1;
        // Remain in this state until an I2C Start condition is detected.
        if (flag_start_q)
          pmbus_nextstate     <= ST_SLAVE_ADDR;
      end

      // Shift in the address for the PMBus slave
      ST_SLAVE_ADDR: begin
        // After 8 SCL cycles, the slave address and r/w bit have shifted in.
        if ((bitcounter_q == 8) && scl_fall) begin
          // If our device is being addressed, send ACK after the falling edge of SCL
          if (smb_byte_q[7:1] == PMB_SLAVE_ADDR) begin
            store_slave_addr  <= 1'b1;
            pmbus_nextstate   <= ST_SLAVE_ACK;
          end
          // The address specifies a different slave; return to idle state.
          else
            pmbus_nextstate   <= ST_IDLE;
        end
      end

      // Acknowledge to the master that the slave address is being processed by this
      //   device.  Reset the PMBus bit counter.
      ST_SLAVE_ACK: begin
        sda_tx                <= 1'b0;
        bitcounter_rst        <= 1'b1;
        bitcounter_en         <= 1'b0;
        if (scl_fall) begin
          // If the command has been latched in, proceed to the read or write state.
          if (flag_cmd_latched_q) begin
            if (cmd_slave_addr_q[0] == 1'b0)
              pmbus_nextstate <= ST_DATA_RX;
            else begin
              store_readdata  <= 1'b1;
              pmbus_nextstate <= ST_DATA_TX;
            end
          end
          // Otherwise, proceed to latch in the PMBus command.
          else
            pmbus_nextstate   <= ST_COMMAND;
        end
      end

      // Shift in the command for the PMBus slave
      ST_COMMAND: begin
        // After 8 SCK cycles, the command has been shifted in.  Send ACK
        //   after the falling edge of SCL, and reset the bit counter
        if ((bitcounter_q == 8) && scl_fall) begin
          bitcounter_rst      <= 1'b1;
          store_command       <= 1'b1;
          pmbus_nextstate     <= ST_DATA_ACK;
        end
      end

      // Acknowledge that the command has been received.  Disable the bit
      //   counter during this state, since data is not being received or
      //   transmitted.
      ST_DATA_ACK: begin
        sda_tx                <= 1'b0;
        bitcounter_en         <= 1'b0;
        if (scl_fall) begin
          // Return to transmitting or receiving data bytes until the master
          //   indicates completion by sending a STOP signal.
          if (cmd_slave_addr_q[0] == 1'b0)
            pmbus_nextstate   <= ST_DATA_RX;
          else
            pmbus_nextstate   <= ST_DATA_TX;
        end
      end

      // Shift in the "write" data for the PMBus slave
      ST_DATA_RX: begin
        // After 8 SCK cycles, the writedata byte has shifted in.  Send an
        //   acknowledge to indicate reception of the data.
        if ((bitcounter_q[2:0] == 0) && scl_fall) begin
          store_data          <= 1'b1;
          pmbus_nextstate     <= ST_DATA_ACK;
        end
      end

      // Shift out the "read" data for the PMBus slave
      ST_DATA_TX: begin
         sda_tx               <= smb_readdata_q[smb_addr_q][7];
        // After 8 SCK cycles, the readdata byte has shifted out.  Check for
        //   an ACK or NACK from the master.
         if ((bitcounter_q[2:0] == 0) && scl_fall)
           pmbus_nextstate    <= ST_MASTER_ACK;
      end

      // Check for ACK/NACK from Master.  Disable the bit counter during
      //   this state, since data is not being received or transmitted.
      ST_MASTER_ACK: begin
        bitcounter_en         <= 1'b0;
        if (scl_fall) begin
          // If the master sends an ACK, continue to transmit read data.
          //   Otherwise, return to the idle state.
          if (~sda_q[1])
            pmbus_nextstate   <= ST_DATA_TX;
          else
            pmbus_nextstate   <= ST_IDLE;
        end
      end

    endcase
  end : P_SMB_SM_Combinational

endmodule : pmbus_slave