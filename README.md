# KASH — Personal Finance

**KASH** is a premium, minimalist personal finance tracker built for those who value clarity, privacy, and impeccable design. Inspired by the **Obsidian Curator** aesthetic, KASH provides a "Private Vault" experience for your finances—keeping your data local, your interface dark, and your financial goals within reach.

---

## Key Features

### 💎 Premium Design & UX
- **Obsidian Curator Theme**: A sophisticated dark mode interface with deep navy surfaces, indigo accents, and 1px architectural "hairline" borders.
- **Smooth Animations**: High-end transitions, including a sliding-scale FAB animation for adding transactions and fluid page-swipe navigation.
- **Privacy First**: 100% offline. No cloud syncing, no trackers, and no internet required. Your financial data stays encrypted on your device via **Hive**.

### 📊 Intelligent Tracking
- **Multi-Account Support**: Manage multiple bank accounts with custom logos and unique color coding.
- **Repetitive Expenses (Templates)**: Save frequent transactions (like "Morning Coffee") as templates for instant, one-tap entry from your home dashboard.
- **Smart Activity Feed**: Redesigned transaction tiles featuring category-specific iconography and subtle account context.
- **Interactive Insights**: Visualize your spending habits with dynamic category charts and monthly trend analysis.

### 🎯 Goal Oriented
- **Savings Goals**: Set visual targets for your big dreams—whether it's a new laptop or a summer vacation—and watch your progress grow in real-time.
- **Customizable Categories**: Fully personalize your expense and income categories through the profile settings to match your specific lifestyle.

### 👤 Personalized Profile
- **Adaptive Branding**: Tap to edit your name and set a custom profile picture with built-in square cropping for a perfect fit.
- **Theme Toggle**: Switch between light and dark modes instantly with a dedicated toggle in your settings.

---

## Tech Stack

KASH is engineered using modern Flutter development standards:
- **Framework**: [Flutter](https://flutter.dev/) (3.x)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Database**: [Hive](https://pub.dev/packages/hive) (NoSQL)
- **Data Visualization**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Asset Handling**: [flutter_svg](https://pub.dev/packages/flutter_svg) & [Lottie](https://pub.dev/packages/lottie)
- **Image Processing**: [image_cropper](https://pub.dev/packages/image_cropper) & [image_picker](https://pub.dev/packages/image_picker)

---

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.8.1)
- Dart SDK (>= 3.8.1)

### Installation
1. **Clone the repository**
   ```bash
   git clone https://github.com/whybhav360/kash.git
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Hive Adapters**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Launch the application**
   ```bash
   flutter run
   ```

---

## Screenshots

| Dashboard | Dark Mode | Insights | Goals |
| :---: | :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/7064f510-77e0-4540-bacd-7cba951829cf" width="200" /> | <img src="https://github.com/user-attachments/assets/5792be2a-2c84-46eb-a2e5-06d91eba64be" width="200" /> | <img src="https://github.com/user-attachments/assets/56a6ad40-2dbe-407c-aecc-d1c92e6e66c1" width="200" /> | <img src="https://github.com/user-attachments/assets/7e363425-aeee-4fdd-895e-875feafd9805" width="200" /> |

---

## Contribution & Contact

KASH is an open-source project. If you've found a bug or have a feature request, please feel free to open an issue or submit a pull request.

**Developed by Vaibhav Madaan**

- **LinkedIn**: [vaibhav360](https://www.linkedin.com/in/vaibhav360/)
- **GitHub**: [@whybhav360](https://github.com/whybhav360)

---
*Crafted with precision and a little help from Gemini.*
