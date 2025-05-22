import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_ui_helpers.dart';
import 'package:flutter_wallet/wallet_pages/qr_scanner_page.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:ldk_node/ldk_node.dart' as ldk;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LightningPage extends StatefulWidget {
  final String mnemonic;

  const LightningPage({super.key, required this.mnemonic});

  @override
  State<LightningPage> createState() => _LightningPageState();
}

class _LightningPageState extends State<LightningPage> {
  ldk.Node? ldkNode;
  List<ldk.ChannelDetails> channels = [];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  final _sendKey = GlobalKey<FormState>();

  int onChainBalance = 0;
  int lightningBalance = 0;

  String nodeId = "";
  String address = "";
  int port = 0;
  int amount = 0;
  int counterPartyAmount = 0;
  String invoice = "";
  String listeningAddress = "";
  String fundingAddress = "";

  bool showInSatoshis = true; // Toggle display state
  bool isInitialized = false;

  ldk.PublicKey? ldkNodeId;

  double ledCurrencyBalance = 0.0;
  double avCurrencyBalance = 0.0;

  final int _currentHeight = 0;
  final String _timeStamp = "";

  late WalletService walletService;
  late SettingsProvider settingsProvider;

  @override
  void initState() {
    super.initState();
    settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    walletService = WalletService(settingsProvider);
    initNode();
  }

  @override
  void dispose() {
    ldkNode?.stop();
    super.dispose();
  }

  String extractInvoice(String data) => data;

