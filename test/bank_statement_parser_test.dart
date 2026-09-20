import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:test_money/models/transaction.dart';
import 'package:test_money/services/bank_statement_parser.dart';

void main() {
  group('BankStatementParser Tests', () {
    test('detectBank identifies Indian banks accurately', () {
      expect(BankStatementParser.detectBank('Welcome to HDFC BANK statement'), 'HDFC Bank');
      expect(BankStatementParser.detectBank('STATE BANK OF INDIA e-Statement'), 'State Bank of India');
      expect(BankStatementParser.detectBank('ICICI BANK LIMITED Statement of Account'), 'ICICI Bank');
      expect(BankStatementParser.detectBank('AXIS BANK LTD Statement'), 'Axis Bank');
      expect(BankStatementParser.detectBank('KOTAK MAHINDRA BANK Account Statement'), 'Kotak Mahindra Bank');
      expect(BankStatementParser.detectBank('PUNJAB NATIONAL BANK Savings Statement'), 'Punjab National Bank');
      expect(BankStatementParser.detectBank('Random Overseas Bank'), 'Bank Statement');
    });

    test('detectAccountNumber finds masked account numbers', () {
      expect(BankStatementParser.detectAccountNumber('Account No: 50100234567890'), '50100234567890');
      expect(BankStatementParser.detectAccountNumber('A/c No.: XXXXXX123456'), 'XXXXXX123456');
    });

    test('categorize maps merchant and transaction keywords accurately', () {
      // Food
      expect(BankStatementParser.categorize('UPI-SWIGGY-1234-PAYMENT', TransactionType.expense), 'Food');
      expect(BankStatementParser.categorize('Zomato Order #8921', TransactionType.expense), 'Food');
      expect(BankStatementParser.categorize('STARBUCKS COFFEE IND', TransactionType.expense), 'Food');
      expect(BankStatementParser.categorize('Blinkit Commerce', TransactionType.expense), 'Food');
      expect(BankStatementParser.categorize('Zepto Marketplace', TransactionType.expense), 'Food');

      // Transport
      expect(BankStatementParser.categorize('Uber India Systems', TransactionType.expense), 'Transport');
      expect(BankStatementParser.categorize('Ola Cabs Mobility', TransactionType.expense), 'Transport');
      expect(BankStatementParser.categorize('HPCL PETROL PUMP MUMBAI', TransactionType.expense), 'Transport');
      expect(BankStatementParser.categorize('IRCTC E-TICKETING', TransactionType.expense), 'Transport');

      // Shopping
      expect(BankStatementParser.categorize('AMAZON PAY INDIA', TransactionType.expense), 'Shopping');
      expect(BankStatementParser.categorize('Flipkart Internet Pvt Ltd', TransactionType.expense), 'Shopping');
      expect(BankStatementParser.categorize('DMART SUPERMARKET', TransactionType.expense), 'Shopping');

      // Entertainment
      expect(BankStatementParser.categorize('Netflix Services', TransactionType.expense), 'Entertainment');
      expect(BankStatementParser.categorize('Spotify India AB', TransactionType.expense), 'Entertainment');
      expect(BankStatementParser.categorize('BookMyShow Cinema', TransactionType.expense), 'Entertainment');

      // Health
      expect(BankStatementParser.categorize('APOLLO PHARMACY BANGALORE', TransactionType.expense), 'Health');
      expect(BankStatementParser.categorize('1mg Healthcare Solutions', TransactionType.expense), 'Health');

      // Income
      expect(BankStatementParser.categorize('SALARY CREDIT FOR AUGUST', TransactionType.income), 'Salary');
      expect(BankStatementParser.categorize('INTEREST CREDIT FROM FD', TransactionType.income), 'Investment');
      expect(BankStatementParser.categorize('CASHBACK REWARD CRED', TransactionType.income), 'Gift');
    });

    test('parses HDFC Bank statement text format', () {
      const hdfcSample = '''
HDFC BANK LIMITED
Account Branch: CONNAUGHT PLACE
Account No: 50100987654321
Date        Narration                             Chq/Ref No   Value Dt   Withdrawal Amt   Deposit Amt   Closing Balance
01/08/2024  UPI-SWIGGY-PAYTM0123-PAYMENT           421456123456 01/08/2024 450.00                         24,550.00
05/08/2024  ACH D-NETFLIX ENTERTAINMENT           000000009871 05/08/2024 649.00                         23,901.00
10/08/2024  NEFT CR-TECH CORP LTD-SALARY          N24123456789 10/08/2024                  75,000.00     98,901.00
15/08/2024  UPI-UBER-TRIP1234-DELHI                422456789012 15/08/2024 320.00                         98,581.00
''';

      final result = BankStatementParser.parseStatementText(hdfcSample);

      expect(result.bankName, 'HDFC Bank');
      expect(result.accountNumber, '50100987654321');
      expect(result.transactions.length, 4);

      // Swiggy expense
      final t1 = result.transactions[0];
      expect(t1.amount, 450.0);
      expect(t1.type, TransactionType.expense);
      expect(t1.category, 'Food');
      expect(t1.balance, 24550.0);

      // Netflix expense
      final t2 = result.transactions[1];
      expect(t2.amount, 649.0);
      expect(t2.type, TransactionType.expense);
      expect(t2.category, 'Entertainment');

      // Salary credit
      final t3 = result.transactions[2];
      expect(t3.amount, 75000.0);
      expect(t3.type, TransactionType.income);
      expect(t3.category, 'Salary');
      expect(t3.balance, 98901.0);

      // Uber expense
      final t4 = result.transactions[3];
      expect(t4.amount, 320.0);
      expect(t4.type, TransactionType.expense);
      expect(t4.category, 'Transport');
    });

    test('parses SBI (State Bank of India) statement text format', () {
      const sbiSample = '''
State Bank of India
Account Name: Vaibhav
Account Number: 00000030123456789
Txn Date    Value Date  Description                                 Ref No./Cheque No.  Debit       Credit      Balance
12 Jan 2024 12 Jan 2024 TO TRANSFER-UPI/DR/401234/ZOMATO/ORDER        TRANSFER TO 4012    350.00                  15,200.00
15 Jan 2024 15 Jan 2024 TO TRANSFER-UPI/DR/401567/AMAZON INDIA       TRANSFER TO 4015    1,499.00                13,701.00
20 Jan 2024 20 Jan 2024 BY TRANSFER-UPI/CR/402999/REFUND             TRANSFER FROM 4029              500.00      14,201.00
''';

      final result = BankStatementParser.parseStatementText(sbiSample);

      expect(result.bankName, 'State Bank of India');
      expect(result.transactions.length, 3);

      expect(result.transactions[0].amount, 350.0);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].category, 'Food');

      expect(result.transactions[1].amount, 1499.0);
      expect(result.transactions[1].type, TransactionType.expense);
      expect(result.transactions[1].category, 'Shopping');

      expect(result.transactions[2].amount, 500.0);
      expect(result.transactions[2].type, TransactionType.income);
    });

    test('parses PNB (Punjab National Bank) statement format', () {
      const pnbSample = '''
Punjab National Bank
Statement of Account for A/c No: 0123000100123456
Txn Date   Value Date Description                       Cheque No  Debit (Dr)   Credit (Cr)   Balance
02/05/2024 02/05/2024 UPI/DR/4123/STARBUCKS/PAYMENT                380.00                     22,100.00
05/05/2024 05/05/2024 SALARY CR/TECH CORP PRIVATE LIMITED                       85,000.00     1,07,100.00
''';

      final result = BankStatementParser.parseStatementText(pnbSample);

      expect(result.bankName, 'Punjab National Bank');
      expect(result.transactions.length, 2);

      expect(result.transactions[0].amount, 380.0);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].category, 'Food');

      expect(result.transactions[1].amount, 85000.0);
      expect(result.transactions[1].type, TransactionType.income);
      expect(result.transactions[1].category, 'Salary');
    });

    test('parses ICICI Bank statement format', () {
      const iciciSample = '''
ICICI Bank Statement
Account Number: 001101234567
Date        Particulars                                    Chq No  Withdrawal (Dr) Deposit (Cr)  Balance
10/06/2024  UPI/4033221144/Blinkit/blinkit@icici                   540.00                        34,000.00
12/06/2024  UPI/4033221155/Apollo Pharmacy                         280.00                        33,720.00
''';

      final result = BankStatementParser.parseStatementText(iciciSample);

      expect(result.bankName, 'ICICI Bank');
      expect(result.transactions.length, 2);
      expect(result.transactions[0].amount, 540.0);
      expect(result.transactions[0].category, 'Food');
      expect(result.transactions[1].amount, 280.0);
      expect(result.transactions[1].category, 'Health');
    });

    test('parses Axis Bank statement format', () {
      const axisSample = '''
Axis Bank Limited
Account No: 919010012345678
Date        Transaction Details                            Dr/Cr  Amount     Balance
14-07-2024  UPI/Uber India/12345/DR                        DR     250.00     18,500.00
18-07-2024  UPI/Myntra Designs/54321/DR                    DR     1,299.00   17,201.00
''';

      final result = BankStatementParser.parseStatementText(axisSample);

      expect(result.bankName, 'Axis Bank');
      expect(result.transactions.length, 2);
      expect(result.transactions[0].amount, 250.0);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].category, 'Transport');
      expect(result.transactions[1].amount, 1299.0);
      expect(result.transactions[1].type, TransactionType.expense);
      expect(result.transactions[1].category, 'Shopping');
    });

    test('throws PdfParsingException when text contains no transactions', () {
      expect(
        () => BankStatementParser.parseStatementText('This is just a random text document with no banking tables.'),
        throwsA(isA<PdfParsingException>()),
      );
    });

    test('handles password protected PDF documents in-memory', () {
      // Create a password protected PDF in memory using syncfusion_flutter_pdf
      final document = PdfDocument();
      document.security.userPassword = 'secretPassword123';
      final page = document.pages.add();
      page.graphics.drawString(
        'HDFC BANK LIMITED\nDate Narration Chq/Ref No Value Dt Withdrawal Amt Deposit Amt Closing Balance\n01/08/2024 UPI-SWIGGY-123 123 01/08/2024 450.00 12,000.00',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
      );
      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      // 1. Without password -> Throws PdfPasswordProtectedException
      expect(
        () => BankStatementParser.parsePdfBytes(bytes),
        throwsA(isA<PdfPasswordProtectedException>()),
      );

      // 2. With incorrect password -> Throws PdfInvalidPasswordException
      expect(
        () => BankStatementParser.parsePdfBytes(bytes, password: 'wrongPassword'),
        throwsA(isA<PdfInvalidPasswordException>()),
      );

      // 3. With correct password -> Successfully unlocks and parses!
      final result = BankStatementParser.parsePdfBytes(bytes, password: 'secretPassword123');
      expect(result.bankName, 'HDFC Bank');
      expect(result.transactions.length, 1);
      expect(result.transactions.first.amount, 450.0);
      expect(result.transactions.first.category, 'Food');
    });

    test('parses columnar PDF table drawn column-by-column (Finacle Axis / PNB format)', () {
      final document = PdfDocument();
      final page = document.pages.add();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 10);

      // Header
      page.graphics.drawString('AXIS BANK LTD', font, bounds: Rect.fromLTWH(40, 20, 200, 20));
      page.graphics.drawString('Account No: 919010012345678', font, bounds: Rect.fromLTWH(40, 40, 200, 20));

      // Draw table column-by-column (as bank engines do)
      // Column 1: Dates (uppercase month, 2-digit year)
      page.graphics.drawString('01-MAY-24', font, bounds: Rect.fromLTWH(40, 100, 70, 20));
      page.graphics.drawString('05-MAY-24', font, bounds: Rect.fromLTWH(40, 130, 70, 20));

      // Column 2: Particulars
      page.graphics.drawString('UPI/4123456789/Zomato/Order', font, bounds: Rect.fromLTWH(120, 100, 160, 20));
      page.graphics.drawString('SALARY CREDIT TECH CORP', font, bounds: Rect.fromLTWH(120, 130, 160, 20));

      // Column 3: Debit
      page.graphics.drawString('450.00', font, bounds: Rect.fromLTWH(300, 100, 60, 20));
      page.graphics.drawString('0.00', font, bounds: Rect.fromLTWH(300, 130, 60, 20));

      // Column 4: Credit
      page.graphics.drawString('0.00', font, bounds: Rect.fromLTWH(370, 100, 60, 20));
      page.graphics.drawString('80000.00', font, bounds: Rect.fromLTWH(370, 130, 60, 20));

      // Column 5: Balance
      page.graphics.drawString('14550.00', font, bounds: Rect.fromLTWH(440, 100, 60, 20));
      page.graphics.drawString('94550.00', font, bounds: Rect.fromLTWH(440, 130, 60, 20));

      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      final result = BankStatementParser.parsePdfBytes(bytes);
      expect(result.bankName, 'Axis Bank');
      expect(result.transactions.length, 2);

      // Zomato
      expect(result.transactions[0].amount, 450.0);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].category, 'Food');
      expect(result.transactions[0].date.year, 2024);
      expect(result.transactions[0].date.month, 5);
      expect(result.transactions[0].date.day, 1);

      // Salary
      expect(result.transactions[1].amount, 80000.0);
      expect(result.transactions[1].type, TransactionType.income);
      expect(result.transactions[1].category, 'Salary');
      expect(result.transactions[1].balance, 94550.0);
    });

    test('parses PNB statement with serial numbers, double dates, and uppercase months', () {
      const pnbRealSample = '''
PUNJAB NATIONAL BANK
Statement of Account for A/c No: 0123000100123456
IFSC: PUNB0012300
S.No  Txn Date     Value Date   Description                               Cheque No   Withdrawal    Deposit       Balance
1     05-MAY-2024  05-MAY-2024  UPI/DR/4123456789/SWIGGY/ORDER                         380.00                      22,100.00
2     10-MAY-2024  10-MAY-2024  SALARY CR/TECH CORP PRIVATE LIMITED                                  85,000.00     1,07,100.00
3     15-MAY-2024  15-MAY-2024  UPI/DR/4123999999/UBER/TRIP                            290.00                      1,06,810.00
''';

      final result = BankStatementParser.parseStatementText(pnbRealSample);
      expect(result.bankName, 'Punjab National Bank');
      expect(result.transactions.length, 3);

      expect(result.transactions[0].amount, 380.0);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].category, 'Food');
      expect(result.transactions[0].date.month, 5);

      expect(result.transactions[1].amount, 85000.0);
      expect(result.transactions[1].type, TransactionType.income);
      expect(result.transactions[1].category, 'Salary');

      expect(result.transactions[2].amount, 290.0);
      expect(result.transactions[2].type, TransactionType.expense);
      expect(result.transactions[2].category, 'Transport');
    });

    test('parses Axis Bank statement with Dr/Cr suffixes and running balance delta', () {
      const axisRealSample = '''
AXIS BANK LTD
A/c No: 919010012345678
IFSC Code: UTIB0000123
Tran Date   Particulars                             Chq No   Amount         Balance
10-06-2024  UPI/4033221144/Blinkit/blinkit@icici             540.00(Dr)     34,000.00
12-06-2024  BY TRANSFER/NEFT/SALARY                          50,000.00(Cr)  84,000.00
15-06-2024  UPI/4033221155/Apollo Pharmacy                   280.00         83,720.00
''';

      final result = BankStatementParser.parseStatementText(axisRealSample);
      expect(result.bankName, 'Axis Bank');
      expect(result.transactions.length, 3);

      expect(result.transactions[0].amount, 540.0);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].category, 'Food');

      expect(result.transactions[1].amount, 50000.0);
      expect(result.transactions[1].type, TransactionType.income);
      expect(result.transactions[1].category, 'Salary');

      // 3rd has no explicit Dr/Cr suffix, but balance decreased from 84,000 to 83,720
      expect(result.transactions[2].amount, 280.0);
      expect(result.transactions[2].type, TransactionType.expense);
      expect(result.transactions[2].category, 'Health');

      // Opening balance mathematically calculated: 34,000 + 540 = 34,540
      expect(result.openingBalance, 34540.0);
    });

    test('extracts explicit opening balance from header if present', () {
      const pnbWithOpeningBalance = '''
PUNJAB NATIONAL BANK
Account Number: 0123456789012345
Opening Balance : 50,000.00
Txn Date    Value Date  Description                      Cheque No   Debit      Credit     Balance
01-07-2024  01-07-2024  UPI/SWIGGY/12345678                          450.00                49,550.00
''';
      final result = BankStatementParser.parseStatementText(pnbWithOpeningBalance);
      expect(result.bankName, 'Punjab National Bank');
      expect(result.openingBalance, 50000.0);
    });

    test('parses PNB statement in reverse-chronological order with Cr balance suffix', () {
      // PNB mPassbook often displays newest transactions first, and balances with "Cr" suffix
      const pnbReverseSample = '''
PUNJAB NATIONAL BANK - MPASSBOOK
Account No : 0123000100987654
Date        Value Date   Details                                         Amount       Balance
15/06/2024  15/06/2024   POS / RELIANCE RETAIL NEW DELHI                 1,250.00     25,250.00 Cr
10/06/2024  10/06/2024   TO TRANSFER-INB / ELECTRICITY BILL              2,500.00     26,500.00 Cr
01/06/2024  01/06/2024   BY SALARY CREDIT / TECH CORP                   50,000.00     29,000.00 Cr
''';

      final result = BankStatementParser.parseStatementText(pnbReverseSample);
      expect(result.bankName, 'Punjab National Bank');
      expect(result.accountNumber, '0123000100987654');
      expect(result.transactions.length, 3);

      // Newest: 15/06/2024 Reliance Retail (Balance went from 26,500 down to 25,250 => Expense)
      final t1 = result.transactions[0];
      expect(t1.amount, 1250.0);
      expect(t1.type, TransactionType.expense);
      expect(t1.category, 'Shopping');
      expect(t1.balance, 25250.0);

      // Middle: 10/06/2024 Electricity bill (Balance went from 29,000 down to 26,500 => Expense)
      final t2 = result.transactions[1];
      expect(t2.amount, 2500.0);
      expect(t2.type, TransactionType.expense);
      expect(t2.category, 'Rent');

      // Oldest: 01/06/2024 Salary (Deposit of 50,000 => Income)
      final t3 = result.transactions[2];
      expect(t3.amount, 50000.0);
      expect(t3.type, TransactionType.income);
      expect(t3.category, 'Salary');
    });

    test('parses PNB statement with timestamps in txn/value dates and multi-line narration', () {
      const pnbTimestampSample = '''
NETPNB INTERNET BANKING
Statement for Account: 1234002100012345
Txn Date             Value Date           Particulars                                       Amount    Balance
05-MAY-2024 14:22:10 05-MAY-2024 14:22:10 UPI/412345678901/ZOMATO RESTAURANT                 420.00   18,580.00
12-MAY-2024 09:10:00 12-MAY-2024 09:10:00 UPI/412399999999/INDIAN OIL PETROL PUMP            1,000.00   17,580.00
''';

      final result = BankStatementParser.parseStatementText(pnbTimestampSample);
      expect(result.bankName, 'Punjab National Bank');
      expect(result.accountNumber, '1234002100012345');
      expect(result.transactions.length, 2);

      expect(result.transactions[0].amount, 420.0);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].category, 'Food');
      expect(result.transactions[0].date.year, 2024);
      expect(result.transactions[0].date.month, 5);
      expect(result.transactions[0].date.day, 5);

      expect(result.transactions[1].amount, 1000.0);
      expect(result.transactions[1].type, TransactionType.expense);
      expect(result.transactions[1].category, 'Transport');
    });

    test('PNB statement does NOT misidentify as SBI when narrations contain @sbi or SBIN', () {
      const pnbWithSbiTxns = '''
PUNJAB NATIONAL BANK
Statement of Account for A/c No: 0123000100987654
IFSC: PUNB0012300
Date        Particulars                                    Amount     Balance
01-09-2026  UPI/DR/662483905643/Vinod Ku/SBIN/vinod@sbi    20.0       7,935.05
02-09-2026  UPI/DR/625896808392/Amazon I/UTIB/amazon@apl   394.0      7,541.05
''';

      final result = BankStatementParser.parseStatementText(pnbWithSbiTxns);
      expect(result.bankName, 'Punjab National Bank');
      expect(result.transactions.length, 2);
      expect(result.transactions[0].amount, 20.0);
      expect(result.transactions[0].description, 'Vinod Ku');
      expect(result.transactions[1].amount, 394.0);
      expect(result.transactions[1].description, 'Amazon I');
    });

    test('parses PNB/Finacle layout from user image with 1-decimal amounts and remarks at end', () {
      const userImageSample = '''
PUNJAB NATIONAL BANK - PNB ONE
Statement of Account: 0123000100987654
Date        Instrument ID  Amount(INR)  Type  Balance   Remarks
16/09/2026                 70.0         DR    7805.05   UPI/DR/662588224268/Lalit Ku/PPIW/7070963001@fam/P
16/09/2026                 60.0         DR    7875.05   UPI/DR/662586061704/PARVEEN/PUNB/7042106 194@ibl/Pa
15/09/2026                 20.0         DR    7935.05   UPI/DR/662483905643/Vinod Ku/YESB/paytmqr6exel5@p/
15/09/2026                 394.0        DR    7955.05   UPI/DR/625896808392/Amazon I/UTIB/amazonupi@apl/Re
15/09/2026                 50.0         DR    8349.05   UPI/DR/662480483040/RAM PAL/PUNB/rampalyadav3612/P
15/09/2026                 20.0         DR    8399.05   UPI/DR/662474730041/Amir jui/YESB/q705687787@ybl/P
15/09/2026                 2.0          CR    8419.05   UPI/CR/479737782586/Google P/UTIB/playstore1.bd@a/
15/09/2026                 2.0          DR    8417.05   UPI/DR/479708492586/Google P/UTIB/playstore1.bd@a/
15/09/2026                 60.0         DR    8419.05   UPI/DR/662471454510/PARVEEN/PUNB/7042106 194@ibl/Pa
14/09/2026                 35.0         DR    8479.05   UPI/DR/662369387655/Meena/YESB/q829462435@ybl/Paid
14/09/2026                 20.0         DR    8514.05   UPI/DR/662369102696/Vinod Ku/YESB/paytmqr6exel5@p/
14/09/2026                 50.0         DR    8534.05   UPI/DR/662366129696/Preeti D/PUNB/9599675849@ptye/
14/09/2026                 70.0         DR    8584.05   UPI/DR/662360511213/RAMESH Y/YESB/paytm.s2wfwrw@p/
''';

      final result = BankStatementParser.parseStatementText(userImageSample);
      expect(result.bankName, 'Punjab National Bank');
      expect(result.transactions.length, 13);

      // Row 1: 16/09/2026, Lalit Ku, 70.0 DR, balance 7805.05
      final r1 = result.transactions[0];
      expect(r1.amount, 70.0);
      expect(r1.type, TransactionType.expense);
      expect(r1.balance, 7805.05);
      expect(r1.description, 'Lalit Ku');

      // Row 4: 15/09/2026, Amazon I, 394.0 DR, Shopping
      final r4 = result.transactions[3];
      expect(r4.amount, 394.0);
      expect(r4.type, TransactionType.expense);
      expect(r4.description, 'Amazon I');
      expect(r4.category, 'Shopping');

      // Row 7: 15/09/2026, Google P, 2.0 CR, Income
      final r7 = result.transactions[6];
      expect(r7.amount, 2.0);
      expect(r7.type, TransactionType.income);
      expect(r7.description, 'Google P');
      expect(r7.balance, 8419.05);

      // Row 8: 15/09/2026, Google P, 2.0 DR, Expense
      final r8 = result.transactions[7];
      expect(r8.amount, 2.0);
      expect(r8.type, TransactionType.expense);
      expect(r8.description, 'Google P');
      expect(r8.balance, 8417.05);

      // Row 10: 14/09/2026, Meena, 35.0 DR
      final r10 = result.transactions[9];
      expect(r10.amount, 35.0);
      expect(r10.type, TransactionType.expense);
      expect(r10.description, 'Meena');

      // Row 13: 14/09/2026, RAMESH Y, 70.0 DR
      final r13 = result.transactions[12];
      expect(r13.amount, 70.0);
      expect(r13.type, TransactionType.expense);
      expect(r13.description, 'RAMESH Y');
      expect(r13.balance, 8584.05);
    });

    test('ignores Opening Balance and Total lines, preventing phantom 8L+ transactions', () {
      const statementWith8LOpeningBalance = '''
PUNJAB NATIONAL BANK
Statement of Account for A/c No: 0123000100987654
Sanction Limit: 8,00,000.00
Date        Instrument ID  Amount(INR)  Type  Balance       Remarks
01/09/2026  OPENING BALANCE                   8,50,000.00   B/F
05/09/2026                 450.0        DR    8,49,550.00   UPI/DR/4123/SWIGGY/ORDER
10/09/2026                 1,200.0      DR    8,48,350.00   UPI/DR/4124/ZOMATO/ORDER
16/09/2026  TOTAL                             1,650.00      TOTAL DEBITS: 8,50,000.00
''';

      final result = BankStatementParser.parseStatementText(statementWith8LOpeningBalance);
      expect(result.bankName, 'Punjab National Bank');
      // Must NOT include the 8,50,000.00 opening balance or total as a transaction
      expect(result.transactions.length, 2);
      expect(result.transactions.every((t) => t.amount < 10000), isTrue);

      expect(result.transactions[0].amount, 450.0);
      expect(result.transactions[0].type, TransactionType.expense);
      expect(result.transactions[0].category, 'Food');

      expect(result.transactions[1].amount, 1200.0);
      expect(result.transactions[1].type, TransactionType.expense);
      expect(result.transactions[1].category, 'Food');

      // Opening balance captured properly without polluting transaction list
      expect(result.openingBalance, 850000.0);
    });
  });
}
