library empathetech_ss_api;

import 'package:empathetech_ss_api/empathetech_ss_api.dart';
import 'package:empathetech_flutter_ui/empathetech_flutter_ui.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Wrapper for housing all Firebase instances
class AppUser {
  static late FirebaseMessaging messager;
  static late FirebaseAuth auth;
  static late User account;
  static late FirebaseFirestore db;
}

/// Attempt creating a new firebase user account
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> attemptAccountCreation(
    BuildContext context, String email, String password) async {
  try {
    await AppUser.auth.createUserWithEmailAndPassword(email: email, password: password);

    // Successful login, return to the home screen
    popScreen(context, pass: true);
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'email-already-in-use':
        logAlert(context, 'Email already in use');
        break;

      case 'weak-password':
        logAlert(context, 'The provided password is too weak');
        break;

      default:
        String message = 'Firebase error on user creation\n' + e.code;
        logAlert(context, message);
        break;
    }
  } catch (e) {
    String message = 'Error creating user\n' + e.toString();
    logAlert(context, message);
  }
}

/// Attempt logging in firebase user with passed credentials
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> attemptLogin(BuildContext context, String email, String password) async {
  try {
    await AppUser.auth.signInWithEmailAndPassword(email: email, password: password);

    // Successful login, return to the home screen
    popScreen(context, pass: true);
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'user-not-found':
        logAlert(context, 'No user found for that email!');
        break;

      case 'wrong-password':
        logAlert(context, 'Incorrect password');
        break;

      default:
        String message = 'Error logging in\n' + e.code;
        logAlert(context, message);
        break;
    }
  }
}

/// Logout current user
void logout(BuildContext context) {
  ezDialog(
    context,
    title: 'Logout?',
    content: [
      ezYesNo(
        context,
        onConfirm: () async {
          popUntilHome(context);
          await AppUser.auth.signOut();
        },
        onDeny: () => popScreen(context),
        axis: Axis.vertical,
        spacer: AppConfig.prefs[dialogSpacingKey],
      ),
    ],
    needsClose: false,
  );
}

/// Return the FCM token of the user with the passed ID
/// This can cost money! [https://firebase.google.com/pricing/]
Future<String> getToken(String id) async {
  try {
    DocumentSnapshot userSnap = await AppUser.db.collection(usersPath).doc(id).get();

    final Map<String, dynamic> data = userSnap.data() as Map<String, dynamic>;

    return data[fcmTokenPath];
  } catch (e) {
    return '';
  }
}

/// Get the FCM tokens for all the passed user ids
/// This can cost money! [https://firebase.google.com/pricing/]
Future<List<String>> gatherTokens(List<String> ids) async {
  List<Future<String>> tokenReqs = ids.map((id) async => await getToken(id)).toList();
  List<String> tokens = await Future.wait(tokenReqs);

  tokens.removeWhere((token) => token == '');

  return tokens;
}

/// Merge the current users FCM token with firestore
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> setToken(User currUser) async {
  String userToken = await AppUser.messager.getToken() ?? '';

  // The doc may not exist yet, so use set w/ merge
  await FirebaseFirestore.instance.collection(usersPath).doc(currUser.uid).set(
    {fcmTokenPath: userToken},
    SetOptions(merge: true),
  );
}

/// Stream user docs from db, optionally filtering by the list of ids we know we want
/// This can cost money! [https://firebase.google.com/pricing/]
Stream<QuerySnapshot<Map<String, dynamic>>> streamUsers([List<String>? ids]) {
  try {
    if (ids == null) {
      return AppUser.db.collection(usersPath).snapshots();
    } else {
      return AppUser.db
          .collection(usersPath)
          .where(FieldPath.documentId, whereIn: ids)
          .snapshots();
    }
  } catch (e) {
    return Stream.empty();
  }
}

/// Gets the users avatar url
/// This can cost money! [https://firebase.google.com/pricing/]
Future<String> getAvatar() async {
  DocumentSnapshot userSnap =
      await AppUser.db.collection(usersPath).doc(AppUser.account.uid).get();

  final Map<String, dynamic> data = userSnap.data() as Map<String, dynamic>;

  return data[avatarURLPath] ?? defaultAvatarURL;
}

