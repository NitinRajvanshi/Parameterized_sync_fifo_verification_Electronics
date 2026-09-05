# 🚀 Parameterized Synchronous FIFO — SystemVerilog Verification

> A complete RTL verification project demonstrating directed testing, randomized verification, reference-model scoreboarding, functional coverage, SystemVerilog Assertions (SVA), intentional bug injection, and class-based verification.

---

## 📌 Project Overview

This project implements and verifies a **parameterized synchronous FIFO** using Verilog/SystemVerilog.

The verification environment was developed progressively from basic directed testing to randomized verification, reference-model scoreboarding, functional coverage, SystemVerilog Assertions (SVA), bug injection, and class-based transaction verification.

The main objective was not only to verify that the FIFO works, but also to verify that the **verification environment can detect intentionally injected RTL bugs**.

### Final Results

| Metric | Result |
|---|---:|
| FIFO Type | Synchronous FIFO |
| Data Width | 8 bits |
| Test Depth | 5 |
| Regression | 10,000 transactions |
| Functional Coverage | **100% (7/7)** |
| Scoreboard Errors | **0** |
| RTL Bugs Injected | **3** |
| Non-Power-of-2 Depths Tested | **3, 5, 7, 10, 16** |
| Final Regression | **✅ PASSED** |

---

## 🏗️ FIFO Architecture

The FIFO contains:

- Memory array
- Write pointer
- Read pointer
- Occupancy counter
- Full flag
- Empty flag

### Parameters

systemverilog
DATA_WIDTH = 8
DEPTH      = 5

The design is parameterized so that different FIFO widths and depths can be verified without modifying the core RTL.

---

## 🔄 FIFO Operation

### Write Operation

A write is accepted when:

- `wr_en = 1`
- FIFO is not full

The write data is stored at the current write pointer and the pointer advances.

### Read Operation

A read is accepted when:

- `rd_en = 1`
- FIFO is not empty

The data is read from the current read pointer and the pointer advances.

### Simultaneous Read + Write

The FIFO supports simultaneous read and write operations.

An important corner case is **FULL + simultaneous READ/WRITE**. When the FIFO is full, a read occurring in the same cycle frees one location, allowing the write to proceed.

```systemverilog
wire do_read  = rd_en && !empty;
wire do_write = wr_en && (!full || do_read);
