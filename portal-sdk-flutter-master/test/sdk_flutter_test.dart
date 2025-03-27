import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdk_flutter/sdk_flutter.dart';
import 'package:sdk_flutter/sdk_flutter_platform_interface.dart';
import 'package:sdk_flutter/sdk_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSdkFlutterPlatform
    with MockPlatformInterfaceMixin
    implements SdkFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> ackSend() {
    // TODO: implement ackSend
    throw UnimplementedError();
  }

  @override
  Future<String> displayAddress(int index) {
    // TODO: implement displayAddress
    throw UnimplementedError();
  }

  @override
  Future<void> generateMnemonic(
      GenerateMnemonicWords num_words, String network, String? password) {
    // TODO: implement generateMnemonic
    throw UnimplementedError();
  }

  @override
  Future<CardStatus> getStatus() {
    // TODO: implement getStatus
    throw UnimplementedError();
  }

  @override
  Future<void> incomingData(int msgIndex, Uint8List data) {
    // TODO: implement incomingData
    throw UnimplementedError();
  }

  @override
  Future<void> initialize(bool useFastMessages) {
    // TODO: implement initialize
    throw UnimplementedError();
  }

  @override
  Future<void> newTag() {
    // TODO: implement newTag
    throw UnimplementedError();
  }

  @override
  Future<NfcOut> poll() {
    // TODO: implement poll
    throw UnimplementedError();
  }

  @override
  Future<Descriptors> publicDescriptors() {
    // TODO: implement publicDescriptors
    throw UnimplementedError();
  }

  @override
  Future<void> restoreMnemonic(
      String mnemonic, String network, String? password) {
    // TODO: implement restoreMnemonic
    throw UnimplementedError();
  }

  @override
  Future<String> signPsbt(String psbt) {
    // TODO: implement signPsbt
    throw UnimplementedError();
  }

  @override
  Future<void> unlock(String password) {
    // TODO: implement unlock
    throw UnimplementedError();
  }

  @override
  Future<void> updateFirmware(Uint8List binary) {
    // TODO: implement updateFirmware
    throw UnimplementedError();
  }
}

void main() {
  final SdkFlutterPlatform initialPlatform = SdkFlutterPlatform.instance;

  test('$MethodChannelSdkFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSdkFlutter>());
  });

  test('getPlatformVersion', () async {
    SdkFlutter sdkFlutterPlugin = SdkFlutter();
    MockSdkFlutterPlatform fakePlatform = MockSdkFlutterPlatform();
    SdkFlutterPlatform.instance = fakePlatform;

    expect(await sdkFlutterPlugin.getStatus(), '42');
  });
}
