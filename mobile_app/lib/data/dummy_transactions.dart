class TransactionItem {
  final String id;
  final String type; // Cash In / Cash Out
  final double amount;
  final String status; // Success / Pending / Failed
  final DateTime date;
  final String counterparty; // Agent or shop name

  const TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.date,
    required this.counterparty,
  });
}

// TODO: Replace this dummy list with backend API transactions when available.
final List<TransactionItem> dummyTransactions = [
  TransactionItem(
    id: 'TXN1001',
    type: 'Cash In',
    amount: 1500.00,
    status: 'Success',
    date: DateTime(2025, 12, 27, 10, 30),
    counterparty: 'Sharma Kirana Store',
  ),
  TransactionItem(
    id: 'TXN1002',
    type: 'Cash Out',
    amount: 2200.50,
    status: 'Pending',
    date: DateTime(2025, 12, 26, 14, 15),
    counterparty: 'Metro Supermarket',
  ),
  TransactionItem(
    id: 'TXN1003',
    type: 'Cash In',
    amount: 800.00,
    status: 'Success',
    date: DateTime(2025, 12, 25, 9, 5),
    counterparty: 'Patil Cyber Cafe',
  ),
  TransactionItem(
    id: 'TXN1004',
    type: 'Cash Out',
    amount: 1200.75,
    status: 'Failed',
    date: DateTime(2025, 12, 24, 18, 40),
    counterparty: 'Bankar General Store',
  ),
  TransactionItem(
    id: 'TXN1005',
    type: 'Cash In',
    amount: 3000.00,
    status: 'Success',
    date: DateTime(2025, 12, 23, 12, 0),
    counterparty: 'City Mall Outlet',
  ),
  TransactionItem(
    id: 'TXN1006',
    type: 'Cash Out',
    amount: 950.25,
    status: 'Success',
    date: DateTime(2025, 12, 22, 16, 20),
    counterparty: 'Green Mart',
  ),
  TransactionItem(
    id: 'TXN1007',
    type: 'Cash In',
    amount: 1750.00,
    status: 'Pending',
    date: DateTime(2025, 12, 21, 11, 45),
    counterparty: 'Neighborhood Agent',
  ),
];
