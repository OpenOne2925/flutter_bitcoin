enum PaymentType {
  receiveLightning,
  sendLightning,
  receiveBitcoin,
  receiveLiquid,
  sendBitcoin,
  sendLiquid,
}

extension PaymentTypeX on PaymentType {
  bool get isReceive => name.startsWith("receive");
  bool get isSend => !isReceive;

  bool get isBitcoin =>
      this == PaymentType.receiveBitcoin || this == PaymentType.sendBitcoin;
  bool get isLightning =>
      this == PaymentType.receiveLightning || this == PaymentType.sendLightning;
  bool get isLiquid =>
      this == PaymentType.receiveLiquid || this == PaymentType.sendLiquid;

  String get displayNetwork {
    if (isBitcoin) return "Bitcoin";
    if (isLightning) return "Lightning";
    if (isLiquid) return "Liquid";

    return "Payment";
  }

  String get displayAction => isReceive ? "Receive" : "Send";
}
