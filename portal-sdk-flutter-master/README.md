# sdk_flutter

This repo contains the Flutter bindings for the Portal Rust SDK.

The goal of the SDK is to make it very easy to interact with the device, by abstracting away all the complex logic and just exposing a simple API.

## Getting Started

Using this library requires essentially four steps:

1. Add NFC permissions to your app's manifest
2. Call `initialize()` once at the beginning of your app. The boolean argument switches between "fast" and "slow" messages. All the smartphones should
   support the "fast" messages, but if you experience unreliable communication you could try switching to the "slow" ones.
3. Setup the NFC communication loop, similarly to `./example/lib/main.dart#L30-L59`. Whenever a new NfcA tag is found you need to:
  - Let the library know there's a new device, by calling the `newTag()` method.
  - Start a loop calling `poll()` at each iteration, which will return the message to send to the device.
  - If you were able to send the message, acknowledge it by calling `ackSend()`.
  - Then give the library the response you got from the NFC device with `incomingData()`.
4. Within your app call any of the methods exposed by the sdk, like `getStatus()`, `signPsbt()`, etc.

## Limitations

Right now the library only supports Android. iOS support will follow soon!
