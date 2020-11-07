import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:foobar/model/danger_notification.dart';
import 'package:geolocator/geolocator.dart';

class DatabaseMethods {
  FirebaseFirestore _database = FirebaseFirestore.instance;
  FirebaseMessaging _fcm = FirebaseMessaging();

  Future createUserDocument({String email, String name, String uid}) async {
    try {
      await _database.collection("users").doc(uid).set(
        {"email": email, "name": name, "uid": uid},
      );
    } on Exception catch (e) {
      print(e);
      return null;
    }
  }

  Future updateUserLocation({Position location, String uid}) async {
    try {
      await _database.collection("users").doc(uid).update(
        {
          "location": {
            "longitude": location.longitude,
            "latitude": location.latitude
          },
        },
      );
    } on Exception catch (e) {
      print(e);
      return null;
    }
  }

  Future updateUserFcmToken({String uid}) async {
    try {
      String token = await _fcm.getToken();
      await _database.collection("users").doc(uid).update(
        {"fcmToken": token},
      );
    } on Exception catch (e) {
      print(e);
      return null;
    }
  }

  Future _triggerAlertCloudFunction() async {
    Position userLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'sendDangerAlert',
    );
    await callable.call(<String, double>{
      'latitude': userLocation.latitude,
      'longitude': userLocation.longitude
    });
  }

  Future sendDangerAlert() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (LocationPermission.denied.index == permission.index) {
        LocationPermission permission2 = await Geolocator.requestPermission();

        if (LocationPermission.whileInUse.index == permission2.index ||
            LocationPermission.always.index == permission2.index) {
          await _triggerAlertCloudFunction();
        }
      } else if (LocationPermission.whileInUse.index == permission.index ||
          LocationPermission.always.index == permission.index) {
        await _triggerAlertCloudFunction();
      }
    } on Exception catch (e) {}
  }

  Stream<List<DangerNotification>> getAllAlertNotifications({String uid}) {
    // _database.collection("collectionPath").doc("Asd").collection("asd").snapshots();
    return _database
        .collection("users")
        .doc(uid)
        .collection("dangerNotifications")
        .orderBy("time", descending: true)
        .snapshots()
        .map((event) {
      print(event);

      return event.docs.map((e) {
        print(e.data()["location"]["latitude"]);
        return DangerNotification(
            latitude: e.data()["location"]["latitude"],
            longitude: e.data()["location"]["longitude"],
            time: e.data()["time"]);
      }).toList();
    });
  }
}
