# Shared Haven  

[![Flutter](https://img.shields.io/badge/Flutter-2.10-blue.svg)](https://flutter.dev)  
[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)  

**Shared Haven** is a Flutter (mobile/web) wallet / shared-fund / pooling app (work in progress). The idea is to let groups pool funds, share balances, and manage contributions all in one place.  

---

## 🚀 Features

- Multi-platform (iOS, Android, web) support via Flutter  
- Account / wallet management  
- Shared group balances / shared funds  
- Transaction tracking and reconciliation  
- Theming, localization, dark mode  
- Modular architecture for future expansion  

---

## 🎯 Why Shared Haven?

Shared Haven aims to be more than just a wallet. Think of it as a **co-funding / community wallet** where friends, roommates, or small groups can transparently manage a shared pot or expense pool.  

---

## 🧱 Architecture & Modules

Here’s a rough breakdown of how things are organized:

| Module | Purpose |
|---|---|
| **lib/** | Core Dart / Flutter code |
| **lib/models** | Models / data classes |
| **lib/services** | Abstractions for API / storage / business logic |
| **lib/ui / widgets** | Reusable UI components |
| **assets/** | Static assets (icons, images, translations) |
| **android / ios / web** | Platform-specific configs |

We follow **separation of concerns**, **clean architecture**, and aim for testability where possible.

---

## 🛠 Getting Started (Dev Guide)

### Prerequisites

- Flutter SDK (≥ stable version)  
- Dart SDK  
- A device emulator or browser for web  

### Setup

1. Clone the repo  
   ```bash
   git clone https://github.com/OpenOne2925/flutter_bitcoin.git
   cd shared_haven
   flutter run --flavor bitcoin_testnet