library empathetech_ss_api;

import 'package:empathetech_ss_api/empathetech_ss_api.dart';
import 'package:empathetech_flutter_ui/empathetech_flutter_ui.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// Localized mirror of Firebase [User] information
class UserProfile {
  String id;
  String name;
  String avatarURL;

  UserProfile(this.id, this.name, this.avatarURL);

  /// Builds a local [UserProfile] from a Firestore (user) [DocumentSnapshot]
  static UserProfile buildFromDoc(DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;
    return UserProfile(userDoc.id, data[displayNamePath], data[avatarURLPath]);
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile && this.id == other.id && this.name == other.name;

  @override
  int get hashCode => Object.hash(this.id, this.name);

  @override
  String toString() {
    return this.name;
  }
}

/// Map all Firebase [DocumentSnapshot] user docs to local [UserProfile]s
List<UserProfile> buildProfiles(List<DocumentSnapshot> userDocs) {
  return userDocs
      .map((DocumentSnapshot userDoc) => UserProfile.buildFromDoc(userDoc))
      .toList();
}

/// [Widget] to display when there are on users found
Widget noUserCoin(BuildContext context) {
  return GestureDetector(
    onLongPress: () => ezDialog(
      context: context,
      content: [
        Text(
          'Nobody!',
          style: buildTextStyle(style: dialogTitleStyleKey),
          textAlign: TextAlign.center,
        ),
      ],
    ),
    child: Container(
      decoration: BoxDecoration(
        color: Color(EzConfig.prefs[themeColorKey]),
        shape: BoxShape.circle,
      ),
      child: EzIcon(
        PlatformIcons(context).clear,
        color: Color(EzConfig.prefs[themeTextColorKey]),
        size: 35,
      ),
    ),
  );
}

/// Displays a horizontally scrollable list of [UserProfile] pictures
Widget showUserPics(BuildContext context, List<UserProfile> profiles) {
  // Return clear icon on empty list
  if (profiles.isEmpty) return noUserCoin(context);

  List<Widget> children = [];

  // Build the avatars
  profiles.forEach((profile) {
    children.addAll(
      [
        GestureDetector(
          // On long press: display the user's profile name
          onLongPress: () => ezDialog(
            context: context,
            content: [
              Text(
                profile.name,
                style: buildTextStyle(style: dialogTitleStyleKey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          child: CircleAvatar(
            foregroundImage: CachedNetworkImageProvider(profile.avatarURL),
            minRadius: 35,
            maxRadius: 35,
          ),
        ),
        Container(width: EzConfig.prefs[paddingKey]),
      ],
    );
  });

  return EzScrollView(
    children: children,
    centered: true,
    mainAxisSize: MainAxisSize.max,
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    direction: Axis.horizontal,
  );
}

/// Displays a list of [UserProfile] pictures alongside their display names
Widget showUserProfiles(BuildContext context, List<UserProfile> profiles) {
  double dialogSpacer = EzConfig.prefs[dialogSpacingKey];

  // Return clear icon on empty list
  if (profiles.isEmpty)
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        noUserCoin(context),
        Container(height: dialogSpacer),
      ],
    );

  List<Widget> children = [];

  // Build the rows
  profiles.forEach((profile) {
    children.addAll([
      Row(
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
          Text(
            profile.name,
            style: buildTextStyle(style: dialogTitleStyleKey),
            textAlign: TextAlign.start,
          ),
        ],
      ),
      Container(height: dialogSpacer),
    ]);
  });

  return EzScrollView(children: children, centered: true);
}

/// Wraps [PlatformListTile]s in an [EzScrollView] with a [title]
/// Optionally provide a height limit, 1/3 [screenHeight] will be used as default
Widget addProfilesWindow({
  required BuildContext context,
  required String title,
  required List<PlatformListTile> items,
  double? customHeight,
}) {
  Color themeColor = Color(EzConfig.prefs[themeColorKey]);
  TextStyle titleStyle = buildTextStyle(style: titleStyleKey);

  return Container(
    width: screenWidth(context),
    height: customHeight ?? screenHeight(context) / 3.0,
    decoration: BoxDecoration(
      color: themeColor.withOpacity(themeColor.opacity * 0.75),
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text(title, style: titleStyle),
        EzScrollView(children: items),
      ],
    ),
  );
}
