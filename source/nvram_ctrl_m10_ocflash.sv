////////////////////////////////////////////////////////////////////////////////////
//
// Module: nvram_ctrl_m10_ocflash
//
// Description: This module performs the accesses for storing event data to flash
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
// Current Assumptions/Limitations: Neither byte enables nor bit masks are currently
//   supported, although it would be rather simple to add that support.
//
////////////////////////////////////////////////////////////////////////////////////

`timescale 1 ps / 1 ps
module nvram_ctrl_m10_ocflash #(
  parameter                     VRAILS = 16,
  parameter                     P_ADDRSIZE = 11,
  parameter                     P_DATASIZE = 32
)(
  input                         CLOCK,
  input                         RESET_N,
  input                         FLASH_ERASEPAGE,
  input                         NVLOG_ERROR,
  input                         NVLOG_BBENA,
  input                 [7:0]   NVLOG_FAULTTYPE,
  input                 [7:0]   NVLOG_FAULTPAGE,
  input                [31:0]   NVLOG_TIMESTAMP,
  input        [VRAILS*2+1:0]   NVLOG_BBDATA,
  output reg            [7:0]   NVLOG_FLASHENTRIES_Q,
  output reg                    AVM_CSR_READ,
  output reg                    AVM_CSR_WRITE,
  input                         AVM_CSR_WAITREQUEST,
  output reg            [2:0]   AVM_CSR_ADDRESS,
  input      [P_DATASIZE-1:0]   AVM_CSR_READDATA,
  output reg [P_DATASIZE-1:0]   AVM_CSR_WRITEDATA,
  output reg                    AVM_DATA_READ,
  output reg                    AVM_DATA_WRITE,
  input                         AVM_DATA_WAITREQUEST,
  output reg [P_ADDRSIZE-1:0]   AVM_DATA_ADDRESS,
  input      [P_DATASIZE-1:0]   AVM_DATA_READDATA,
  output reg [P_DATASIZE-1:0]   AVM_DATA_WRITEDATA
);

  // This file contains the thresholds and command information for the voltage monitor
  import sequencer_vmon_pkg::*;

  // Import the structure containing the data for the read/write accesses that need to be performed
  localparam integer P_BBWRITES  = ((VRAILS*2+2+31)/32);  // round up, $ceil can't be synthesized
  localparam         P_WP_ALL  = 32'hFFFFFFFF;
  localparam         P_WE_UFM0 = 32'hFF7 << 20;
  localparam         P_WE_UFM1 = 32'hFEF << 20;

  // Enumerate a list of states for the FSM that performs accesses to the flash's data interface
  typedef enum int unsigned {
    ST_FLASH_IDLE,
    ST_FLASH_FINDEMPTY,
    ST_FLASH_WR_ERRORLOG,
    ST_FLASH_WR_ERRORTS,
    ST_FLASH_WR_BBDATA
  } t_seq_states;
  t_seq_states seq_state_q, seq_nextstate;
  // Enumerate a list of states for the FSM that performs accesses to the flash's control interface
  typedef enum int unsigned {
    ST_CSR_IDLE,
    ST_CSR_ERASE_CFM0PAGE0,
    ST_CSR_WR_ENA,
    ST_CSR_WR_PROT_CHKIDLE,
    ST_CSR_WR_PROT
  } t_csrseq_states;
  t_csrseq_states seq_csrstate_q, seq_nextcsrstate;

  reg                     reg_initdone_q = 1'b0;
  reg                     reg_erasepage_q;
  reg               [2:0] reg_nv_error_q;
  reg              [31:0] reg_faultdata_q;
  reg              [31:0] reg_faultts_q;
  reg [P_BBWRITES*32-1:0] reg_bbdata_q;
  reg               [5:0] cntr_q;
  reg                     csr_wr_clr;
  reg                     csr_wr_set;
  reg                     csr_erase_clr;
  reg                     flash_wr_prot;
  reg                     flash_wr_en;
  reg                     flash_wrena_q = 1'b0;
  reg                     cntr_en;
  reg                     cntr_rst;
  reg                     entries_en;
  reg                     entries_inc;
  reg                     log_full;
  reg                     bbdata_shift;
  
  // Registered process to implement various counter, shadow registers,
  //   and handshaking registers
  always_ff @(posedge CLOCK or negedge RESET_N) begin : P_MiscRegs
    if (~RESET_N) begin
      cntr_q               <=  'b0;
      NVLOG_FLASHENTRIES_Q <=  'b0;
      reg_nv_error_q       <=  'b0;
      reg_erasepage_q      <= 1'b0;
      flash_wrena_q        <= 1'b0;
      log_full             <= 1'b0;
      reg_faultdata_q      <=  'b0;
      reg_faultts_q        <=  'b0;
      reg_bbdata_q         <=  'b0;
      // Since it's fast, keep this initialization to recheck entries on every reset
      reg_initdone_q       <= 1'b0;
    end
    else if (CLOCK) begin
      // Implement address counter for the flash's data interface
      if      (cntr_rst == 1) cntr_q <= '0;
      else if (cntr_en  == 1) cntr_q <= cntr_q + 1'b1;
      else                    cntr_q <= cntr_q;
      // Capture error and status information from the voltage monitor register block
      //   when an error is identified
      reg_nv_error_q  <= {reg_nv_error_q[1:0], NVLOG_ERROR};
      if (reg_nv_error_q[1:0] == 2'b01) begin
        reg_faultdata_q <= {16'b0, NVLOG_FAULTTYPE, NVLOG_FAULTPAGE};
        reg_faultts_q   <= NVLOG_TIMESTAMP;
        reg_bbdata_q    <= NVLOG_BBDATA;
      end
      // If the request has been made to erase the flash page, store that request
      //   and keep it active until it has been processed and acknowledged
      if (FLASH_ERASEPAGE)     reg_erasepage_q <= 1'b1;
      else if (csr_erase_clr)  reg_erasepage_q <= 1'b0;
      // Store the current write-enable state of the flash.  We need to enable
      //   access before any write or erase operation, and protect it afterwards.
      if      (csr_wr_set) flash_wrena_q   <= 1'b1;
      else if (csr_wr_clr) flash_wrena_q   <= 1'b0;
      // Shift-right the blackbox data by a 32-bit word, each time a word is
      //   written to flash
      if (bbdata_shift) begin
        reg_bbdata_q   <= reg_bbdata_q >> 32;
      end
      // This is asserted after the state machine has finished scanning the flash
      //   to determine the current number of log entries written, and the next
      //   available slot.
      if (entries_en) begin
        NVLOG_FLASHENTRIES_Q <= cntr_q;
        reg_initdone_q      <= 1'b1;
      end
      else if (csr_erase_clr) NVLOG_FLASHENTRIES_Q <= 'b0;
      else if (entries_inc)   NVLOG_FLASHENTRIES_Q <= NVLOG_FLASHENTRIES_Q + 1'b1;
      // If the log is full, set a flag so we don't write to it.
      if (NVLOG_FLASHENTRIES_Q >= 32) log_full <= 1'b1; else log_full <= 1'b0;
    end
  end: P_MiscRegs

  // Sequential process that advances the state machines
  always_ff @(posedge CLOCK or negedge RESET_N) begin : fsm_sequential
    if (~RESET_N) begin
      seq_state_q    <= ST_FLASH_IDLE;
      seq_csrstate_q <= ST_CSR_IDLE;
    end
    else if (CLOCK) begin
      // Advance state machines to the next state
      seq_state_q    <= seq_nextstate;
      seq_csrstate_q <= seq_nextcsrstate;
    end
  end: fsm_sequential

  // State machine that performs the instruction command sequencing
  always @* begin : seq_combinatorial
    // Default inactive assignments
    AVM_DATA_READ      <= 1'b0;
    AVM_DATA_WRITE     <= 1'b0;
    AVM_DATA_ADDRESS   <=  'b0;
    AVM_DATA_WRITEDATA <=  'b0;
    flash_wr_en        <= 1'b0;
    flash_wr_prot      <= 1'b0;
    cntr_rst           <= 1'b0;
    cntr_en            <= 1'b0;
    entries_en         <= 1'b0;
    entries_inc        <= 1'b0;
    bbdata_shift       <= 1'b0;

    case (seq_state_q)
      // Idle state.  We remain in this state until we exit reset.
      ST_FLASH_IDLE: begin
        cntr_rst          <= 1'b1;
        // At POR, scan flash to find next empty location for writing
        if (!reg_initdone_q)
          seq_nextstate   <= ST_FLASH_FINDEMPTY;
        // If an error occurred, enable the sector for writing and
        //   write the log to flash if there is space to write
        else if ((reg_nv_error_q[2:1] == 2'b01) & !log_full) begin
          flash_wr_en     <= 1'b1;
          seq_nextstate   <= ST_FLASH_WR_ERRORLOG;
        end
        else
          seq_nextstate   <= ST_FLASH_IDLE;
      end

      // At POR, scan flash to find next empty location for writing
      ST_FLASH_FINDEMPTY: begin
        AVM_DATA_READ      <= 1'b1;
        AVM_DATA_WRITE     <= 1'b0;
        AVM_DATA_ADDRESS   <= (P_OFFSET_LOG | (cntr_q[4:0] << 1)) << 2;
        AVM_DATA_WRITEDATA <=  'b0;

        // The command has been executed when waitrequest is driven low.
        if (!AVM_DATA_WAITREQUEST) begin
          // Fault type bits 15:13 aren't used, are written to "000", and
          //   should be read as "111" for unused entries.  Or, exit if the
          //   entire flash space is written.
          if ((AVM_DATA_READDATA[15:13] == 3'h7) | (cntr_q[5])) begin
            seq_nextstate  <= ST_FLASH_IDLE;
            entries_en     <= 1'b1;
          end
          else begin
            // Increment to the next set of data when waitrequest is deasserted.
            seq_nextstate  <= ST_FLASH_FINDEMPTY;
            cntr_en        <= ~AVM_DATA_WAITREQUEST;
          end
        end
        else begin
          seq_nextstate    <= ST_FLASH_FINDEMPTY;
        end
      end

      // Write out the Error Log Data.  
      ST_FLASH_WR_ERRORLOG: begin
        AVM_DATA_READ      <= 1'b0;
        AVM_DATA_WRITE     <= flash_wrena_q;
        AVM_DATA_ADDRESS   <= (P_OFFSET_LOG | (NVLOG_FLASHENTRIES_Q << 1)) << 2;
        AVM_DATA_WRITEDATA <= reg_faultdata_q;
        flash_wr_en        <= ~flash_wrena_q;  // Assert write only when enabled
        // The command has been executed when waitrequest is driven low, wait for
        //   the CSR state machine to enable write accesses before continuing.
        if (!AVM_DATA_WAITREQUEST & flash_wrena_q)
          seq_nextstate    <= ST_FLASH_WR_ERRORTS;
        else 
          seq_nextstate    <= ST_FLASH_WR_ERRORLOG;
      end

      // Write out the Error Timestamp.  
      ST_FLASH_WR_ERRORTS: begin
        AVM_DATA_READ      <= 1'b0;
        AVM_DATA_WRITE     <= flash_wrena_q;
        AVM_DATA_ADDRESS   <= (P_OFFSET_LOG | (NVLOG_FLASHENTRIES_Q << 1) | 1'b1) << 2;
        AVM_DATA_WRITEDATA <= reg_faultts_q;
        flash_wr_en        <= ~flash_wrena_q;  // Assert write only when enabled
        // The command has been executed when waitrequest is driven low, wait for
        //   the CSR state machine to enable write accesses before continuing.
        if (!AVM_DATA_WAITREQUEST & flash_wrena_q) begin
          // If we are writing blackbox data, reset the address counter and
          //   proceed to that state
          if ((P_LOGGING_FUNCT_LEVEL == 2) & NVLOG_BBENA) begin
            cntr_rst       <= 1'b1;
            seq_nextstate  <= ST_FLASH_WR_BBDATA;
          end
          // Once we have completed writing the blackbox entries, write protect
          //   the flash.
          else begin
            flash_wr_prot  <= 1'b1;
            entries_inc    <= 1'b1;
            seq_nextstate  <= ST_FLASH_IDLE;
          end
        end
        else 
          seq_nextstate    <= ST_FLASH_WR_ERRORTS;
      end

      // Write out the BB Data (current state of all rails).  
      ST_FLASH_WR_BBDATA: begin
        AVM_DATA_READ      <= 1'b0;
        AVM_DATA_WRITE     <= flash_wrena_q;
        AVM_DATA_ADDRESS   <= (P_OFFSET_BBDATA | (NVLOG_FLASHENTRIES_Q << 4) | cntr_q[3:0]) << 2;
        AVM_DATA_WRITEDATA <= reg_bbdata_q[31:0];
        flash_wr_en        <= ~flash_wrena_q;  // Assert write only when enabled
        // The command has been executed when waitrequest is driven low, wait for
        //   the CSR state machine to enable write accesses before continuing.
        if (~AVM_DATA_WAITREQUEST & flash_wrena_q) begin;
          cntr_en          <= ~AVM_DATA_WAITREQUEST;
          bbdata_shift     <= 1'b1;
        end
        // The command has been executed when waitrequest is driven low, wait for
        //   the CSR state machine to enable write accesses before continuing.
        //   Once we have completed writing the blackbox entries, write protect
        //   the flash.
        if ((!AVM_DATA_WAITREQUEST) & flash_wrena_q & (cntr_q[4:0] >= (P_BBWRITES - 1))) begin
          flash_wr_prot     <= 1'b1;
          entries_inc       <= 1'b1;
          seq_nextstate     <= ST_FLASH_IDLE;
        end 
        else 
          seq_nextstate     <= ST_FLASH_WR_BBDATA;
      end

    endcase
  end : seq_combinatorial

  // State machine that performs the instruction command sequencing
  always @* begin : seq_csr_combinatorial
    // Default inactive assignments
    AVM_CSR_READ      <= 1'b0;
    AVM_CSR_WRITE     <= 1'b0;
    AVM_CSR_ADDRESS   <=  'b0;
    AVM_CSR_WRITEDATA <=  'b0;
    csr_wr_set        <= 1'b0;
    csr_wr_clr        <= 1'b0;
    csr_erase_clr     <= 1'b0;

    case (seq_csrstate_q)
      // Idle state.  We remain in this state until we exit reset.
      ST_CSR_IDLE: begin
        // Is there a request to erase the page of flash, and is the flash
        //   enabled for write access?
        if (reg_erasepage_q & flash_wrena_q)
          seq_nextcsrstate   <= ST_CSR_ERASE_CFM0PAGE0;
        // Is there a request to erase the page of flash or to enable write access?
        else if (flash_wr_en | reg_erasepage_q)
          seq_nextcsrstate   <= ST_CSR_WR_ENA;
        // Is there a request to write protect the flash?
        else if (flash_wr_prot) begin
          AVM_CSR_READ       <= 1'b1;
          AVM_CSR_ADDRESS    <= 3'h0; // Status Register
          seq_nextcsrstate   <= ST_CSR_WR_PROT_CHKIDLE;
        end
        else
          seq_nextcsrstate   <= ST_CSR_IDLE;
      end

      // Clear the write protect bit for UFM0.  
      ST_CSR_WR_ENA: begin
        AVM_CSR_WRITE        <= 1'b1;
        AVM_CSR_ADDRESS      <= 3'h4; // Control Register
        AVM_CSR_WRITEDATA    <= P_WE_UFM0 | 32'h000FFFFF;
        // The command has been executed when waitrequest is driven low.
        if (!AVM_CSR_WAITREQUEST) begin
          csr_wr_set         <= 1'b1;
          // If a request has been made to erase the page, move to
          //   that state, otherwise, go back to idle.
          if (reg_erasepage_q) 
            seq_nextcsrstate <= ST_CSR_ERASE_CFM0PAGE0;
          else
            seq_nextcsrstate <= ST_CSR_IDLE;
        end 
        else 
          seq_nextcsrstate   <= ST_CSR_WR_ENA;
      end

      // A second write to UFM0 with the WE set will erase page 0
      ST_CSR_ERASE_CFM0PAGE0: begin
        AVM_CSR_WRITE        <= 1'b1;
        AVM_CSR_ADDRESS      <= 3'h4; // Control Register
        AVM_CSR_WRITEDATA    <= P_WE_UFM0 | 32'h00000000;
        // The command has been executed when waitrequest is driven low.
        //   Write-protect the flash once it has been erased.
        if (!AVM_CSR_WAITREQUEST) begin
          csr_erase_clr      <= 1'b1;
          seq_nextcsrstate   <= ST_CSR_WR_PROT_CHKIDLE;
        end 
        else 
          seq_nextcsrstate   <= ST_CSR_ERASE_CFM0PAGE0;
      end

      // Check for the flash to be in an IDLE state before setting
      //   the write protect bit 
      ST_CSR_WR_PROT_CHKIDLE: begin
        AVM_CSR_READ         <= 1'b1;
        AVM_CSR_ADDRESS      <= 3'h0; // Status Register
        // The command has been executed when waitrequest is driven low.
        //   Is the flash idle or still processing an access?
        if (!AVM_CSR_WAITREQUEST & (AVM_CSR_READDATA[1:0] == 2'b0)) begin
          seq_nextcsrstate   <= ST_CSR_WR_PROT;
        end 
        else 
          seq_nextcsrstate   <= ST_CSR_WR_PROT_CHKIDLE;
      end

      // Set the write protect bit for UFM0.  
      ST_CSR_WR_PROT: begin
        AVM_CSR_WRITE        <= 1'b1;
        AVM_CSR_ADDRESS      <= 3'h4; // Control Register
        AVM_CSR_WRITEDATA    <= P_WP_ALL | 32'h000FFFFF;
        // The command has been executed when waitrequest is driven low.
        //   Acknowledge that the flash is protected by clearing out the internal
        //   status register.
        if (!AVM_CSR_WAITREQUEST) begin
          csr_wr_clr         <= 1'b1;
          seq_nextcsrstate   <= ST_CSR_IDLE;
        end 
        else 
          seq_nextcsrstate   <= ST_CSR_WR_PROT;
      end

    endcase
  end : seq_csr_combinatorial

endmodule