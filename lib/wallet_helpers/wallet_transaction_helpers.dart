import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletTransactionHelpers {
  final BuildContext context;
  final int currentHeight;
  final String address;

  WalletTransactionHelpers({
    required this.context,
    required this.currentHeight,
    required this.address,
  });

  void showTransactionsDialog(Map<String, dynamic> transaction) {
    final txid = transaction['txid'];

    // Extract confirmation details
    final blockHeight = transaction['status']?['block_height'];
    final isConfirmed = blockHeight != null;
    final unformattedBlockTime = transaction['status']['block_time'] ?? 0;

    final blockTime = isConfirmed
        ? DateTime.fromMillisecondsSinceEpoch(
            unformattedBlockTime * 1000,
          ).add(Duration(hours: -2))
        : 'Unconfirmed';

    print(blockTime);

    // Extract transaction fee
    final fee = transaction['fee'] ?? 0;

    // Extract all input addresses (senders)
    final Set<String> inputAddresses = (transaction['vin'] as List<dynamic>)
        .map((vin) => vin['prevout']['scriptpubkey_address'] as String)
        .toSet();

    // Extract all ouput addresses (receivers
    final Set<String> outputAddresses = (transaction['vout'] as List<dynamic>)
        .map((vout) => vout['scriptpubkey_address'] as String)
        .toSet();

    final int totalOutput = transaction['vout']?.fold<int>(
          0,
          (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
        ) ??
        0;

    // Determine if transaction is sent, received, or internal
    final bool isSent = inputAddresses.contains(address);
    final bool isReceived = outputAddresses.contains(address);
    final bool isInternal = inputAddresses.length == 1 &&
        inputAddresses.contains(address) &&
        outputAddresses.length == 1 &&
        outputAddresses.contains(address);

    // Determine the actual amount sent/received
    int amount = 0;

    if (isInternal) {
      amount = totalOutput;
    } else if (isSent) {
      amount = transaction['vout']
              ?.where((vout) =>
                  vout['scriptpubkey_address'] !=
                  address) // Exclude own address
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    } else if (isReceived) {
      amount = transaction['vout']
              ?.where((vout) =>
                  vout['scriptpubkey_address'] ==
                  address) // Include own address
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    }

    final rootContext = context;

    // Build the dialog
    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Transaction Details',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Transaction Type
                      Text(
                        isInternal
                            ? "Internal Transaction"
                            : isSent
                                ? 'Sent Transaction'
                                : 'Received Transaction',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Sender Addresses
                      const Text(
                        "Senders",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: inputAddresses.map((sender) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    sender,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      overflow: TextOverflow
                                          .ellipsis, // Handle long addresses
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy,
                                      color: Colors.green, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: sender));
                                    ScaffoldMessenger.of(rootContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Copied to clipboard: $sender'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),

                      // Receiver Addresses
                      const Text(
                        "Receivers",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: outputAddresses.map((receiver) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    receiver,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      overflow: TextOverflow
                                          .ellipsis, // Handle long addresses
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy,
                                      color: Colors.green, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: receiver));
                                    ScaffoldMessenger.of(rootContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Copied to clipboard: $receiver'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),

                      // Amount Sent/Received
                      const Text(
                        "Amount",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        "$amount satoshis",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Transaction Fee
                      if (isSent || isInternal) ...[
                        const Text(
                          "Transaction Fee",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          "$fee satoshis",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Confirmation Details
                      const Text(
                        "Confirmation Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        isConfirmed
                            ? "Confirmed at block: $blockHeight"
                            : "Status: Unconfirmed",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      if (isConfirmed)
                        Text(
                          "Block Time: $blockTime",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      GestureDetector(
                        onTap: () async {
                          final Uri url = Uri.parse(
                              "https://mempool.space/testnet4/tx/$txid/");

                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          } else {
                            throw "Could not launch $url";
                          }
                        },
                        child: Text(
                          "Visit the Mempool",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildTransactionItem(Map<String, dynamic> tx) {
    // Extract confirmation status
    final blockHeight = tx['status']?['block_height'];
    final confirmations =
        blockHeight != null ? currentHeight - blockHeight : -1;
    final isConfirmed = confirmations >= 0;

    // Transaction fee
    final fee = tx['fee'] ?? 0;

    // Extract all input addresses (senders) and their total input value
    final inputAddresses = (tx['vin'] as List<dynamic>?)
            ?.map((vin) => vin['prevout']?['scriptpubkey_address'] as String?)
            .where((addr) => addr != null)
            .toSet() ??
        <String>{};

    // Extract all output addresses (receivers) and their total output value
    final outputAddresses = (tx['vout'] as List<dynamic>?)
            ?.map((vout) => vout['scriptpubkey_address'] as String?)
            .where((addr) => addr != null)
            .toSet() ??
        {};

    final totalOutput = tx['vout']?.fold<int>(
          0,
          (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
        ) ??
        0;

    // Check if transaction is sent, received, or internal
    final isSent = inputAddresses.contains(address); // Sent transaction
    final isReceived =
        outputAddresses.contains(address); // Received transaction
    final isInternal = inputAddresses.length == 1 &&
        inputAddresses.contains(address) &&
        outputAddresses.length == 1 &&
        outputAddresses.contains(address); // Internal transaction

    // Determine the amount sent/received
    int amount = 0;

    if (isInternal) {
      amount = totalOutput; // Full amount in an internal transaction
    } else if (isSent) {
      amount = tx['vout']
              ?.where((vout) =>
                  vout['scriptpubkey_address'] !=
                  address) // Exclude own address
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    } else if (isReceived) {
      amount = tx['vout']
              ?.where((vout) =>
                  vout['scriptpubkey_address'] ==
                  address) // Include only own address
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    }

    // Extract specific sender/recipient address
    String? counterpartyAddress;

    if (isSent) {
      counterpartyAddress = outputAddresses
          .where((addr) => addr != address) // Exclude own address
          .join(', ');
    } else if (isReceived) {
      // If multiple input addresses exist, the sender is likely the one contributing the most BTC.
      if (inputAddresses.isNotEmpty) {
        counterpartyAddress =
            inputAddresses.first; // Default to the first sender

        // Find the input with the highest value (likely the fee payer)
        int highestInputValue = 0;
        String? feePayerAddress;

        for (var vin in tx['vin']) {
          String? inputAddr = vin['prevout']?['scriptpubkey_address'];
          int inputValue = vin['prevout']?['value'] ?? 0;

          if (inputAddr != null && inputValue > highestInputValue) {
            highestInputValue = inputValue;
            feePayerAddress = inputAddr;
          }
        }

        // Use the highest input as the sender if found
        if (feePayerAddress != null) {
          counterpartyAddress = feePayerAddress;
        }
      }
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 2,
      color: isInternal
          ? Colors.amber
          : isSent
              ? Colors.redAccent[100]
              : Colors.tealAccent,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  isConfirmed ? Icons.check_circle : Icons.timelapse,
                  color: isConfirmed ? Colors.green : Colors.amber,
                ),
                Text(
                  // Show only the fee payed for internal transactions
                  isInternal
                      ? "Internal: - $fee satoshis"
                      : '${isSent ? "Sent: - " : "Received: + "}$amount satoshis',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.green),
              ],
            ),
            const SizedBox(height: 4),
            if (!isInternal)
              Text(
                isSent
                    ? "To: $counterpartyAddress"
                    : "From: $counterpartyAddress",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            const SizedBox(height: 4),
            if (isSent && !isInternal)
              Text(
                isInternal
                    ? '$fee satoshis spent in fees'
                    : 'Fee: $fee satoshis',
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
          ],
        ),
      ),
    );
  }
}
