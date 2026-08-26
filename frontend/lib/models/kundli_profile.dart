import 'package:flutter/foundation.dart';

/// A person whose birth chart can be viewed — either the signed-in user
/// ("My Kundli") or someone generated via "Get Kundli" (family/friend).
/// All fields are display strings; no backend/ephemeris exists yet.
class KundliProfile {
  const KundliProfile({
    required this.id,
    required this.name,
    required this.isOwn,
    required this.dob,
    required this.tob,
    required this.tobUnknown,
    required this.place,
    required this.generatedOn,
  });

  final String id;
  final String name;
  final bool isOwn;
  final String dob;
  final String tob;
  final bool tobUnknown;
  final String place;
  final String generatedOn;

  static const own = KundliProfile(
    id: 'own',
    name: 'You',
    isOwn: true,
    dob: '24 October 1988',
    tob: '04:42 AM',
    tobUnknown: false,
    place: 'Mumbai, Maharashtra, India',
    generatedOn: 'At onboarding',
  );
}

/// In-memory store of Kundlis generated for family/friends via "Get Kundli".
/// No backend yet, so this only lives for the app session — a [ValueNotifier]
/// so the landing screen's saved-list rebuilds itself on add/remove.
class KundliStore {
  KundliStore._();

  static final ValueNotifier<List<KundliProfile>> saved =
      ValueNotifier<List<KundliProfile>>(<KundliProfile>[]);

  static void add(KundliProfile profile) {
    saved.value = [...saved.value, profile];
  }

  static void remove(KundliProfile profile) {
    saved.value = saved.value.where((p) => p.id != profile.id).toList();
  }
}
