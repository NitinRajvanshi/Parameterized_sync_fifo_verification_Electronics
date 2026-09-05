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

```systemverilog
DATA_WIDTH = 8
DEPTH      = 5
