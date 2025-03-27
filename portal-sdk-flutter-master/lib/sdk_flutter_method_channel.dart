import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dart:typed_data';
import 'dart:convert';

import 'sdk_flutter_platform_interface.dart';

/// An implementation of [SdkFlutterPlatform] that uses method channels.
class MethodChannelSdkFlutter extends SdkFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('sdk_flutter');

  @override
  Future<void> initialize(bool useFastMessages) async {
    await methodChannel.invokeMethod('initialize', {'useFastMessages': useFastMessages});
  }
  @override
  Future<NfcOut> poll() async {
    final data = await methodChannel.invokeMethod<String>('poll');
    Map<String, dynamic> jsonMap = jsonDecode(data!);

    return NfcOut.fromJson(jsonMap);
  }
  @override
  Future<void> ackSend() async {
    await methodChannel.invokeMethod('ack_send');
  }
  @override
  Future<void> newTag() async {
    await methodChannel.invokeMethod('new_tag');
  }
  @override
  Future<void> incomingData(int msgIndex, Uint8List data) async {
    await methodChannel.invokeMethod('incoming_data', {'msgIndex': msgIndex, 'data': data});
  }
  @override
  Future<CardStatus> getStatus() async {
    final data = await methodChannel.invokeMethod<String>('get_status');
    Map<String, dynamic> jsonMap = jsonDecode(data!);

    return CardStatus.fromJson(jsonMap);
  }
  @override
  Future<void> generateMnemonic(GenerateMnemonicWords num_words, String network, String? password) async {
    print(num_words.toString());
    await methodChannel.invokeMethod('generate_mnemonic', {'numWords': num_words.toString(), 'network': network, 'password': password});
  }
  @override
  Future<void> restoreMnemonic(String mnemonic, String network, String? password) async {
    await methodChannel.invokeMethod('restore_mnemonic', {'mnemonic': mnemonic, 'network': network, 'password': password});
  }
  @override
  Future<void> unlock(String password) async {
    await methodChannel.invokeMethod('unlock', {'password': password});
  }
  @override
  Future<String> displayAddress(int index) async {
    final data = await methodChannel.invokeMethod<String>('display_address', {'index': index});
    return data!;
  }
  @override
  Future<String> signPsbt(String psbt) async {
    final data = await methodChannel.invokeMethod<String>('sign_psbt', {'psbt': psbt});
    return data!;
  }
  @override
  Future<Descriptors> publicDescriptors() async {
    final data = await methodChannel.invokeMethod<String>('public_descriptors');
    Map<String, dynamic> jsonMap = jsonDecode(data!);

    return Descriptors.fromJson(jsonMap);
  }
  @override
  Future<void> updateFirmware(Uint8List binary) async {
    await methodChannel.invokeMethod<String>('update_firmware', {'binary': binary});
  }
}
