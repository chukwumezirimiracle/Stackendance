

# Stackendance - STX Proof of Attendance (POA)

A **Clarity smart contract** for issuing and managing **Proof of Attendance (POA) tokens** for multiple events on the Stacks blockchain. This system allows organizers to create events, track attendance through check-ins and check-outs, verify participation, and reward attendees in STX based on engagement and duration.

---

## 🚀 Features

* ✅ **Multi-event support**
* 🕒 **Timed check-in & check-out system**
* 🛡 **Verifier-based attendance validation**
* 🎁 **Tiered STX rewards system**
* 🔒 **Admin controls for event and verifier management**
* 💰 **On-chain treasury for deposits and reward disbursement**

---

## 🧱 Data Structures

### 🗂 Event Structure

Each event includes:

* `name`, `description`
* `start-height`, `end-height`
* `base-reward`, `bonus-reward`
* `min-attendance-duration`
* `organizer`, `is-active`

### 🧾 Attendance Tracking

Stores check-in/check-out block heights and attendance duration.

### ✅ Verification Details

Stores the `verified-by` and `verified-at` details once an attendee is verified.

### 🎖 Rewards Claimed

Tracks reward amount and tier per attendee per event.

### 🛡 Verifiers

A map of authorized addresses allowed to verify attendance.

---

## 📚 Functions

### 🧑‍💼 Admin Functions

* `add-verifier(principal)`
* `remove-verifier(principal)`
* `deactivate-event(event-id)`
* `deposit-funds(amount)`
* `withdraw-funds(amount)`

### 📆 Event Management

* `create-event(name, description, start-height, duration, base-reward, bonus-reward, min-attendance)`
* `get-event(event-id)`
* `event-exists(event-id)`

### ⏱ Attendance Lifecycle

* `check-in(event-id)`
* `check-out(event-id)`
* `get-attendance-record(event-id, attendee)`

### ✅ Verification

* `verify-attendance(event-id, attendee)`
* `can-verify-attendance(event-id, attendee)`
* `get-verification-details(event-id, attendee)`
* `get-full-verification-status(event-id, attendee)`

### 🎁 Reward Claiming

* `claim-reward(event-id)`
* `get-reward-claim(event-id, attendee)`

---

## 🧪 Validation & Security

* ✳️ Validations for event timing, string formatting, reward caps, and attendance duration.
* 🛡 Role-based access for contract owner and verifier addresses.
* 🔐 Funds safely managed in a contract treasury, only transferable by owner.

---

## ⚠ Error Codes

| Code    | Description                 |
| ------- | --------------------------- |
| `u100`  | Not authorized              |
| `u101`  | Already claimed             |
| `u102`  | Event not ended             |
| `u103`  | Event already ended         |
| `u104`  | No reward                   |
| `u105`  | Event not found             |
| `u106`  | Insufficient funds          |
| `u107`  | Invalid duration            |
| `u108`  | Already registered          |
| `u110`  | Invalid start height        |
| `u111`  | Invalid reward amount       |
| `u112`  | Invalid min attendance      |
| `u120`  | Event not active            |
| `u121`  | No check-in record          |
| `u122`  | Already verified            |
| `u123`  | Invalid attendee            |
| `u2000` | Invalid name                |
| `u2001` | Invalid description         |
| `u2002` | Contains invalid characters |

---

## 🏗 Setup & Deployment

This contract is written in **Clarity** and intended for deployment on the **Stacks blockchain**. Use [Clarinet](https://docs.hiro.so/clarinet/get-started) to test and deploy:

```bash
clarinet check
clarinet test
clarinet deploy
```

---

## 💡 Use Cases

* Web3 conferences or online workshops with reward-based attendance
* University courses or hackathons that incentivize full participation
* NFT drops tied to real-time event verification

---
