# KASH — Personal Finance & Wealth Vault

**KASH** is a premium, minimalist personal finance tracker built for those who value clarity, privacy, and impeccable design. Inspired by the **Obsidian Curator** aesthetic, KASH provides a "Private Vault" experience for your finances—keeping your data local, your interface dark, and your financial goals within reach.

---

## 🚀 What's New & Key Features

### 🏦 Automated Bank Statement Parser & PDF Import
- **Instant Statement Ingestion**: Upload PDF bank statements from major banks (Axis, HDFC, SBI, ICICI, PNB, Kotak, etc.).
- **Smart Parsing**: Automatically extracts transaction details, dates, amounts, bank names, and account numbers.
- **Interactive Review**: Review, categorize, and verify parsed transactions in an intuitive staging screen before committing them to your vault.

### 🔄 Account-to-Account Transfers
- **Seamless Fund Transfers**: Move money between your various bank accounts with dedicated transfer tracking and balance updates.

### 💾 Backup & Restore (JSON Vault)
- **Local Data Portability**: Export your complete financial database to a secure JSON backup file and restore anytime.
- **100% Privacy**: No cloud required. Your financial backups remain entirely under your control on your device.

### 📄 Professional PDF Reports
- **Financial Statements**: Generate detailed PDF financial summaries and reports powered by Syncfusion PDF.

### 💎 Premium Design & UX (Obsidian Curator Theme)
- **Sophisticated Aesthetics**: Deep navy surfaces, vibrant emerald/indigo accents, and 1px architectural hairline borders.
- **Fluid Interactions**: Smooth sliding-scale FAB animations, category-specific iconography, and dynamic trend charts (`fl_chart`).
- **Privacy First**: Completely offline and secure local storage via **Hive**.

### 🎯 Savings Goals & Insights
- **Goal Tracking**: Set visual savings targets for major life goals and monitor progress in real time.
- **Analytics Dashboard**: Visualize your income vs. expense trends with interactive charts.

---

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (3.x)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Database**: [Hive](https://pub.dev/packages/hive) (NoSQL encrypted local vault)
- **Data Visualization**: [fl_chart](https://pub.dev/packages/fl_chart)
- **PDF Generation & Parsing**: [syncfusion_flutter_pdf](https://pub.dev/packages/syncfusion_flutter_pdf) & custom regex bank parsers
- **Image Processing**: [image_cropper](https://pub.dev/packages/image_cropper) & [image_picker](https://pub.dev/packages/image_picker)

---

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.8.1)
- Dart SDK (>= 3.10.0)

### Installation & Building
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

4. **Build APK**
   - **Debug APK**: `flutter build apk --debug`
   - **Release APK**: `flutter build apk --release`
   - Output path: `build/app/outputs/flutter-apk/app-release.apk`

---

## Screenshots


---

## Author & Contribution

**Developed by Vaibhav Madaan**

- **LinkedIn**: [vaibhav360](https://www.linkedin.com/in/vaibhav360/)
- **GitHub**: [@whybhav360](https://github.com/whybhav360)

---
*Crafted with precision and a little help from Gemini.*
