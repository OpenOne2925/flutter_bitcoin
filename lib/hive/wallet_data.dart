import 'package:hive/hive.dart';

part 'wallet_data.g.dart'; // Needed for Hive TypeAdapter (generated)

@HiveType(typeId: 0)
class WalletData extends HiveObject {
  @HiveField(0)
  String address;

  @HiveField(1)
  int balance;

  @HiveField(2)
  int ledgerBalance;

  @HiveField(3)
  int availableBalance;

  @HiveField(4)
  List<Map<String, dynamic>> transactions; // Store transaction IDs or details

  WalletData({
    required this.address,
    required this.balance,
    required this.ledgerBalance,
    required this.availableBalance,
    required this.transactions,
  });
}
