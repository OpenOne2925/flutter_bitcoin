import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:hive/hive.dart';

class WalletStorageService {
  // Open the Hive box
  Future<Box<WalletData>> openBox() async {
    return await Hive.openBox<WalletData>('walletDataBox');
  }

  // Save wallet data to Hive
  Future<void> saveWalletData(String walletId, WalletData walletData) async {
    // print(walletData.address);

    var box = await openBox();
    await box.put(walletId, walletData); // Use a key to store the wallet data
  }

  // Load wallet data from Hive
  Future<WalletData?> loadWalletData(String walletId) async {
    try {
      var box =
          await openBox(); // Safely open or access the existing box      WalletData? walletData =
      WalletData? walletData =
          box.get(walletId); // Retrieve the wallet data using the walletId

      return walletData;
    } catch (e) {
      print('Error loading wallet data: $e');
      return null; // Return null if the wallet is not found or an error occurs
    }
  }

  // Check if wallet data exists
  Future<bool> walletDataExists() async {
    var box = await openBox();
    return box.containsKey('walletData');
  }

  // Clear wallet data
  Future<void> clearWalletData() async {
    var box = await openBox();
    await box.delete('walletData');
  }
}
