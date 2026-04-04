# Kash - Smart Money Tracking

**Kash** is a modern, minimalist personal finance tracker built to help you master your money with zero stress. Designed for clarity and privacy, Kash keeps your financial data exactly where it belongs—on your device.

## Why Kash

- **Clean Dashboard**: A beautiful, unified view of your total balance, income, and expenses at a glance.
- **Smart Insights**: Interactive category-based charts with monthly filtering to spot spending trends instantly.
- **Goal Oriented**: Set savings goals for your dreams (like a new laptop or vacation) and track your progress in real-time.
- **Effortless Activity**: Log transactions in seconds. Use the built-in filters to see exactly where your money goes.
- **Privacy First**: Completely offline-first. No cloud, no tracking, no internet required. Your data is stored locally using Hive.
- **Modern UI**: Smooth animations, intuitive gestures (like hold-to-delete), and a calming design language.

---

## Tech Stack

Built with high-performance, modern Android development practices:
- **Flutter**: For a smooth, native-feeling cross-platform experience.
- **Provider**: Clean state management for a responsive UI.
- **Hive**: Lightning-fast, local NoSQL database for offline persistence.
- **fl_chart**: Dynamic, responsive data visualizations.
- **Clean Architecture**: Decoupled UI, providers, and services for easy maintainability.

---

## Want to try it on your own?
(P.S. You can just download the APK from the releases tab)

Want to go deep and get more control?
1. **Clone the repository**
   ```bash
   git clone https://github.com/whybhav360/kash.git
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

---

## Project Structure

- `lib/models/`: Data structures (Transaction, Goal, etc.).
- `lib/providers/`: Business logic and state management.
- `lib/screens/`: Feature-specific UI (Home, Activity, Insights, Goals).
- `lib/services/`: Database (Hive) initialization.
- `lib/widgets/`: Reusable UI components (Transaction tiles, Goal cards, etc.).

---

## Let's Connect!

Found a bug or have a feature request? Feel free to open an issue or submit a pull request.

---
Made By -> Vaibhav Madaan

LinkedIn: https://www.linkedin.com/in/vaibhav360/

GitHub: https://github.com/whybhav360

and a lot of boilerplate by Gemini