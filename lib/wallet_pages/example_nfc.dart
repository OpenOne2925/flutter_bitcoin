import 'package:flutter/material.dart';

import 'package:sdk_flutter/sdk_flutter.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class ExampleNfc extends StatefulWidget {
  const ExampleNfc({super.key});

  @override
  State<ExampleNfc> createState() => ExampleNfcState();
}

class ExampleNfcState extends State<ExampleNfc> {
  String _status = '';
  final _sdkFlutterPlugin = SdkFlutter();

  @override
  void initState() {
    super.initState();

    _sdkFlutterPlugin.initialize(true);

    NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        NfcA? nfca = NfcA.from(tag);

        if (nfca == null) {
          print('Tag is not compatible');
          await NfcManager.instance.stopSession().catchError((_) {/* no op */});
          return;
        }

        _sdkFlutterPlugin.newTag();

        while (true) {
          try {
            final nfcOut = await _sdkFlutterPlugin.poll();
            print('NfcData: ${nfcOut.data}');
            final reply = await nfca.transceive(data: nfcOut.data);
            print('Reply: $reply');
            await _sdkFlutterPlugin.ackSend();
            await _sdkFlutterPlugin.incomingData(nfcOut.msgIndex, reply);
          } catch (e) {
            await NfcManager.instance
                .stopSession()
                .catchError((_) {/* no op */});
            setState(() => _status = 'Error: $e');

            break;
          }
        }
      },
    ).catchError((e) => setState(() => _status = 'Error: $e'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Portal SDK Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Status: $_status',
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  final status = await _sdkFlutterPlugin.getStatus();
                  print('Status: $status');

                  setState(() => _status =
                      'initialized: ${status.initialized}, unlocked: ${status.unlocked}, network: ${status.network}');
                },
                child: Text('Request Status'),
              ),
              TextButton(
                onPressed: () async {
                  final signed = await _sdkFlutterPlugin.signPsbt(
                      "cHNidP8BAFIBAAAAAXbN96PvQ+ZKYV1cNaA3PTHmC5zWxCRAT1fW3azUJFWNAAAAAAD+////AaImAAAAAAAAFgAUnzVKEjdFtB9zsPlcaCEkNeD3fc7XZQIAAAEA3gIAAAAAAQGYEApmWClxrcZ1EfyjwlkNFrOkT8C/JXmVWapWmfLHEgAAAAAA/v///wIQJwAAAAAAABYAFJ81ShI3RbQfc7D5XGghJDXg933O/2EBEAAAAAAWABQupnNAECI8+4OvBCWLSvmtrIpSnAJHMEQCIAkWSIX+oJaN0REAHYPLnsL/3+ZIiknDckFBy0SPk0eRAiAf2z4GKnUPl6Epzu/L4Pf0sMnyP8JkrYhVDe7p1bEcLAEhA9rahMDNzfz0/e8z6E5me26cOpqBkJdi6/zJ+9YYIADT12UCAAEBHxAnAAAAAAAAFgAUnzVKEjdFtB9zsPlcaCEkNeD3fc4iBgJAd1xnM2tcqPZ6y3uXqhzmedJIlmbszYBssTh9KchsqhgLtbvoVAAAgAEAAIAAAACAAAAAACoAAAAAIgICQHdcZzNrXKj2est7l6oc5nnSSJZm7M2AbLE4fSnIbKoYC7W76FQAAIABAACAAAAAgAAAAAAqAAAAAA==");
                  setState(() => _status = signed);
                },
                child: Text('Sign PSBT'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final addr = await _sdkFlutterPlugin.displayAddress(42);
                    print('Address: $addr');

                    setState(() => _status = addr);
                  } catch (e, stackTrace) {
                    print('Error: $e');
                    print('StackTrace: $stackTrace');
                  }
                },
                child: Text('Request Address #42'),
              ),
              TextButton(
                onPressed: () async {
                  final desc = await _sdkFlutterPlugin.publicDescriptors();
                  setState(() => _status =
                      'ext: ${desc.external_descriptor}, int: ${desc.internal_descriptor}');
                },
                child: Text('Request Descriptors'),
              ),
              TextButton(
                onPressed: () async {
                  await _sdkFlutterPlugin.generateMnemonic(
                      GenerateMnemonicWords.Words12, "testnet", null);
                  setState(() => _status = 'done!');
                },
                child: Text('Generate Mnemonic'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
