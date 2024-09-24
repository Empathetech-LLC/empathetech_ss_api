/* empathetech_ss_api
 * Copyright (c) 2022-2024 Empathetech LLC. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:empathetech_ss_api/empathetech_ss_api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:empathetech_flutter_ui/empathetech_flutter_ui.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// Return documents from the 'signals' collection
/// Filter by the current user's membership in the passed field
/// This can cost money! [https://firebase.google.com/pricing/]
Stream<QuerySnapshot<Map<String, dynamic>>> streamSignals(String filter) {
  try {
    return AppUser.db
        .collection(signalsPath)
        .where(filter, arrayContains: AppUser.account.uid)
        .snapshots();
  } catch (e) {
    return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  }
}

/// Add new signal to the DB
/// This can cost money! [https://firebase.google.com/pricing/]
Future<bool> addToDB({
  required BuildContext context,
  required String title,
  required String message,
  required bool isActive,
  required List<String> requestIDs,
}) async {
  try {
    // Check to see if a document with the same name exists
    final DocumentSnapshot<Map<String, dynamic>> check =
        await AppUser.db.collection(signalsPath).doc(title).get();

    if (check.exists) {
      if (context.mounted) logAlert(context, message: 'That name is taken!');
      return false;
    }

    // Upload the new document
    await AppUser.db.collection(signalsPath).doc(title).set(
      <String, dynamic>{
        messagePath: message,
        membersPath: <String>[AppUser.account.uid],
        ownerPath: AppUser.account.uid,
        activeMembersPath:
            isActive ? <String>[AppUser.account.uid] : <String>[],
        memberRequestsPath: requestIDs,
      },
    );

    return true;
  } catch (e) {
    if (context.mounted) logAlert(context, message: e.toString());
    return false;
  }
}

/// Add/remove the current user from the signals list of participants
/// Notify other signal members whenever someone joins
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> toggleParticipation({
  required BuildContext context,
  required bool active,
  required String title,
  required List<String> memberIDs,
  required String message,
}) async {
  try {
    if (active) {
      // User is already active, remove from the list
      await AppUser.db.collection(signalsPath).doc(title).update(
        <String, dynamic>{
          activeMembersPath: FieldValue.arrayRemove(
            <String>[AppUser.account.uid],
          )
        },
      );
    } else {
      // User is inactive, add to the list
      await AppUser.db.collection(signalsPath).doc(title).update(
        <String, dynamic>{
          activeMembersPath: FieldValue.arrayUnion(
            <String>[AppUser.account.uid],
          )
        },
      );
    }
  } catch (e) {
    if (context.mounted) logAlert(context, message: e.toString());
  }
}

/// Adds the list of users to the signals member requests
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> requestMembers({
  required BuildContext context,
  required String title,
  required List<String> toAdd,
}) async {
  try {
    await AppUser.db.collection(signalsPath).doc(title).update(
      <String, dynamic>{
        memberRequestsPath: FieldValue.arrayUnion(toAdd),
      },
    );
  } catch (e) {
    if (context.mounted) logAlert(context, message: e.toString());
  }
}

/// Accept joining the passed signal
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> acceptInvite(BuildContext context, String title) async {
  try {
    await AppUser.db.collection(signalsPath).doc(title).update(
      <String, dynamic>{
        membersPath: FieldValue.arrayUnion(<String>[AppUser.account.uid]),
        memberRequestsPath:
            FieldValue.arrayRemove(<String>[AppUser.account.uid]),
      },
    );
  } catch (e) {
    if (context.mounted) logAlert(context, message: e.toString());
  }
}

/// Decline joining the passed signal
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> declineInvite(BuildContext context, String title) async {
  try {
    await AppUser.db.collection(signalsPath).doc(title).update(
      <String, dynamic>{
        memberRequestsPath:
            FieldValue.arrayRemove(<String>[AppUser.account.uid]),
      },
    );
  } catch (e) {
    if (context.mounted) logAlert(context, message: e.toString());
  }
}

/// Reset the active members field of the passed signal
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> resetSignal(BuildContext context, String title) async {
  try {
    await AppUser.db.collection(signalsPath).doc(title).update(
      <String, dynamic>{activeMembersPath: <String>[]},
    );
  } catch (e) {
    if (context.mounted) logAlert(context, message: e.toString());
  }
}

/// Optionally update the notification message of the passed signal
/// This can cost money! [https://firebase.google.com/pricing/]
/// Returns the new message [String] on success
Future<dynamic> updateMessage(BuildContext context, String title) {
  final TextEditingController messageController = TextEditingController();

  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      void onConfirm() async {
        closeKeyboard(dialogContext);

        final String message = messageController.text.trim();

        // Don't do anything if the message is invalid
        if (signalMessageValidator(message) != null) {
          logAlert(context, message: 'Invalid message!');
          return;
        }

        try {
          // Upload the new message
          await AppUser.db.collection(signalsPath).doc(title).update(
            <String, dynamic>{messagePath: message},
          );

          if (dialogContext.mounted) Navigator.of(dialogContext).pop(message);
        } catch (e) {
          if (context.mounted) logAlert(context, message: e.toString());
          return;
        }
      }

      void onDeny() => Navigator.of(dialogContext).pop();

      return EzAlertDialog(
        title: const Text('New message...', textAlign: TextAlign.center),
        content: TextFormField(
          controller: messageController,
          maxLines: 1,
          decoration: const InputDecoration(hintText: 'Notification'),
          validator: signalMessageValidator,
          autovalidateMode: AutovalidateMode.onUnfocus,
        ),
        materialActions: ezMaterialActions(
          context: context,
          confirmMsg: 'Update',
          onConfirm: onConfirm,
          onDeny: onDeny,
        ),
        cupertinoActions: ezCupertinoActions(
          context: context,
          confirmMsg: 'Update',
          onConfirm: onConfirm,
          confirmIsDestructive: true,
          onDeny: onDeny,
        ),
        needsClose: false,
      );
    },
  ).then((_) => messageController.dispose());
}

/// Optionally transfer the signal to a new owner in firestore
/// This can cost money! [https://firebase.google.com/pricing/]
/// Returns [bool] true on success
Future<dynamic> confirmTransfer({
  required BuildContext context,
  required String title,
  required List<String> members,
}) {
  final List<String> others = List<String>.from(members);
  others.remove(AppUser.account.uid);

  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return EzAlertDialog(
        title: const Text('Select user', textAlign: TextAlign.center),
        content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: streamUsers(others),
          builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return const CircularProgressIndicator();
              case ConnectionState.done:
              default:
                if (snapshot.hasError) {
                  return Text(snapshot.error.toString());
                }

                final List<UserProfile> memberProfiles =
                    buildProfiles(snapshot.data!.docs);

                // Return an "avatar" of the none icon if there are no other members
                if (memberProfiles.isEmpty) {
                  return noUserCoin(context);
                }

                final List<Widget> children = <Widget>[];

                // Build the rows
                for (final UserProfile profile in memberProfiles) {
                  children.addAll(<Widget>[
                    GestureDetector(
                      onTap: () async {
                        try {
                          // Set the owner to "this" user
                          await AppUser.db
                              .collection(signalsPath)
                              .doc(title)
                              .update(<String, dynamic>{ownerPath: profile.id});

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            logAlert(context, message: e.toString());
                          }
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          // Profile image/avatar
                          CircleAvatar(
                            foregroundImage:
                                CachedNetworkImageProvider(profile.avatarURL),
                            minRadius: 35,
                            maxRadius: 35,
                          ),

                          // Display name
                          Text(profile.name, textAlign: TextAlign.start),
                        ],
                      ),
                    ),
                    const EzSpacer(),
                  ]);
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                );
            }
          },
        ),
      );
    },
  );
}

/// Optionally delete the signal in firestore and clear local prefs
/// This can cost money! [https://firebase.google.com/pricing/]
Future<dynamic> confirmDelete({
  required BuildContext context,
  required String title,
  required Set<String> prefKeys,
}) {
  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      void onConfirm() async {
        try {
          // Pop first to avoid errors
          Navigator.of(dialogContext).pop();

          // Clear local prefs for the signal
          await EzConfig.removeKeys(prefKeys);

          // Delete the signal from the db
          await AppUser.db.collection(signalsPath).doc(title).delete();
        } catch (e) {
          if (context.mounted) logAlert(context, message: e.toString());
        }
      }

      void onDeny() => Navigator.of(dialogContext).pop();

      return EzAlertDialog(
        title: Text('Delete $title?', textAlign: TextAlign.center),
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

/// Optionally delete the signal in firestore and clear local prefs
/// This can cost money! [https://firebase.google.com/pricing/]
Future<dynamic> confirmDeparture({
  required BuildContext context,
  required String title,
  required Set<String> prefKeys,
}) {
  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      void onConfirm() async {
        try {
          // Pop first to avoid errors
          Navigator.of(dialogContext).pop();

          // Clear local prefs for the signal
          await EzConfig.removeKeys(prefKeys);

          // Remove the current user from the list of members
          await AppUser.db.collection(signalsPath).doc(title).update(
            <String, dynamic>{
              membersPath: FieldValue.arrayRemove(<String>[AppUser.account.uid])
            },
          );
        } catch (e) {
          if (context.mounted) logAlert(context, message: e.toString());
        }
      }

      void onDeny() => Navigator.of(context).pop();

      return EzAlertDialog(
        title: Text('Leave $title?', textAlign: TextAlign.center),
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
