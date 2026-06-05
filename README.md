# SIP Protocol — PROMELA Model

Formal verification of the SIP (Session Initiation Protocol) using **PROMELA** and the **SPIN model checker**.

Built as part of the Formal Methods course at the Department of Informatics and Telecommunications, University of the Peloponnese.

---

## Overview

This model simulates the communication between **2 SIP nodes (Alice and Bob)** through an **intermediate Proxy server**, covering:

- ✅ Normal call flow (INVITE → TRYING → RINGING → OK → ACK → RTP → BYE)
- ❌ Error cases (busy, rejected, unreachable subscriber)
- 📡 Message loss scenarios via a datalink layer with non-deterministic packet drops

---

## System Architecture

```
Alice ──► Datalink ──► Proxy ──► Datalink ──► Bob
Alice ◄── Datalink ◄── Proxy ◄── Datalink ◄── Bob
```

### Processes

| Process | Role |
|---|---|
| `Alice` | Caller — initiates and terminates the call |
| `Proxy` | Intermediate server — forwards messages between Alice and Bob |
| `Bob` | Callee — accepts, rejects, or ignores the call |
| `datalink` | Network layer — models message loss with non-deterministic drops |

---

## Message Types

| Message | Description |
|---|---|
| `INVITE` | Call initiation request |
| `TRYING100` | Proxy acknowledges the request |
| `RINGING180` | Bob's phone is ringing |
| `OK200` | Call accepted |
| `ACK` | Acknowledgement of OK200 |
| `RTP` | Media stream (audio) |
| `BYE` | Call termination request |
| `BYE_OK` | Acknowledgement of BYE |
| `BUSY` | Bob is busy |
| `REJECTED` | Bob rejected the call |

---

## Scenarios Covered

### 1. Normal Call Flow
Alice sends INVITE → Proxy forwards to Bob → Bob rings → Bob accepts → Alice ACKs → RTP stream → Alice sends BYE → Call ends cleanly.

### 2. Error Cases
- **Busy:** Bob responds with BUSY → Alice is notified → call aborted
- **Rejected:** Bob explicitly rejects → Alice is notified → call aborted
- **Unreachable:** Proxy retries up to `MAX_RETRIES` (3) → sends BUSY to Alice

### 3. Message Loss
The `datalink` process non-deterministically drops any message. All processes implement **retransmission logic** with a maximum of 3 retries before aborting.

---

## How to Run

### Requirements
- [SPIN model checker](http://spinroot.com) or [iSpin GUI](http://spinroot.com/spin/whatispin.html)

### Verification with iSpin
1. Open iSpin
2. Load `kalox.pml`
3. Run **Simulation** to trace a specific execution path
4. Run **Verification** to check for deadlocks and progress properties

### Command Line (SPIN)
```bash
spin -a kalox.pml       # Generate verifier
gcc -o pan pan.c        # Compile
./pan                   # Run verification
```

---

## Files

| File | Description |
|---|---|
| `kalox.pml` | PROMELA model — full system implementation |

---

## Author

**Dimitra Chrysikou**  
Department of Informatics and Telecommunications  
University of the Peloponnese  
[github.com/dimitrachrysikou](https://github.com/dimitrachrysikou)
