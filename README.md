<div align="center">

# ☕ APOS: Athar Point of Sale

A premium, responsive, and secure Point of Sale (POS) system built with **Flutter** and **Supabase**. Designed to bring a modern, fluid, and robust operational experience to retail environments, cafes, and artisanal businesses.

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![Riverpod](https://img.shields.io/badge/Riverpod-State%20Management-blue.svg)](https://riverpod.dev/)

</div>

---

## ✨ Features

- **Omnichannel Responsive UI**: Seamlessly adapts between Desktop/Tablet registers and Mobile terminals.
- **Premium "Stitch" Design System**: Beautiful custom UI with fluid animations, glassmorphism effects, and built-in Dark/Light modes.
- **Advanced POS Terminal**: 
  - Dynamic cart management with stock limit protections.
  - Multi-payment support (Cash, Card, QRIS).
  - Floating responsive cart for mobile environments.
- **Role-Based Access Control (RBAC)**: securely scopes access using PostgreSQL RLS policies.
  - **Cashier**: Access to terminal and profile settings.
  - **Admin**: Full access including financial dashboards and inventory management.
- **Real-Time Inventory Management**: Create, update, delete, and restock products with live category filtering.
- **Interactive Analytics Dashboard**: Beautiful visual metrics via `fl_chart` tracking daily revenue, monthly trends, and top-selling products.
- **Secure Authentication**: Backed by Supabase Auth with custom user profile triggers.

<br>

## 🛠 Tech Stack

### Frontend (Application Layer)
*   **Framework**: [Flutter](https://flutter.dev/)
*   **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
*   **Routing**: [GoRouter](https://pub.dev/packages/go_router) for deep linking and declarative routing.
*   **Typography**: [Google Fonts](https://pub.dev/packages/google_fonts) (Manrope & Inter)
*   **Charts**: [FlChart](https://pub.dev/packages/fl_chart) for interactive dashboards.

### Backend (BaaS)
*   **Database**: PostgreSQL hosted via [Supabase](https://supabase.com/).
*   **Authentication**: Supabase Auth (Email / Password).
*   **Security**: Row Level Security (RLS) policies tightly coupled with custom schema triggers.

<br>

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (3.22.0 or higher recommended)
*   Dart SDK
*   A Supabase Project

### 1. Supabase Setup
First, execute the required SQL schema directly in your Supabase SQL Editor. This will set up the foundational auth triggers, tables, and RLS policies.

*(Ensure you have run your local `auth_profiles.sql` schema which contains the `profiles` table, `handle_new_user` trigger, and constraints).*

### 2. Environment Variables
Clone the repository and set up your Supabase keys. You can provide these directly through your provider configuration or securely through Dart define statements/environment files.

```bash
git clone <your-repo-link>
cd POS/app
```

### 3. Run the App
Install dependencies and run the application on your preferred platform (Chrome, Windows, iOS, or Android).

```bash
flutter pub get
flutter run -d chrome
```

<br>

## 🔒 Security Architecture (RBAC)

APOS uses a robust pattern where the `auth.users` state seamlessly syncs with a `public.profiles` table using PostgreSQL database triggers.

*   When a new user signs up, a trigger automatically drops them into the `profiles` table with a default `cashier` constraint.
*   Riverpod providers (`authStateProvider` -> `userProfileProvider`) reactively push these role states down to the UI.
*   `GoRouter` redirects are locked dynamically via a refresh listenable; if a `cashier` attempts to navigate to the `/dashboard`, they are securely intercepted and redirected to `/pos`.

<br>

## 🎨 Design Philosophy

Built around the "Velvet Roast Nocturne" aesthetic paradigm:
- **Surfaces:** Floating cards, subtle gradients, high-contrast borders.
- **Typography:** Hierarchy driven by `Manrope` (Headers) and `Inter` (Body).
- **Feedback:** Haptic-driven button responses, animated opacity for out-of-stock items, and custom artisanal snacking bars.

<br>

## 📝 License

This project is licensed under the MIT License.
