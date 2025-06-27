import 'package:flutter/material.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart' as liquid_sdk;
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/lightning/receive_bitcoin_bottom_sheet.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/lightning/receive_liquid_bottom_sheet.dart';
import 'package:flutter_wallet/lightning/send_bitcoin_bottom_sheet.dart';
import 'package:flutter_wallet/lightning/send_liquid_bottom_sheet.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/wallet_pages/qr_scanner_page.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LightningPage extends StatefulWidget {
  final String mnemonic;

  const LightningPage({super.key, required this.mnemonic});

  @override
  State<LightningPage> createState() => _LightningPageState();
}

class _LightningPageState extends State<LightningPage> {
  int _balance = 0;
  int _pendingSend = 0;
  int _pendingReceive = 0;

  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initBreez();
  }

  @override
  void dispose() {
    disconnect();

    super.dispose();
  }

  Future<void> _initBreez() async {
    try {
      const breezApiKey =
          "MIIBfTCCAS+gAwIBAgIHPi2AYT27hzAFBgMrZXAwEDEOMAwGA1UEAxMFQnJlZXowHhcNMjUwNjE3MDgwOTU2WhcNMzUwNjE1MDgwOTU2WjAvMRswGQYDVQQKExJPcGVuT25lIENvbnN1bHRpbmcxEDAOBgNVBAMTB0NpcHJpYW4wKjAFBgMrZXADIQDQg/XL3yA8HKIgyimHU/Qbpxy0tvzris1fDUtEs6ldd6OBiDCBhTAOBgNVHQ8BAf8EBAMCBaAwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU2jmj7l5rSw0yVb/vlWAYkK/YBwkwHwYDVR0jBBgwFoAU3qrWklbzjed0khb8TLYgsmsomGswJQYDVR0RBB4wHIEacHJvZHV6aW9uZTI5MjVAb3Blbi1vbmUuaXQwBQYDK2VwA0EAS5upQbf8CFqd9TCANEQwMOy+bJO8/zYxEaNNhSczOps8t2+bVgzXMyeFV8idEFuSPL+5eZazfPlf3DL4Gb+BBg==";

      final appDir = await getApplicationDocumentsDirectory();

      // Create config
      var config = liquid_sdk.defaultConfig(
        network: liquid_sdk.LiquidNetwork.testnet,
        breezApiKey: breezApiKey,
      );

      config = config.copyWith(workingDir: appDir.path);

      final connectRequest = liquid_sdk.ConnectRequest(
        mnemonic: widget.mnemonic,
        config: config,
      );

      await breezSDKLiquid.connect(req: connectRequest);
      await fetchBalance();

      setState(() {
        _loading = false;
      });
    } catch (e, st) {
      print("Init error: $e");
      print(st);
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void disconnect() {
    breezSDKLiquid.disconnect();
  }

  Future<void> _refreshLightning() async {
    // await breezSDKLiquid.instance!.sync();
    await fetchBalance();
  }

  Future<void> fetchBalance() async {
    liquid_sdk.GetInfoResponse? info = await breezSDKLiquid.instance!.getInfo();
    BigInt balanceSat = info.walletInfo.balanceSat;
    BigInt pendingSendSat = info.walletInfo.pendingSendSat;
    BigInt pendingReceiveSat = info.walletInfo.pendingReceiveSat;

    setState(() {
      _balance = balanceSat.toInt();
      _pendingSend = pendingSendSat.toInt();
      _pendingReceive = pendingReceiveSat.toInt();
    });
  }

  Future<void> _createInvoice(BuildContext context) async {
    try {
      final limits = await breezSDKLiquid.instance!.fetchLightningLimits();
      // print(
      //   "Receive min: ${limits.receive.minSat}, max: ${limits.receive.maxSat}",
      // );

      // Ask user for amount
      final controller = TextEditingController();
      final amountSat = await DialogHelper.buildCustomStatefulDialog<BigInt?>(
        context: context,
        titleKey: "enter_amount", // Use your i18n key or replace with string
        showCloseButton: true,
        showAssistant: false,
        assistantMessages: const ["Specify how much you'd like to receive."],
        contentBuilder: (setDialogState, updateAssistant) {
          return TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "Amount in sats"),
          );
        },
        actionsBuilder: (setDialogState) {
          return [
            InkwellButton(
              onTap: () {
                final parsed = BigInt.tryParse(controller.text.trim());
                Navigator.of(context, rootNavigator: true).pop(parsed);
              },
              label: AppLocalizations.of(context)!.translate('create_invoice'),
              backgroundColor: AppColors.background(context),
              textColor: AppColors.text(context),
              icon: Icons.payment,
              iconColor: AppColors.gradient(context),
            ),
          ];
        },
      );

      if (amountSat == null ||
          amountSat < limits.receive.minSat ||
          amountSat > limits.receive.maxSat) {
        SnackBarHelper.showError(
          context,
          message: AppLocalizations.of(context)!.translate('invalid_amount'),
        );

        return;
      }

      final receiveAmount = liquid_sdk.ReceiveAmount_Bitcoin(
        payerAmountSat: amountSat,
      );
      final prepareResponse =
          await breezSDKLiquid.instance!.prepareReceivePayment(
        req: liquid_sdk.PrepareReceiveRequest(
          paymentMethod: liquid_sdk.PaymentMethod.bolt11Invoice,
          amount: receiveAmount,
        ),
      );

      String optionalDescription = "description";

      liquid_sdk.ReceivePaymentResponse res =
          await breezSDKLiquid.instance!.receivePayment(
        req: liquid_sdk.ReceivePaymentRequest(
          description: optionalDescription,
          prepareResponse: prepareResponse,
        ),
      );

      final invoice = res.destination;

      await DialogHelper.buildCustomStatefulDialog<void>(
        context: context,
        titleKey: "bolt11_invoice",
        contentBuilder: (setDialogState, updateAssistantMessage) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: invoice,
                    version: QrVersions.auto,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Amount: $amountSat sats",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          );
        },
        actionsBuilder: (setDialogState) {
          return [
            IconButton(
              icon: Icon(
                Icons.copy,
                color: AppColors.cardTitle(context),
              ),
              tooltip: 'Copy to clipboard',
              onPressed: () {
                UtilitiesService.copyToClipboard(
                  context: context,
                  text: invoice,
                  messageKey: 'invoice_clipboard',
                );
              },
            ),
          ];
        },
        showCloseButton: true,
        showAssistant: false, // or true if you'd like it active here
        assistantMessages: const [
          "Scan this QR to pay the invoice.",
          "You can copy it if needed."
        ],
      );
    } catch (e) {
      // print("Invoice creationg failed: $e");

      SnackBarHelper.showError(
        context,
        message: AppLocalizations.of(context)!.translate('invoice_error'),
      );
    }
  }

  Future<void> _payInvoice(BuildContext context) async {
    final controller = TextEditingController();

    String? bolt11 = await DialogHelper.buildCustomStatefulDialog<String?>(
      context: context,
      titleKey: 'enter_bolt11_invoice',
      showCloseButton: true,
      showAssistant: false,
      assistantMessages: const ["Paste or scan the Lightning invoice to pay."],
      contentBuilder: (setState, updateAssistant) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText:
                    AppLocalizations.of(context)!.translate('paste_invoice'),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan QR Code',
                  onPressed: () {
                    // 🚨 Pop the dialog and signal "scan requested"
                    Navigator.of(context, rootNavigator: true).pop('__scan__');
                  },
                ),
              ),
            ),
          ],
        );
      },
      actionsBuilder: (setDialogState) => [
        InkwellButton(
          onTap: () {
            final value = controller.text.trim();
            Navigator.of(context, rootNavigator: true).pop(value);
          },
          label: AppLocalizations.of(context)!.translate('pay'),
          backgroundColor: AppColors.background(context),
          textColor: AppColors.text(context),
          icon: Icons.payment,
          iconColor: AppColors.gradient(context),
        ),
      ],
    );

