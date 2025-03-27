import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dart:typed_data';
import 'dart:convert';

import 'sdk_flutter_method_channel.dart';

class NfcOut {
  final int msgIndex;
  final Uint8List data;

  NfcOut({required this.msgIndex, required this.data});

  factory NfcOut.fromJson(Map<String, dynamic> json) {
    List<int> data = json['data'].cast<int>();
    Uint8List uint8List = Uint8List.fromList(data);

    return NfcOut(
      msgIndex: json['msgIndex'],
      data: uint8List,
    );
  }
}

class CardStatus {
  final bool initialized;
  final bool unlocked;
  final String? network;

  CardStatus({required this.initialized, required this.unlocked, required this.network});

  factory CardStatus.fromJson(Map<String, dynamic> json) {
    return CardStatus(
      initialized: json['initialized'],
      unlocked: json['unlocked'],
      network: json['network'],
    );
  }
}

enum GenerateMnemonicWords {
  Words12,
  Words24,
}

class Descriptors {
  final String external_descriptor;
  final String? internal_descriptor;

  Descriptors({required this.external_descriptor, required this.internal_descriptor});

  factory Descriptors.fromJson(Map<String, dynamic> json) {
    return Descriptors(
      external_descriptor: json['external'],
      internal_descriptor: json['internal'],
    );
  }
}

abstract class SdkFlutterPlatform extends PlatformInterface {
  /// Constructs a SdkFlutterPlatform.
  SdkFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static SdkFlutterPlatform _instance = MethodChannelSdkFlutter();

  /// The default instance of [SdkFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelSdkFlutter].
  static SdkFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SdkFlutterPlatform] when
  /// they register themselves.
  static set instance(SdkFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(bool useFastMessages) {
    throw UnimplementedError('initialize() has not been implemented.');
  }
  Future<NfcOut> poll() {
    throw UnimplementedError('poll() has not been implemented.');
  }
  Future<void> ackSend() {
    throw UnimplementedError('ackSend() has not been implemented.');
  }
  Future<void> newTag() {
    throw UnimplementedError('newTag() has not been implemented.');
  }
  Future<void> incomingData(int msgIndex, Uint8List data) {
    throw UnimplementedError('incomingData() has not been implemented.');
  }
  Future<CardStatus> getStatus() {
    throw UnimplementedError('getStatus() has not been implemented.');
  }
  Future<void> generateMnemonic(GenerateMnemonicWords num_words, String network, String? password) {
    throw UnimplementedError('generateMnemonic() has not been implemented.');
  }
  Future<void> restoreMnemonic(String mnemonic, String network, String? password) {
    throw UnimplementedError('restoreMnemonic() has not been implemented.');
  }
  Future<void> unlock(String password) {
    throw UnimplementedError('unlock() has not been implemented.');
  }
  Future<String> displayAddress(int index) {
    throw UnimplementedError('displayAddress() has not been implemented.');
  }
  Future<String> signPsbt(String psbt) {
    throw UnimplementedError('signPsbt() has not been implemented.');
  }
  Future<Descriptors> publicDescriptors() {
    throw UnimplementedError('publicDescriptors() has not been implemented.');
  }
  Future<void> updateFirmware(Uint8List binary) {
    throw UnimplementedError('updateFirmware() has not been implemented.');
  }
}
