const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

exports.sendremotecommandnotification = functions.firestore
    .document("commands/{commandId}")
    .onCreate(async (snapshot, context) => {
      const commandData = snapshot.data();
      if (!commandData) {
        console.log("No data associated with the event");
        return null;
      }

      const userId = commandData.userId;
      const commandType = commandData.type;

      try {
        // Fetch target user's document to get their FCM token
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
          console.log("User not found for ID:", userId);
          return null;
        }

        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) {
          console.log("FCM token not available for user:", userId);
          return null;
        }

        
        const message = {
          token: fcmToken,
          data: {
            commandId: context.params.commandId,
            type: commandType,
            action: "EXECUTE_REMOTE_COMMAND",
          },
          android: {
            priority: "high",
          },
          apns: {
            payload: {
              aps: {
                contentAvailable: true,
              },
            },
          },
        };

        // Send notification via FCM
        await admin.messaging().send(message);
        console.log(`Successfully sent ${commandType} command to user ${userId}`);

        // Update command document status to 'sent'
        await snapshot.ref.update({status: "sent"});
        return null;
      } catch (error) {
        console.error("Error sending remote command notification:", error);
        return null;
      }
    });