/// Update the users avatar
/// This can cost money! [https://firebase.google.com/pricing/]
/// Returns the new URL on success
Future<dynamic> editAvatar(BuildContext context) async {
  final urlFormKey = GlobalKey<FormState>();
  TextEditingController _urlController = TextEditingController();

  double dialogSpacer = AppConfig.prefs[dialogSpacingKey];

  return ezDialog(
    context,
    content: [
      // URL text field/form
      ezForm(
        key: urlFormKey,
        controller: _urlController,
        hintText: 'Enter URL',
        validator: urlValidator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
      Container(height: dialogSpacer),

      // Explanation for not using image files
      Text(
        'Images are expensive to store!\nPaste an image link and that will be used',
        maxLines: 2,
        style: getTextStyle(dialogContentStyleKey),
        textAlign: TextAlign.center,
      ),
      Container(height: dialogSpacer),

      // Submit & cancel buttons
      ezYesNo(
        context,
        onConfirm: () async {
          // Close keyboard if open
          AppConfig.focus.primaryFocus?.unfocus();

          // Don't do anything if the url is invalid
          if (!urlFormKey.currentState!.validate()) {
            logAlert(context, 'Invalid URL!');
            return;
          }

          // Update firestore and the firebase user config
          String photoURL = _urlController.text.trim();

          try {
            await AppUser.account.updatePhotoURL(photoURL);
            await AppUser.db.collection(usersPath).doc(AppUser.account.uid).update(
              {avatarURLPath: photoURL},
            );

            popScreen(context, pass: photoURL);
          } catch (e) {
            logAlert(context, e.toString());
          }
        },
        onDeny: () => popScreen(context),
        axis: Axis.vertical,
        spacer: dialogSpacer,
        confirmMsg: 'Submit',
        denyMsg: 'Cancel',
      ),
    ],
    needsClose: false,
  );
}

/// Gets the users display name
/// This can cost money! [https://firebase.google.com/pricing/]
Future<String> getName() async {
  DocumentSnapshot userSnap =
      await AppUser.db.collection(usersPath).doc(AppUser.account.uid).get();

  final Map<String, dynamic> data = userSnap.data() as Map<String, dynamic>;

  return data[displayNamePath] ?? defaultDisplayName;
}

/// Update the users display name
/// This can cost money! [https://firebase.google.com/pricing/]
/// Returns the new name on success
Future<dynamic> editName(BuildContext context) async {
  final nameFormKey = GlobalKey<FormState>();
  TextEditingController _nameController = TextEditingController();

  double dialogSpacer = AppConfig.prefs[dialogSpacingKey];

  return ezDialog(
    context,
    title: 'Who are you?',
    content: [
      // Name field
      ezForm(
        key: nameFormKey,
        controller: _nameController,
        hintText: 'Enter display name',
        validator: displayNameValidator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
      Container(height: dialogSpacer),

      // Submit & cancel buttons
      ezYesNo(
        context,
        onConfirm: () async {
          // Close keyboard if open
          AppConfig.focus.primaryFocus?.unfocus();

          // Don't do anything if the display name is invalid
          if (!nameFormKey.currentState!.validate()) {
            logAlert(context, 'Invalid display name!');
            return;
          }

          // Update firestore and the firebase user config
          String newName = _nameController.text.trim();

          try {
            await AppUser.account.updateDisplayName(newName);
            await AppUser.db.collection(usersPath).doc(AppUser.account.uid).update(
              {displayNamePath: newName},
            );

            popScreen(context, pass: newName);
          } catch (e) {
            logAlert(context, e.toString());
          }
        },
        onDeny: () => popScreen(context),
        axis: Axis.vertical,
        spacer: dialogSpacer,
        confirmMsg: 'Submit',
        denyMsg: 'Cancel',
      ),
    ],
    needsClose: false,
  );
}
