/* empathetech_ss_api
 * Copyright (c) 2022-2024 Empathetech LLC. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:empathetech_ss_api/empathetech_ss_api.dart';
import 'package:empathetech_flutter_ui/empathetech_flutter_ui.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// Wrapper for housing all Firebase instances
class AppUser {
  static late FirebaseAuth auth;
  static late User account;
  static late FirebaseFirestore db;
}

/// Attempt creating a new firebase user account
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> attemptAccountCreation(
    BuildContext context, String email, String password) async {
  try {
    await AppUser.auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Successful login, return to the home screen
    if (context.mounted) Navigator.of(context).pop(true);
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'email-already-in-use':
        if (context.mounted) logAlert(context, message: 'Email already in use');
        break;

      case 'weak-password':
        if (context.mounted) {
          logAlert(
            context,
            message: 'The provided password is too weak',
          );
        }
        break;

      default:
        final String message = 'Firebase error on user creation\n${e.code}';
        logAlert(context, message: message);
        break;
    }
  } catch (e) {
    final String message = 'Error creating user\n${e.toString()}';
    if (context.mounted) logAlert(context, message: message);
  }
}

/// Attempt logging in firebase user with passed credentials
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> attemptLogin(
    BuildContext context, String email, String password) async {
  try {
    await AppUser.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Successful login, return to the home screen
    if (context.mounted) Navigator.of(context).pop(true);
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'user-not-found':
        if (context.mounted) {
          logAlert(context, message: 'No user found for that email!');
        }
        break;

      case 'wrong-password':
        if (context.mounted) logAlert(context, message: 'Incorrect password');

        break;

      default:
        final String message = 'Error logging in\n${e.code}';
        logAlert(context, message: message);
        break;
    }
  }
}

/// Logout current user
Future<dynamic> logout(BuildContext context) {
  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      void onConfirm() async {
        Navigator.of(dialogContext).popUntil((Route<dynamic> route) {
          return route.settings.name == homePath;
        });

        await AppUser.auth.signOut();
      }

      void onDeny() => Navigator.of(dialogContext).pop();

      return EzAlertDialog(
        content: const Text('Logout?', textAlign: TextAlign.center),
        materialActions: ezMaterialActions(
          context: context,
          onConfirm: onConfirm,
          onDeny: onDeny,
        ),
        cupertinoActions: ezCupertinoActions(
          context: context,
          onConfirm: onConfirm,
          confirmIsDestructive: true,
          onDeny: onDeny,
        ),
        needsClose: false,
      );
    },
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
    return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  }
}

/// Gets the users avatar url
/// This can cost money! [https://firebase.google.com/pricing/]
Future<String> getAvatar() async {
  final DocumentSnapshot<Map<String, dynamic>> userSnap =
      await AppUser.db.collection(usersPath).doc(AppUser.account.uid).get();

  final Map<String, dynamic> data = userSnap.data() as Map<String, dynamic>;

  return data[avatarURLPath] ?? defaultAvatarURL;
}

/// Update the users avatar
/// This can cost money! [https://firebase.google.com/pricing/]
/// Returns the new URL on success
Future<dynamic> editAvatar(BuildContext context) {
  final GlobalKey<FormState> urlFormKey = GlobalKey<FormState>();
  final TextEditingController urlController = TextEditingController();

  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      void onConfirm() async {
        closeKeyboard(dialogContext);

        // Don't do anything if the url is invalid
        if (!urlFormKey.currentState!.validate()) {
          logAlert(context, message: 'Invalid URL!');
          return;
        }

        // Update firestore and the firebase user config
        final String photoURL = urlController.text.trim();

        try {
          await AppUser.account.updatePhotoURL(photoURL);
          await AppUser.db
              .collection(usersPath)
              .doc(AppUser.account.uid)
              .update(
            <String, dynamic>{avatarURLPath: photoURL},
          );

          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop(photoURL);
          }
        } catch (e) {
          if (context.mounted) logAlert(context, message: e.toString());
        }
      }

      void onDeny() => Navigator.of(dialogContext).pop();

      return EzAlertDialog(
        contents: <Widget>[
          TextFormField(
            key: urlFormKey,
            controller: urlController,
            decoration: const InputDecoration(hintText: 'Enter URL'),
            validator: urlValidator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const EzSpacer(),

          // Explanation for not using image files
          const Text(
            'Images are expensive to store!\nPaste an image link and that will be used',
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ],
        materialActions: ezMaterialActions(
          context: context,
          onConfirm: onConfirm,
          confirmMsg: 'Submit',
          onDeny: onDeny,
          denyMsg: 'Cancel',
        ),
        cupertinoActions: ezCupertinoActions(
          context: context,
          onConfirm: onConfirm,
          confirmMsg: 'Submit',
          confirmIsDestructive: true,
          onDeny: onDeny,
          denyMsg: 'Cancel',
        ),
        needsClose: false,
      );
    },
  ).then((_) => urlController.dispose());
}

/// Gets the users display name
/// This can cost money! [https://firebase.google.com/pricing/]
Future<String> getName() async {
  final DocumentSnapshot<Map<String, dynamic>> userSnap =
      await AppUser.db.collection(usersPath).doc(AppUser.account.uid).get();

  final Map<String, dynamic> data = userSnap.data() as Map<String, dynamic>;

  return data[displayNamePath] ?? defaultDisplayName;
}

/// Update the users display name
/// This can cost money! [https://firebase.google.com/pricing/]
/// Returns the new name on success
Future<dynamic> editName(BuildContext context) {
  final GlobalKey<FormState> nameFormKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();

  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      void onConfirm() async {
        closeKeyboard(dialogContext);

        // Don't do anything if the display name is invalid
        if (!nameFormKey.currentState!.validate()) {
          logAlert(context, message: 'Invalid display name!');
          return;
        }

        // Update firestore and the firebase user config
        final String newName = nameController.text.trim();

        try {
          await AppUser.account.updateDisplayName(newName);
          await AppUser.db
              .collection(usersPath)
              .doc(AppUser.account.uid)
              .update(
            <String, dynamic>{displayNamePath: newName},
          );

          if (dialogContext.mounted) Navigator.of(dialogContext).pop(newName);
        } catch (e) {
          if (context.mounted) logAlert(context, message: e.toString());
        }
      }

      void onDeny() => Navigator.of(dialogContext).pop();

      return EzAlertDialog(
        title: const Text('Who are you?', textAlign: TextAlign.center),
        content: TextFormField(
          key: nameFormKey,
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Enter display name'),
          validator: displayNameValidator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        materialActions: ezMaterialActions(
          context: context,
          onConfirm: onConfirm,
          confirmMsg: 'Submit',
          onDeny: onDeny,
          denyMsg: 'Cancel',
        ),
        cupertinoActions: ezCupertinoActions(
          context: context,
          onConfirm: onConfirm,
          confirmMsg: 'Submit',
          confirmIsDestructive: true,
          onDeny: onDeny,
          denyMsg: 'Cancel',
        ),
        needsClose: false,
      );
    },
  ).then((_) => nameController.dispose());
}
