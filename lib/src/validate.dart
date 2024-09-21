/* empathetech_ss_api
 * Copyright (c) 2022-2024 Empathetech LLC. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'package:email_validator/email_validator.dart';

const String inputRules =
    '''Display names, signal titles, and signal messages can be 3-20 characters long.

Letters, numbers, spaces, and the following special characters are allowed...

, : . ? ! _ ^ -
''';

/// r'^[\d\w\s-_!,?^]{3,20}$'
final RegExp validatorRegex = RegExp(r'^[\w\d\s,:.?!_^-]{3,20}$');

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
  return (toCheck != null && !validatorRegex.hasMatch(toCheck))
      ? 'Invalid title'
      : null;
}

/// Validate signal notification messages via [validatorRegex]
String? signalMessageValidator(String? toCheck) {
  return (toCheck != null && !validatorRegex.hasMatch(toCheck))
      ? 'Invalid message'
      : null;
}
