import 'dart:js_interop';

@JS('byeoljariPasskeys.available')
external bool passkeysAvailable();
@JS('byeoljariPasskeys.ceremony')
external JSPromise<JSString> _ceremony(bool registering, String options);

Future<String> passkeyCeremony(bool registering, String options) async =>
    (await _ceremony(registering, options).toDart).toDart;