// 🚨 Check for scan trigger
    if (bolt11 == '__scan__') {
      final scanned = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => QRScannerPage(
            title: 'Scan Lightning Invoice',
            isValid: isValidBolt11,
            extractValue: (val) => val,
          ),
        ),
      );

      if (scanned != null && scanned.isNotEmpty) {
        controller.text = scanned;

        // 🔁 Reopen dialog with scanned value prefilled
        bolt11 = await DialogHelper.buildCustomStatefulDialog<String?>(
          context: context,
          titleKey: 'enter_bolt11_invoice',
          showCloseButton: true,
          showAssistant: false,
          assistantMessages: const ["Invoice scanned. Confirm to pay."],
          contentBuilder: (setState, updateAssistant) {
            return TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText:
                    AppLocalizations.of(context)!.translate('paste_invoice'),
              ),
            );
          },
          actionsBuilder: (setDialogState) => [
            InkwellButton(
              onTap: () {
                final value = controller.text.trim();
                Navigator.of(context, rootNavigator: true).pop(value);
              },
              label: AppLocalizations.of(context)!.translate('pay'),
              backgroundColor: AppColors.background(context),
              textColor: AppColors.text(context),
              icon: Icons.payment,
              iconColor: AppColors.gradient(context),
            ),
          ],
        );
      }
    }

    if (bolt11 == null || bolt11.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invoice is empty.")),
      );
      return;
    }

    try {
      final prepare = await breezSDKLiquid.instance!.prepareSendPayment(
        req: liquid_sdk.PrepareSendRequest(destination: bolt11),
      );

      final fees = prepare.feesSat;
      // print("Estimated fees: $fees sats");

      final confirm = await DialogHelper.buildCustomStatefulDialog<bool>(
        context: context,
        titleKey: "confirm_payment",
        showCloseButton: true,
        showAssistant: false,
        assistantMessages: const ["Ready to send the payment?"],
        contentBuilder: (_, __) {
          return Text(
            "Pay invoice?\nEstimated fee: $fees sats",
            style: const TextStyle(fontSize: 16),
          );
        },
        actionsBuilder: (_) => [
          InkwellButton(
            onTap: () => Navigator.of(context, rootNavigator: true).pop(true),
            label: AppLocalizations.of(context)!.translate('send'),
            backgroundColor: AppColors.background(context),
            textColor: AppColors.text(context),
            icon: Icons.payment,
            iconColor: AppColors.gradient(context),
          ),
        ],
      );

      if (confirm != true) return;

      // final sendResponse =
      await breezSDKLiquid.instance!.sendPayment(
        req: liquid_sdk.SendPaymentRequest(prepareResponse: prepare),
      );

      // final payment = sendResponse.payment;
      // print('Payment: $payment');

      SnackBarHelper.show(context, message: 'payment_sent');
    } catch (e) {
      // print("Error sending payment: $e");
      SnackBarHelper.showError(context, message: 'failed_payment: $e)');
    }
  }

  void _liquidOperations(
    BuildContext context,
    String operation,
  ) {
    if (operation == "receive") {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (context) => ReceiveLiquidBottomSheet(),
      );
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (context) => SendLiquidBottomSheet(),
      );
    }
  }

  void _bitcoinOperations(
    BuildContext context,
    String operation,
  ) {
    if (operation == "receive") {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (context) => ReceiveBitcoinBottomSheet(),
      );
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (context) => SendBitcoinBottomSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: const Text("Lightning Wallet"),
          backgroundColor: AppColors.primary(context),
        ),
        body: Center(
          child: Text(
            "Error initializing SDK:\n$_error",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text(context)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text("⚡ Breez Lightning Wallet"),
        backgroundColor: AppColors.primary(context),
        foregroundColor: AppColors.white(),
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLightning,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 🪙 Wallet Card
            walletInfoCard(context),

            const SizedBox(height: 24),

            // ⚡ Send / Receive Buttons
            Column(
              children: [
                _assetActionButton(
                  icon: Icons.bolt,
                  label: "Lightning",
                  onTap: () => _showActionSheet(context, "lightning"),
                ),
                const SizedBox(height: 12),
                _assetActionButton(
                  icon: Icons.water_drop,
                  label: "Liquid",
                  onTap: () => _showActionSheet(context, "liquid"),
                ),
                const SizedBox(height: 12),
                _assetActionButton(
                  icon: Icons.currency_bitcoin,
                  label: "Bitcoin",
                  onTap: () => _showActionSheet(context, "bitcoin"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              "Payments",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),
            SizedBox(
              height: 400, // Or use MediaQuery to make it dynamic
              child: StreamBuilder<List<liquid_sdk.Payment>>(
                stream: breezSDKLiquid.paymentsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No payments recorded."));
                  }

                  final payments = snapshot.data!;

                  // for (final p in payments) {
                  //   debugPrint("🔍 Payment:");
                  //   debugPrint("  Status: ${p.status}");
                  //   debugPrint("  Type: ${p.paymentType}");
                  //   debugPrint("  Amount: ${p.amountSat}");
                  //   debugPrint("  Destination: ${p.destination}");
                  //   debugPrint("  Txid: ${p.txId}");
                  // }

                  return ListView.builder(
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final p = payments[index];
                      final isSent = p.amountSat.isNegative;

                      final statusColor = {
                            'complete': Colors.green,
                            'pending': Colors.orange,
                            'failed': Colors.red,
                          }[p.status.toString().split('.').last] ??
                          Colors.grey;

                      final formattedAmount =
                          "${(p.amountSat.abs() ~/ BigInt.from(1000))} sats";

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.container(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.background(context).opaque(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            // Side accent
                            Container(
                              width: 6,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isSent
                                    ? Colors.redAccent
                                    : AppColors.lightSecondary(context),
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                leading: Icon(
                                  Icons.bolt,
                                  size: 28,
                                  color: isSent
                                      ? Colors.redAccent
                                      : AppColors.icon(context),
                                ),
                                title: Text(
                                  isSent ? "Sent" : "Received",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text(context),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        "To: ${p.destination?.substring(0, 10)}...",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.text(context))),
                                    Text("Amount: $formattedAmount",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.text(context))),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(
                                    p.status.toString().split('.').last,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                  backgroundColor: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // const SizedBox(height: 16),
            // const Text("Logs",
            //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            // const SizedBox(height: 8),
            // Container(
            //   height: 100,
            //   width: double.infinity,
            //   padding: const EdgeInsets.all(8),
            //   decoration: BoxDecoration(
            //     color: AppColors.container(context),
            //     borderRadius: BorderRadius.circular(12),
            //   ),
            //   child: StreamBuilder<liquid_sdk.LogEntry>(
            //     stream: breezSDKLiquid.logStream,
            //     builder: (context, snapshot) {
            //       if (!snapshot.hasData) {
            //         return const Text("Waiting for logs...");
            //       }
            //       return SingleChildScrollView(
            //         child: Text(
            //           snapshot.data!.line,
            //           style: TextStyle(
            //             fontSize: 12,
            //             color: AppColors.text(context),
            //           ),
            //         ),
            //       );
            //     },
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget walletInfoCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.container(context),
            AppColors.container(context).opaque(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary(context).opaque(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.primary(context).opaque(0.4),
          width: 1.2,
        ),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _glowingIcon(context),
              const SizedBox(width: 10),
              Text(
                "Wallet Info",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Node ID
          StreamBuilder<liquid_sdk.GetInfoResponse>(
            stream: breezSDKLiquid.walletInfoStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final info = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Node ID",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent(context),
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.container(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accent(context).opaque(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SelectableText(
                            info.walletInfo.pubkey,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.text(context),
                              fontFamily: "monospace",
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.copy,
                            color: AppColors.cardTitle(context),
                            size: 18,
                          ),
                          tooltip: "Copy Node ID",
                          onPressed: () {
                            UtilitiesService.copyToClipboard(
                              context: context,
                              text: info.walletInfo.pubkey,
                              messageKey: 'node_ID_clipboard',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Divider(
            color: AppColors.accent(context).opaque(0.3),
            thickness: 1,
          ),
          const SizedBox(height: 5),

          // Balance section
          Text(
            "Balance",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.accent(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Available: $_balance sats\n"
            "Pending Send: $_pendingSend\n"
            "Pending Receive: $_pendingReceive",
            style: TextStyle(
              fontSize: 15,
              color: AppColors.text(context),
              height: 1.4,
            ),
            textAlign: TextAlign.left,
          )
        ],
      ),
    );
  }

  Widget _glowingIcon(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, glow, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent(context).opaque(glow),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.icon(context),
            size: 32,
          ),
        );
      },
    );
  }

  Widget _assetActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 22,
        color: AppColors.white(),
      ),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary(context),
        foregroundColor: AppColors.white(),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 3,
      ),
    );
  }

  void _showActionSheet(
    BuildContext context,
    String assetType,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: Text("Receive ${_capitalize(assetType)}"),
                onTap: () {
                  Navigator.pop(context);
                  _handleAssetAction(assetType, "receive");
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: Text("Send ${_capitalize(assetType)}"),
                onTap: () {
                  Navigator.pop(context);
                  _handleAssetAction(assetType, "send");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleAssetAction(String assetType, String direction) {
    if (assetType == "lightning") {
      if (direction == "receive") _createInvoice(context);
      if (direction == "send") _payInvoice(context);
    } else if (assetType == "liquid") {
      _liquidOperations(context, direction);
    } else if (assetType == "bitcoin") {
      _bitcoinOperations(context, direction);
    }
  }

  String _capitalize(String str) {
    if (str.isEmpty) {
      return str;
    }
    return str[0].toUpperCase() + str.substring(1);
  }
}
