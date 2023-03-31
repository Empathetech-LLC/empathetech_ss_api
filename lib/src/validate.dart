library empathetech_ss_api;

import 'package:email_validator/email_validator.dart';

const String validatorRule = """For display names, signal titles, and signal messages...

- Length 3 -> 20
- Can contain word characters (upper or lowercase)
- Can contain digits
- Can contain -_!?^,
- Can contain whitespace""";

final RegExp validatorRegex = new RegExp(r'^[\d\w\s-_!,?^]{3,20}$');

/// Validate emails via [EmailValidator]
String? emailValidator(String? toCheck) {
  return (toCheck != null && !EmailValidator.validate(toCheck))
      ? 'Email does not exist'
      : null;
}

/// Validate display names via [validatorRegex]
String? displayNameValidator(String? toCheck) {
  return (toCheck != null && !validatorRegex.hasMatch(toCheck))
      ? 'Invalid display name'
      : null;
}

/// Validate URLs via [Uri.tryParse]
String? urlValidator(String? toCheck) {
  return (toCheck != null && !Uri.tryParse(toCheck)!.hasAbsolutePath)
      ? 'Invalid URL'
      : null;
}

/// Validate signal titles via [validatorRegex]
String? signalTitleValidator(String? toCheck) {
  return (toCheck != null && !validatorRegex.hasMatch(toCheck)) ? 'Invalid title' : null;
}

/// Validate signal notification messages via [validatorRegex]
String? signalMessageValidator(String? toCheck) {
  return (toCheck != null && !validatorRegex.hasMatch(toCheck))
      ? 'Invalid message'
      : null;
}