  Future<String> _storagePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return "${directory.path}/LDK_NODE";
  }

  Future<void> initNode() async {
    final builder = ldk.Builder.testnet()
        .setEntropyBip39Mnemonic(
          mnemonic: ldk.Mnemonic(seedPhrase: widget.mnemonic),
        )
        .setStorageDirPath(await _storagePath());

    ldkNode = await builder.build();
    await ldkNode!.start();

    await sync();

    setState(() {
      isInitialized = true;
    });
  }

  Future<void> sync() async {
    await ldkNode!.syncWallets();
    final res = await ldkNode!.listChannels();

    print("====== Channels Summary (${res.length}) ======");
    for (var e in res) {
      print("🔗 Channel ID: ${e.channelId}");
      print("↔️  Outbound: ${e.isOutbound}");
      print("👤 Counterparty: ${e.counterpartyNodeId.hex}");
      print("💰 Channel Value: ${e.channelValueSats} sats");
      print(
        "🔒 Confirmations: ${e.confirmations}/${e.confirmationsRequired}",
      );
      print("✅ Ready: ${e.isChannelReady}");
      print("⚡ Usable: ${e.isUsable}");
      print("📤 Outbound Capacity: ${e.outboundCapacityMsat} msat");
      print("📥 Inbound Capacity: ${e.inboundCapacityMsat} msat");
      print("📉 Feerate: ${e.feerateSatPer1000Weight} sat/kwu");
      print("🕓 CLTV Delta: ${e.cltvExpiryDelta}");
      print("📡 Public: ${e.isPublic}");
      print("🔐 Reserve (Local): ${e.unspendablePunishmentReserve}");
      print(
          "🔐 Reserve (Remote): ${e.counterpartyUnspendablePunishmentReserve}");
      print("🕓 Force Close Delay: ${e.forceCloseSpendDelay}");
      print("📈 HTLC Out Limit: ${e.nextOutboundHtlcLimitMsat}");
      print("📉 HTLC In Min: ${e.inboundHtlcMinimumMsat}");
      print("-------------------------------------------");
    }

    await updateBalances();
    await getListeningAddress();
    await newFundingAddress();

    final nodeId = await ldkNode!.nodeId();

    setState(() {
      ldkNodeId = nodeId;
      channels = res;
    });
  }

  getListeningAddress() async {
    final hostAndPort = await ldkNode!.listeningAddresses();
    final addr = hostAndPort![0];

    setState(() {
      addr.maybeMap(
        orElse: () {},
        hostname: (e) {
          listeningAddress = "${e.addr}:${e.port}";
        },
      );
    });
  }

  newFundingAddress() async {
    final onChainPayment = await ldkNode!.onChainPayment();
    final onChainAddress = await onChainPayment.newAddress();

    print("ldkNode's address: ${onChainAddress.s}");

    setState(() {
      fundingAddress = onChainAddress.s;
    });
  }

  Future<void> updateBalances() async {
    final balances = await ldkNode!.listBalances();

    setState(() {
      onChainBalance = balances.totalOnchainBalanceSats.toInt();
      lightningBalance = balances.totalLightningBalanceSats.toInt() ~/ 1000;
    });
  }

  Future<void> connectOpenChannel(String host, int port, String nodeId,
      int amount, int pushToCounterpartyMsat) async {
    await ldkNode!.connectOpenChannel(
      channelAmountSats: BigInt.from(amount),
      announceChannel: true,
      pushToCounterpartyMsat: BigInt.from(pushToCounterpartyMsat * 1000),
      socketAddress: ldk.SocketAddress.hostname(addr: host, port: port),
      nodeId: ldk.PublicKey(hex: nodeId),
    );
    await sync();
  }

  Future<void> closeChannel(
      ldk.UserChannelId channelId, ldk.PublicKey nodeId) async {
    await ldkNode!.closeChannel(
      userChannelId: channelId,
      counterpartyNodeId: nodeId,
    );
    await sync();
  }

  Future<String> receiveBolt11Payment({
    int? amount,
    String? description = 'test',
    int? expirySecs = 3600,
  }) async {
    final bolt11Payment = await ldkNode!.bolt11Payment();
    final invoice = amount == null
        ? await bolt11Payment.receiveVariableAmount(
            description: description!,
            expirySecs: expirySecs!,
          )
        : await bolt11Payment.receive(
            amountMsat: BigInt.from(satsToMsats(amount)),
            description: description!,
            expirySecs: expirySecs!,
          );
    return invoice.signedRawInvoice.toString();
  }

  Future<String> sendPayment(String invoice) async {
    final channels = await ldkNode!.listChannels();
    final usableChannels = channels.where(
        (c) => c.isUsable && c.outboundCapacityMsat > BigInt.from(50 * 1000));
    if (usableChannels.isEmpty) return "No route";
    final paymentId = await ldkNode!.bolt11Payment().then((p) => p.send(
          invoice: ldk.Bolt11Invoice(signedRawInvoice: invoice),
        ));
    final res = await ldkNode!.payment(paymentId: paymentId);
    return res?.status.toString() ?? "Unknown";
  }

  void _channelPopup(BuildContext context) {
    popUpWidget(
      context: context,
      title: 'Open Channel',
      widget: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Node Id'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter nodeId';
                  nodeId = value.trim();
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'IP Address'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter IP';
                      address = value.trim();
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Port'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter port';
                      port = int.tryParse(value.trim()) ?? 0;
                      return null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Amount (sats)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter amount';
                  amount = int.tryParse(value.trim()) ?? 0;
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Push to Counterparty (sats)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter push amt';
                  counterPartyAmount = int.tryParse(value.trim()) ?? 0;
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await connectOpenChannel(
                      address,
                      port,
                      nodeId,
                      amount,
                      counterPartyAmount,
                    );

                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },
                child: const Text('Submit'),
              )
            ],
          ),
        ),
      ),
    );
  }

  void popUpWidget({
    required String title,
    required Widget widget,
    required BuildContext context,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: widget,
      ),
    );
  }

  void buttonPopup(BuildContext context, int action, int index) {
    final channel = channels[index];
    if (action == 0) {
      popUpWidget(
        context: context,
        title: "Receive",
        widget: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Amount in sats'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter amount';
                  amount = int.parse(value);
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final invoice = await receiveBolt11Payment(amount: amount);
                    if (!context.mounted) return;

                    Navigator.of(context, rootNavigator: true).pop();

                    // Show second popup with QR + invoice + copy
                    popUpWidget(
                      context: context,
                      title: "Invoice",
                      widget: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: SizedBox(
                                width: 200,
                                height: 200,
                                child: QrImageView(
                                  data: invoice,
                                  version: QrVersions.auto,
                                ),
                              ),
                            ),
                            SelectableText(
                              invoice,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.copy),
                              label: const Text("Copy"),
                              onPressed: () {
                                UtilitiesService.copyToClipboard(
                                  context: context,
                                  text: invoice,
                                  messageKey: 'invoice_clipboard',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Receive'),
              ),
            ],
          ),
        ),
      );
    } else if (action == 1) {
      popUpWidget(
        context: context,
        title: "Send",
        widget: Form(
          key: _sendKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Invoice'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter invoice';
                  invoice = value.trim();
                  return null;
                },
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (_sendKey.currentState!.validate()) {
                        final status = await sendPayment(invoice);
                        if (context.mounted) Navigator.of(context).pop();
                        popUpWidget(
                          context: context,
                          title: "Send Status",
                          widget: SelectableText('Status: $status'),
                        );
                      }
                    },
                    child: const Text('Send'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QRScannerPage(
                            title: 'Scan Lightning Invoice',
                            isValid: isValidBolt11,
                            extractValue: extractInvoice,
                          ),
                        ),
                      ).then((invoice) async {
                        if (invoice != null) {
                          await sendPayment(invoice);
                        }
                      });
                    },
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text("Scan to Pay"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (action == 2) {
      closeChannel(channel.userChannelId, channel.counterpartyNodeId);
    }
  }

  void _convertCurrency() async {
    final currencyLedUsd = await walletService.convertSatoshisToCurrency(
        onChainBalance, settingsProvider.currency);
    final currencyAvUsd = await walletService.convertSatoshisToCurrency(
        lightningBalance, settingsProvider.currency);

    setState(() {
      ledCurrencyBalance = currencyLedUsd;
      avCurrencyBalance = currencyAvUsd;
      showInSatoshis = !showInSatoshis;
    });
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<BaseScaffoldState> baseScaffoldKey =
        GlobalKey<BaseScaffoldState>();

    final walletUiHelpers = WalletUiHelpers(
      address: fundingAddress,
      avBalance: lightningBalance,
      ledBalance: onChainBalance,
      showInSatoshis: showInSatoshis,
      avCurrencyBalance: avCurrencyBalance,
      ledCurrencyBalance: ledCurrencyBalance,
      currentHeight: _currentHeight,
      timeStamp: _timeStamp,
      isInitialized: isInitialized,
      settingsProvider: settingsProvider,
      context: context,
      isSingleWallet: true,
      isLightningWallet: true,
      isLoading: false,
      transactions: [],
      isRefreshing: false,
      baseScaffoldKey: baseScaffoldKey,
      mnemonic: widget.mnemonic,
      listeningAddress: listeningAddress,
      ldkNodeId: ldkNodeId,
    );

    return BaseScaffold(
      title: const Text('Lightning Wallet'),
      body: Stack(
        children: [
          RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: () => sync(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                walletUiHelpers.buildWalletInfoBox(
                  'data',
                  onTap: () {
                    _convertCurrency();
                  },
                  showCopyButton: true,
                ),
                if (channels.isEmpty)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.link_off,
                        size: 64,
                        color: AppColors.unavailableColor
                            .withAlpha((0.5 * 255).toInt()),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Open Channels Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the "+" button below to open one!',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black(),
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 600.ms).slideY(begin: 0.2)
                else
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8.0), // Rounded corners
                    ),
                    elevation: 4, // Subtle shadow for depth
                    color:
                        AppColors.gradient(context), // Match button background
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final ch = channels[index];
                        final isReady = ch.isUsable && ch.isChannelReady;
                        return ListTile(
                          tileColor: AppColors.gradient(context),
                          title: Text(
                              "Channel capacity: ${ch.channelValueSats} sats"),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  "Confirmations: ${ch.confirmations}/${ch.confirmationsRequired}"),
                              Text(
                                  "Outbound: ${mSatsToSats(ch.outboundCapacityMsat.toInt())}"),
                              Text(
                                  "Inbound: ${mSatsToSats(ch.inboundCapacityMsat.toInt())}"),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: isReady
                                        ? () => buttonPopup(context, 1, index)
                                        : null,
                                    child: const Text("Send"),
                                  ),
                                  const SizedBox(width: 5),
                                  ElevatedButton(
                                    onPressed: isReady
                                        ? () => buttonPopup(context, 0, index)
                                        : null,
                                    child: const Text("Receive"),
                                  ),
                                  const SizedBox(width: 5),
                                  ElevatedButton(
                                    onPressed: isReady
                                        ? () => buttonPopup(context, 2, index)
                                        : null,
                                    child: const Text("Close"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: CustomButton(
                onPressed: () => _channelPopup(context),
                backgroundColor: AppColors.background(context),
                foregroundColor: AppColors.text(context),
                icon: Icons.add,
                iconColor: AppColors.gradient(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int satsToMsats(int sats) => sats * 1000;
  String mSatsToSats(int mSats) => '${mSats ~/ 1000}sats';
}
