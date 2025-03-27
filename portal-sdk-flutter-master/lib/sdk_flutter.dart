import 'sdk_flutter_platform_interface.dart';

import 'dart:typed_data';

export 'sdk_flutter_platform_interface.dart' show GenerateMnemonicWords;

class SdkFlutter {
  Future<void> initialize(bool useFastMessages) {
    return SdkFlutterPlatform.instance.initialize(useFastMessages);
  }
  Future<NfcOut> poll() {
    return SdkFlutterPlatform.instance.poll();
  }
  Future<void> ackSend() {
    return SdkFlutterPlatform.instance.ackSend();
  }
  Future<void> newTag() {
    return SdkFlutterPlatform.instance.newTag();
  }
  Future<void> incomingData(int msgIndex, Uint8List data) {
    return SdkFlutterPlatform.instance.incomingData(msgIndex, data);
  }
  Future<CardStatus> getStatus() {
    return SdkFlutterPlatform.instance.getStatus();
  }
  Future<void> generateMnemonic(GenerateMnemonicWords num_words, String network, String? password) {
    return SdkFlutterPlatform.instance.generateMnemonic(num_words, network, password);
  }
  Future<void> restoreMnemonic(String mnemonic, String network, String? password) {
    return SdkFlutterPlatform.instance.restoreMnemonic(mnemonic, network, password);
  }
  Future<void> unlock(String password) {
    return SdkFlutterPlatform.instance.unlock(password);
  }
  Future<String> displayAddress(int index) {
    return SdkFlutterPlatform.instance.displayAddress(index);
  }
  Future<String> signPsbt(String psbt) {
    return SdkFlutterPlatform.instance.signPsbt(psbt);
  }
  Future<Descriptors> publicDescriptors() {
    return SdkFlutterPlatform.instance.publicDescriptors();
  }
  Future<void> updateFirmware(Uint8List binary) {
    return SdkFlutterPlatform.instance.updateFirmware(binary);
  }
}
