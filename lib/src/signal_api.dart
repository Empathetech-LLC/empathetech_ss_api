library empathetech_ss_api;

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:empathetech_ss_api/empathetech_ss_api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:empathetech_flutter_ui/empathetech_flutter_ui.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// Return documents from the 'signals' collection
/// Filter by the current user's membership in the passed field
/// This can cost money! [https://firebase.google.com/pricing/]
Stream<QuerySnapshot<Object?>> streamSignals(String filter) {
  try {
    return AppUser.db
        .collection(signalsPath)
        .where(filter, arrayContains: AppUser.account.uid)
        .snapshots();
  } catch (e) {
    return Stream.empty();
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
    final check = await AppUser.db.collection(signalsPath).doc(title).get();

    if (check.exists) {
      logAlert(context: context, message: 'That name is taken!');
      return false;
    }

    // Upload the new document
    await AppUser.db.collection(signalsPath).doc(title).set(
      {
        messagePath: message,
        membersPath: [AppUser.account.uid],
        ownerPath: AppUser.account.uid,
        activeMembersPath: isActive ? [AppUser.account.uid] : [],
        memberReqsPath: requestIDs,
      },
    );

    return true;
  } catch (e) {
    logAlert(context: context, message: e.toString());
    return false;
  }
}

/// Add/remove the current user from the signals list of participants
/// Notify other signal members whenever someone joins
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> toggleParticipation({
  required BuildContext context,
  required bool joined,
  required String title,
  required List<String> memberIDs,
  required String message,
}) async {
  try {
    if (joined) {
      await AppUser.db.collection(signalsPath).doc(title).update(
        {
          activeMembersPath: FieldValue.arrayRemove([AppUser.account.uid])
        },
      );
    } else {
      await AppUser.db.collection(signalsPath).doc(title).update(
        {
          activeMembersPath: FieldValue.arrayUnion([AppUser.account.uid])
        },
      );

      // Notify members (if there's anyone to notify)
      List<String> others = new List.from(memberIDs);
      others.remove(AppUser.account.uid);

      if (others.isNotEmpty) {
        List<String> tokens = await gatherTokens(others);
        if (tokens.isEmpty) return;

        try {
          await FirebaseFunctions.instance.httpsCallable(sendPushFunc).call({
            tokenData: tokens,
            titleData: title,
            bodyData: message,
          });
        } on FirebaseFunctionsException catch (e) {
          logAlert(context: context, message: e.toString());
        }
      }
    }
  } catch (e) {
    logAlert(context: context, message: e.toString());
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
      {
        memberReqsPath: FieldValue.arrayUnion(toAdd),
      },
    );
  } catch (e) {
    logAlert(context: context, message: e.toString());
  }
}

/// Accept joining the passed signal
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> acceptInvite(BuildContext context, String title) async {
  try {
    await AppUser.db.collection(signalsPath).doc(title).update(
      {
        membersPath: FieldValue.arrayUnion([AppUser.account.uid]),
        memberReqsPath: FieldValue.arrayRemove([AppUser.account.uid]),
      },
    );
  } catch (e) {
    logAlert(context: context, message: e.toString());
  }
}

/// Decline joining the passed signal
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> declineInvite(BuildContext context, String title) async {
  try {
    await AppUser.db.collection(signalsPath).doc(title).update(
      {
        memberReqsPath: FieldValue.arrayRemove([AppUser.account.uid]),
      },
    );
  } catch (e) {
    logAlert(context: context, message: e.toString());
  }
}

/// Reset the active members field of the passed signal
/// This can cost money! [https://firebase.google.com/pricing/]
Future<void> resetSignal(BuildContext context, String title) async {
  try {
    await AppUser.db.collection(signalsPath).doc(title).update(
      {activeMembersPath: []},
    );
  } catch (e) {
    logAlert(context: context, message: e.toString());
  }
}

