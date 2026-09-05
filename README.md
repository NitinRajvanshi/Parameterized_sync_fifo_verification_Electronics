# 🚀 Parameterized Synchronous FIFO — RTL Verification

<p align="center">

**A complete SystemVerilog RTL verification project**

Directed Testing • Randomized Testing • Scoreboarding • Coverage • SVA • Bug Injection • Class-Based Verification

</p>

---

## ⚡ Project at a Glance

| Metric | Result |
|---|---:|
| FIFO Type | Synchronous |
| Data Width | 8 bits |
| Test Depth | 5 |
| Regression | 10,000 transactions |
| Functional Coverage | **100% (7/7)** |
| Scoreboard Errors | **0** |
| RTL Bugs Injected | **3** |
| SVA Checks | **3** |
| Non-Power-of-2 Depths Tested | **3, 5, 7, 10, 16** |
| Final Regression | **✅ PASSED** |

---

## 🧠 What I Built

This project started with a parameterized FIFO RTL and evolved into a
multi-layer verification environment.

The verification strategy was built progressively:

```text
                 ┌──────────────────┐
                 │   FIFO RTL DUT   │
                 └────────┬─────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
   Directed Tests   Randomized Tests       SVA
        │                 │                 │
        └─────────────────┼─────────────────┘
                          ▼
                    Scoreboard
                          │
                          ▼
                     Coverage
                          │
                          ▼
                 Bug Injection
                          │
                          ▼
              Class-Based Verification