/// Optionally update the notification message of the passed signal
/// This can cost money! [https://firebase.google.com/pricing/]
/// Returns the new message [String] on success
Future<dynamic> updateMessage(BuildContext context, String title) {
  final messageFormKey = GlobalKey<FormState>();
  TextEditingController _messageController = TextEditingController();

  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      void onConfirm() async {
        // Don't do anything if the message is invalid
        if (!messageFormKey.currentState!.validate()) {
          logAlert(context: context, message: 'Invalid message!');
          return;
        }

        try {
          // Upload the new message
          String message = _messageController.text.trim();
          await AppUser.db.collection(signalsPath).doc(title).update(
            {messagePath: message},
          );

          Navigator.of(context).pop(message);
        } catch (e) {
          logAlert(context: context, message: e.toString());
          return;
        }
      }

      void onDeny() => Navigator.of(dialogContext).pop();

      return EzAlertDialog(
        title: const Text('New message...'),
        content: TextFormField(
          key: messageFormKey,
          controller: _messageController,
          initialValue: 'Notification',
          validator: signalMessageValidator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
  ).then((_) => _messageController.dispose());
}

/// Optionally transfer the signal to a new owner in firestore
/// This can cost money! [https://firebase.google.com/pricing/]
/// Returns [bool] true on success
Future<dynamic> confirmTransfer({
  required BuildContext context,
  required String title,
  required List<String> members,
}) {
  List<String> others = new List.from(members);
  others.remove(AppUser.account.uid);

  // Build a list of profile buttons that, on tap, update ownership in the db
  Widget buildSelectors(List<UserProfile> memberProfiles) {
    // Return an "avatar" of the none icon if there are no other members
    if (memberProfiles.isEmpty)
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          noUserCoin(context),
          Container(height: dialogSpacer),
        ],
      );

    List<Widget> children = [];

    // Build the rows
    memberProfiles.forEach((profile) {
      children.addAll([
        GestureDetector(
          onTap: () async {
            try {
              // Set the owner to "this" user
              await AppUser.db.collection(signalsPath).doc(title).update(
                {ownerPath: profile.id},
              );
              Navigator.of(context).pop(true);
            } catch (e) {
              logAlert(context: context, message: e.toString());
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Profile image/avatar
              CircleAvatar(
                foregroundImage: CachedNetworkImageProvider(profile.avatarURL),
                minRadius: 35,
                maxRadius: 35,
              ),

              // Display name
              Text(profile.name, textAlign: TextAlign.start),
            ],
          ),
        ),
        Container(height: dialogSpacer),
      ]);
    });

    return EzScrollView(children: children);
  }

  // Actual pop-up
  return showPlatformDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return EzAlertDialog(
        title: const Text('Select user'),
        contents: [
          StreamBuilder<QuerySnapshot>(
            stream: streamUsers(others),
            builder:
                (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.waiting:
                  return PlatformCircularProgressIndicator(
                    material: (context, platform) =>
                        MaterialProgressIndicatorData(
                      color: Color(EzConfig.prefs[buttonColorKey]),
                    ),
                    cupertino: (context, platform) =>
                        CupertinoProgressIndicatorData(
                      color: Color(EzConfig.prefs[buttonColorKey]),
                    ),
                  );
                case ConnectionState.done:
                default:
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        snapshot.error.toString(),
                        style: buildTextStyle(styleKey: errorStyleKey),
                      ),
                    );
                  }

                  return buildSelectors(buildProfiles(snapshot.data!.docs));
              }
            },
          ),
        ],
      );
    },
  );
}

/// Optionally delete the signal in firestore and clear local prefs
/// This can cost money! [https://firebase.google.com/pricing/]
Future<dynamic> confirmDelete({
  required BuildContext context,
  required String title,
  required List<String> prefKeys,
}) {
  return showPlatformDialog(
    context: context,
    dialog: EzAlertDialog(
      title: Text(
        'Delete $title?',
        style: buildTextStyle(styleKey: dialogTitleStyleKey),
      ),
      contents: [
        ezYesNo(
          context: context,
          onConfirm: () async {
            try {
              // Pop first to avoid errors
              Navigator.of(context).pop();

              // Clear local prefs for the signal
              prefKeys.forEach((key) {
                EzConfig.preferences.remove(key);
              });

              // Delete the signal from the db
              await AppUser.db.collection(signalsPath).doc(title).delete();
            } catch (e) {
              logAlert(context: context, message: e.toString());
            }
          },
          onDeny: () => Navigator.of(context).pop(),
          axis: Axis.vertical,
          spacer: EzConfig.prefs[dialogSpacingKey],
        ),
      ],
      needsClose: false,
    ),
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
          EzConfig.removeKeys(prefKeys);

          // Remove the current user from the list of members
          await AppUser.db.collection(signalsPath).doc(title).update(
            {
              membersPath: FieldValue.arrayRemove([AppUser.account.uid])
            },
          );
        } catch (e) {
          logAlert(context: context, message: e.toString());
        }
      }

      void onDeny() => Navigator.of(context).pop();

      return EzAlertDialog(
        content: Text('Leave $title?'),
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
