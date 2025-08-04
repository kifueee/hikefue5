import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
const sgMail = require('@sendgrid/mail');

admin.initializeApp();

// Initialize SendGrid
const sendGridApiKey = functions.config().sendgrid?.api_key;
if (sendGridApiKey) {
  sgMail.setApiKey(sendGridApiKey);
}

// Helper function to create organizer notification
async function createOrganizerNotification(
  organizerId: string,
  title: string,
  body: string,
  type: string,
  eventId?: string,
  additionalData?: any
) {
  const notifRef = admin.firestore()
    .collection('organizers')
    .doc(organizerId)
    .collection('notifications')
    .doc();
  
  await notifRef.set({
    title,
    body,
    type,
    eventId,
    additionalData,
    read: false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// Write a notification to all participants when a new event is created
export const notifyOnNewEvent = functions.firestore
  .document('events/{eventId}')
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    const eventData = snap.data();
    if (!eventData) return;

    const participantsSnapshot = await admin.firestore().collection('participants').get();
    const batch = admin.firestore().batch();

    participantsSnapshot.forEach((doc: FirebaseFirestore.QueryDocumentSnapshot) => {
      const notifRef = doc.ref.collection('notifications').doc();
      batch.set(notifRef, {
        title: 'New Event Available',
        body: `A new event "${eventData.name}" has been created!`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });
    });

    await batch.commit();
  });

// Notify participants when event details are updated
export const notifyOnEventUpdate = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    // Check if important fields changed
    const importantFields = ['name', 'date', 'location', 'description', 'maxParticipants'];
    const hasImportantChange = importantFields.some(field => 
      JSON.stringify(beforeData[field]) !== JSON.stringify(afterData[field])
    );

    if (!hasImportantChange) return;

    const eventName = afterData.name || 'Event';
    
    // Get participants for this event
    const participants = afterData.participants || {};
    const participantIds = Object.keys(participants);
    
    if (participantIds.length === 0) return;

    const batch = admin.firestore().batch();

    participantIds.forEach((participantId) => {
      const notifRef = admin.firestore()
        .collection('participants')
        .doc(participantId)
        .collection('notifications')
        .doc();
      
      batch.set(notifRef, {
        title: 'Event Updated',
        body: `The event "${eventName}" has been updated. Check the new details!`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        eventId: context.params.eventId,
      });
    });

    await batch.commit();
  });

// Notify participants when event is cancelled
export const notifyOnEventCancellation = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    // Check if event was cancelled
    const wasActive = beforeData.status === 'approved' || beforeData.status === 'active';
    const isCancelled = afterData.status === 'cancelled';

    if (!wasActive || !isCancelled) return;

    const eventName = afterData.name || 'Event';
    
    // Get participants for this event
    const participants = afterData.participants || {};
    const participantIds = Object.keys(participants);
    
    if (participantIds.length === 0) return;

    const batch = admin.firestore().batch();

    participantIds.forEach((participantId) => {
      const notifRef = admin.firestore()
        .collection('participants')
        .doc(participantId)
        .collection('notifications')
        .doc();
      
      batch.set(notifRef, {
        title: 'Event Cancelled',
        body: `The event "${eventName}" has been cancelled. We apologize for any inconvenience.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        eventId: context.params.eventId,
      });
    });

    await batch.commit();
  });

// Notify participants when they join an event
export const notifyOnEventJoin = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    const beforeParticipants = beforeData.participants || {};
    const afterParticipants = afterData.participants || {};
    
    // Find new participants
    const newParticipantIds = Object.keys(afterParticipants).filter(
      participantId => !beforeParticipants[participantId]
    );

    if (newParticipantIds.length === 0) return;

    const eventName = afterData.name || 'Event';
    const batch = admin.firestore().batch();

    newParticipantIds.forEach((participantId) => {
      const notifRef = admin.firestore()
        .collection('participants')
        .doc(participantId)
        .collection('notifications')
        .doc();
      
      batch.set(notifRef, {
        title: 'Welcome to Event!',
        body: `You have successfully joined "${eventName}". Get ready for an amazing adventure!`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        eventId: context.params.eventId,
      });
    });

    await batch.commit();
  });

// Notify participants when event is full
export const notifyOnEventFull = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    const maxParticipants = afterData.maxParticipants || 0;
    const beforeCount = Object.keys(beforeData.participants || {}).length;
    const afterCount = Object.keys(afterData.participants || {}).length;
    
    // Check if event just became full
    const wasNotFull = beforeCount < maxParticipants;
    const isNowFull = afterCount >= maxParticipants;

    if (!wasNotFull || !isNowFull) return;

    const eventName = afterData.name || 'Event';
    
    // Notify all participants that the event is full
    const participants = afterData.participants || {};
    const participantIds = Object.keys(participants);
    
    if (participantIds.length === 0) return;

    const batch = admin.firestore().batch();

    participantIds.forEach((participantId) => {
      const notifRef = admin.firestore()
        .collection('participants')
        .doc(participantId)
        .collection('notifications')
        .doc();
      
      batch.set(notifRef, {
        title: 'Event is Full!',
        body: `The event "${eventName}" has reached maximum capacity. You're lucky to have secured your spot!`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        eventId: context.params.eventId,
      });
    });

    await batch.commit();
  });

// Scheduled function to send event reminders (runs daily at 9 AM)
export const sendEventReminders = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Asia/Kuala_Lumpur')
  .onRun(async (context) => {
    const now = new Date();
    const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    // Get events happening tomorrow, in 3 days, and in 7 days
    const eventsSnapshot = await admin.firestore()
      .collection('events')
      .where('date', '>=', now)
      .where('date', '<=', sevenDaysFromNow)
      .where('status', 'in', ['approved', 'active'])
      .get();

    const batch = admin.firestore().batch();

    eventsSnapshot.docs.forEach((eventDoc) => {
      const eventData = eventDoc.data();
      const eventDate = eventData.date.toDate();
      const participants = eventData.participants || {};
      const participantIds = Object.keys(participants);

      if (participantIds.length === 0) return;

      let title = '';
      let body = '';

      // Determine reminder type
      const daysUntilEvent = Math.ceil((eventDate.getTime() - now.getTime()) / (24 * 60 * 60 * 1000));

      if (daysUntilEvent === 1) {
        title = 'Event Tomorrow!';
        body = `Your event "${eventData.name}" is tomorrow! Don't forget to prepare and attend.`;
      } else if (daysUntilEvent <= 3) {
        title = 'Event Coming Soon';
        body = `Your event "${eventData.name}" is in ${daysUntilEvent} days. Start getting ready!`;
      } else if (daysUntilEvent <= 7) {
        title = 'Event Reminder';
        body = `Your event "${eventData.name}" is in ${daysUntilEvent} days. Mark your calendar!`;
      } else {
        return; // Don't send reminders for events more than a week away
      }

      participantIds.forEach((participantId) => {
        const notifRef = admin.firestore()
          .collection('participants')
          .doc(participantId)
          .collection('notifications')
          .doc();
        
        batch.set(notifRef, {
          title: title,
          body: body,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
          eventId: eventDoc.id,
        });
      });
    });

    await batch.commit();
    console.log(`Sent event reminders`);
  });

// ===== ORGANIZER NOTIFICATION TRIGGERS =====

// Notify organizer when new participant joins their event
export const notifyOrganizerOnParticipantJoin = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    const beforeParticipants = beforeData.participants || {};
    const afterParticipants = afterData.participants || {};
    
    // Find new participants (excluding organizer)
    const newParticipantIds = Object.keys(afterParticipants).filter(
      participantId => !beforeParticipants[participantId] && afterParticipants[participantId]?.role !== 'organizer'
    );

    if (newParticipantIds.length === 0) return;

    const eventName = afterData.name || 'Event';
    const organizerId = afterData.organizerId;
    
    if (!organizerId) return;

    // Get participant names
    for (const participantId of newParticipantIds) {
      const participantData = afterParticipants[participantId];
      const participantName = participantData?.name || 'A participant';
      
      await createOrganizerNotification(
        organizerId,
        'New Participant',
        `${participantName} has registered for "${eventName}".`,
        'new_participant',
        context.params.eventId,
        { participantName }
      );
    }
  });

// Notify organizer when participant cancels
export const notifyOrganizerOnParticipantCancel = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    const beforeParticipants = beforeData.participants || {};
    const afterParticipants = afterData.participants || {};
    
    // Find removed participants (excluding organizer)
    const removedParticipantIds = Object.keys(beforeParticipants).filter(
      participantId => !afterParticipants[participantId] && beforeParticipants[participantId]?.role !== 'organizer'
    );

    if (removedParticipantIds.length === 0) return;

    const eventName = afterData.name || 'Event';
    const organizerId = afterData.organizerId;
    
    if (!organizerId) return;

    // Get participant names
    for (const participantId of removedParticipantIds) {
      const participantData = beforeParticipants[participantId];
      const participantName = participantData?.name || 'A participant';
      
      await createOrganizerNotification(
        organizerId,
        'Participant Cancelled',
        `${participantName} has cancelled their registration for "${eventName}".`,
        'participant_cancelled',
        context.params.eventId,
        { participantName }
      );
    }
  });

// Notify organizer when event becomes full
export const notifyOrganizerOnEventFull = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    const maxParticipants = afterData.details?.maxParticipants || 0;
    const beforeCount = Object.keys(beforeData.participants || {}).length;
    const afterCount = Object.keys(afterData.participants || {}).length;
    
    // Check if event just became full
    const wasNotFull = beforeCount < maxParticipants;
    const isNowFull = afterCount >= maxParticipants;

    if (!wasNotFull || !isNowFull) return;

    const eventName = afterData.name || 'Event';
    const organizerId = afterData.organizerId;
    
    if (!organizerId) return;

    await createOrganizerNotification(
      organizerId,
      'Event Full!',
      `Your event "${eventName}" has reached maximum capacity.`,
      'event_full',
      context.params.eventId
    );
  });

// Notify organizer when event is almost full (80% capacity)
export const notifyOrganizerOnEventAlmostFull = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    const maxParticipants = afterData.details?.maxParticipants || 0;
    const beforeCount = Object.keys(beforeData.participants || {}).length;
    const afterCount = Object.keys(afterData.participants || {}).length;
    
    // Check if event just reached 80% capacity
    const beforePercentage = (beforeCount / maxParticipants) * 100;
    const afterPercentage = (afterCount / maxParticipants) * 100;
    
    const wasBelow80 = beforePercentage < 80;
    const isNow80OrAbove = afterPercentage >= 80;

    if (!wasBelow80 || !isNow80OrAbove) return;

    const eventName = afterData.name || 'Event';
    const organizerId = afterData.organizerId;
    const spotsLeft = maxParticipants - afterCount;
    
    if (!organizerId) return;

    await createOrganizerNotification(
      organizerId,
      'Event Almost Full',
      `Your event "${eventName}" has only ${spotsLeft} spots remaining.`,
      'event_almost_full',
      context.params.eventId,
      { spotsLeft }
    );
  });

// Notify organizer when payment is received
export const notifyOrganizerOnPaymentReceived = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    if (!beforeData || !afterData) return;

    const beforeParticipants = beforeData.participants || {};
    const afterParticipants = afterData.participants || {};
    
    // Find participants whose payment status changed to paid
    const newPaidParticipants = Object.keys(afterParticipants).filter(participantId => {
      const beforeParticipant = beforeParticipants[participantId];
      const afterParticipant = afterParticipants[participantId];
      
      if (!beforeParticipant || !afterParticipant) return false;
      
      const wasPaid = beforeParticipant.paymentDetails?.paid === true;
      const isNowPaid = afterParticipant.paymentDetails?.paid === true;
      
      return !wasPaid && isNowPaid && afterParticipant.role !== 'organizer';
    });

    if (newPaidParticipants.length === 0) return;

    const eventName = afterData.name || 'Event';
    const organizerId = afterData.organizerId;
    
    if (!organizerId) return;

    // Notify for each new payment
    for (const participantId of newPaidParticipants) {
      const participantData = afterParticipants[participantId];
      const participantName = participantData?.name || 'A participant';
      const amount = participantData?.paymentDetails?.amount || 0;
      
      await createOrganizerNotification(
        organizerId,
        'Payment Received',
        `${participantName} has paid RM${amount.toFixed(2)} for "${eventName}".`,
        'payment_received',
        context.params.eventId,
        { participantName, amount }
      );
    }
  });

// Scheduled function to send event reminders to organizers
export const sendOrganizerEventReminders = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('Asia/Kuala_Lumpur')
  .onRun(async (context) => {
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    // Get events happening tomorrow
    const eventsSnapshot = await admin.firestore()
      .collection('events')
      .where('date', '>=', now)
      .where('date', '<=', tomorrow)
      .where('status', 'in', ['approved', 'active'])
      .get();

    for (const eventDoc of eventsSnapshot.docs) {
      const eventData = eventDoc.data();
      const organizerId = eventData.organizerId;
      
      if (!organizerId) continue;

      const eventDate = eventData.date.toDate();
      const hoursUntilEvent = Math.ceil((eventDate.getTime() - now.getTime()) / (60 * 60 * 1000));

      if (hoursUntilEvent <= 24 && hoursUntilEvent > 0) {
        await createOrganizerNotification(
          organizerId,
          'Event Starting Soon',
          `Your event "${eventData.name}" starts in ${hoursUntilEvent} hours. Make sure everything is ready!`,
          'event_starting_soon',
          eventDoc.id
        );
      }
    }

    console.log(`Sent organizer event reminders`);
  });

// Notify organizer when carpool request is made
export const notifyOrganizerOnCarpoolRequest = functions.firestore
  .document('carpools/{carpoolId}')
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    const carpoolData = snap.data();
    if (!carpoolData) return;

    const eventId = carpoolData.eventId;
    const driverName = carpoolData.driverName || 'A driver';
    
    if (!eventId) return;

    // Get event details
    const eventDoc = await admin.firestore().collection('events').doc(eventId).get();
    if (!eventDoc.exists) return;

    const eventData = eventDoc.data();
    if (!eventData) return;

    const eventName = eventData.name || 'Event';
    const organizerId = eventData.organizerId;
    
    if (!organizerId) return;

    await createOrganizerNotification(
      organizerId,
      'Carpool Request',
      `${driverName} has applied to be a driver for "${eventName}".`,
      'carpool_request',
      eventId,
      { driverName }
    );
  });

// Scheduled function: Daily countdown notifications for payment and event start
export const sendDailyCountdownNotifications = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const db = admin.firestore();
  const now = new Date();
  const eventsSnap = await db.collection('events').get();

  for (const eventDoc of eventsSnap.docs) {
    const event = eventDoc.data();
    const eventId = eventDoc.id;
    const eventName = event.name || 'Event';
    const eventDate = event.date && event.date.toDate ? event.date.toDate() : null;
    const participants = event.participants || {};
    const pricing = event.pricing || {};
    const paymentDeadline = pricing.paymentDeadline && pricing.paymentDeadline.toDate ? pricing.paymentDeadline.toDate() : null;

    for (const [uid, participantRaw] of Object.entries(participants)) {
      const participant = participantRaw as any;
      // Payment countdown
      if (paymentDeadline instanceof Date && (!participant.paymentDetails || !participant.paymentDetails.paid)) {
        const daysLeft = Math.ceil((paymentDeadline.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
        if (daysLeft >= 0) {
          await db.collection('participants').doc(uid).collection('notifications').add({
            title: 'Payment Reminder',
            body: `Your payment for "${eventName}" is due in ${daysLeft} day(s).`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
            eventId,
          });
        }
      }
      // Event countdown
      if (eventDate instanceof Date) {
        const daysToEvent = Math.ceil((eventDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
        if (daysToEvent > 0) {
          await db.collection('participants').doc(uid).collection('notifications').add({
            title: 'Event Countdown',
            body: `"${eventName}" starts in ${daysToEvent} day(s).`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
            eventId,
          });
        }
      }
    }
  }
});

// Function to send organizer approval email with password setup instructions
export const sendOrganizerApprovalEmail = functions.https.onCall(async (data, context) => {
  // Verify that the request is from an authenticated admin
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated to send emails');
  }

  // Verify admin role
  const adminDoc = await admin.firestore().collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Must be an admin to send emails');
  }

  const { organizerEmail, organizerName, organizationName } = data;

  if (!organizerEmail || !organizerName) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Check if SendGrid is configured
  if (!sendGridApiKey) {
    console.error('SendGrid API key not configured');
    throw new functions.https.HttpsError('failed-precondition', 'Email service not configured');
  }

  const msg = {
    to: organizerEmail,
    from: 'hikefue@gmail.com', // Your verified SendGrid sender email
    subject: '🎉 Welcome to HikeFue5 - Your Organizer Account is Approved!',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to HikeFue5 - Account Approved</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa; }
          .container { background: white; border-radius: 15px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }
          .header { background: linear-gradient(135deg, #4B7F3F, #94BC45); color: white; padding: 40px 30px; text-align: center; position: relative; }
          .header::before { content: ''; position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="mountainPattern" x="0" y="0" width="20" height="20" patternUnits="userSpaceOnUse"><path d="M10,5 L15,15 L5,15 Z" fill="rgba(255,255,255,0.1)"/></pattern></defs><rect width="100" height="100" fill="url(%23mountainPattern)"/></svg>'); opacity: 0.3; }
          .header-content { position: relative; z-index: 1; }
          .header h1 { font-size: 32px; margin: 0 0 10px 0; font-weight: 700; text-shadow: 0 2px 4px rgba(0,0,0,0.3); }
          .header .subtitle { font-size: 18px; margin: 0; opacity: 0.9; }
          .content { padding: 40px 30px; }
          .welcome-box { background: linear-gradient(135deg, #e8f5e8, #f0f8f0); border-left: 5px solid #4B7F3F; padding: 25px; margin: 25px 0; border-radius: 10px; position: relative; }
          .welcome-box::before { content: '🎉'; position: absolute; top: -10px; right: 20px; font-size: 30px; }
          .credentials-box { background: #f8f9fa; border: 2px dashed #4B7F3F; padding: 25px; margin: 25px 0; border-radius: 10px; text-align: center; }
          .password-display { font-family: 'Courier New', monospace; font-size: 18px; color: #4B7F3F; font-weight: bold; background: white; padding: 15px; border-radius: 8px; border: 1px solid #ddd; margin: 15px 0; letter-spacing: 1px; }
          .steps { background: #fff; border-radius: 10px; overflow: hidden; margin: 30px 0; }
          .step { padding: 20px; border-bottom: 1px solid #f0f0f0; display: flex; align-items: flex-start; }
          .step:last-child { border-bottom: none; }
          .step-number { background: #4B7F3F; color: white; border-radius: 50%; width: 30px; height: 30px; display: flex; align-items: center; justify-content: center; font-weight: bold; margin-right: 20px; flex-shrink: 0; }
          .step-content h3 { margin: 0 0 8px 0; color: #2c3e50; }
          .step-content p { margin: 0; color: #666; }
          .button { display: inline-block; background: linear-gradient(135deg, #4B7F3F, #94BC45); color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; margin: 20px 0; font-weight: 600; text-align: center; transition: transform 0.2s; box-shadow: 0 4px 15px rgba(75, 127, 63, 0.3); }
          .button:hover { transform: translateY(-2px); }
          .footer { text-align: center; margin-top: 40px; padding: 30px; border-top: 2px solid #f0f0f0; color: #666; font-size: 14px; background: #f8f9fa; }
          .features { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 30px 0; }
          .feature { text-align: center; padding: 20px; background: #f8f9fa; border-radius: 10px; }
          .feature-icon { font-size: 40px; margin-bottom: 10px; }
          .security-note { background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 20px; border-radius: 10px; margin: 25px 0; }
          .security-note strong { color: #856404; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="header-content">
              <h1>🏔️ HikeFue5</h1>
              <p class="subtitle">Event Organizer Platform</p>
            </div>
          </div>
          
          <div class="content">
            <div class="welcome-box">
              <h2 style="color: #4B7F3F; margin-top: 0;">Welcome to the HikeFue5 Organizer Community!</h2>
              <p><strong>Congratulations ${organizerName}!</strong> Your organizer application${organizationName ? ` for ${organizationName}` : ''} has been approved. You can now create and manage hiking events on our platform.</p>
            </div>

            <div class="credentials-box">
              <h3 style="color: #4B7F3F; margin-top: 0;">🎉 Your Account is Ready!</h3>
              <p><strong>Email:</strong> ${organizerEmail}</p>
              <p><strong>Login Status:</strong> <span style="color: #4B7F3F; font-weight: bold;">APPROVED ✓</span></p>
              <div class="security-note">
                <strong>🔐 Login Information:</strong> Use the email and password you provided during registration to access your dashboard.
              </div>
            </div>

            <h3 style="color: #4B7F3F;">🚀 Getting Started</h3>
            <div class="steps">
              <div class="step">
                <div class="step-number">1</div>
                <div class="step-content">
                  <h3>Access Your Dashboard</h3>
                  <p>Visit the organizer portal and log in with your credentials above.</p>
                </div>
              </div>
              <div class="step">
                <div class="step-number">2</div>
                <div class="step-content">
                  <h3>Log In to Your Account</h3>
                  <p>Use your registration email and password to access your organizer dashboard.</p>
                </div>
              </div>
              <div class="step">
                <div class="step-number">3</div>
                <div class="step-content">
                  <h3>Complete Your Profile</h3>
                  <p>Add your company logo, description, and contact information.</p>
                </div>
              </div>
              <div class="step">
                <div class="step-number">4</div>
                <div class="step-content">
                  <h3>Create Your First Event</h3>
                  <p>Start organizing amazing hiking experiences for the community!</p>
                </div>
              </div>
            </div>

            <div class="features">
              <div class="feature">
                <div class="feature-icon">📊</div>
                <h4>Analytics Dashboard</h4>
                <p>Track your events' performance and participant engagement</p>
              </div>
              <div class="feature">
                <div class="feature-icon">💬</div>
                <h4>Communication Tools</h4>
                <p>Chat with participants and send event updates</p>
              </div>
            </div>

            <div style="text-align: center;">
              <a href="https://hikefue5-8f6ae.firebaseapp.com/organizer/login" class="button">
                🚀 Access Organizer Dashboard
              </a>
            </div>

            <p style="margin-top: 30px;">If you have any questions or need assistance getting started, our support team is here to help. We're excited to see the amazing events you'll create!</p>

            <p><strong>Welcome to the team!</strong><br>
            The HikeFue5 Team 🏔️</p>
          </div>
          
          <div class="footer">
            <p><strong>Need Help?</strong></p>
            <p>📧 Email: support@hikefue5.com</p>
            <p>📞 Phone: +60 12-345-6789</p>
            <p style="margin-top: 20px; opacity: 0.7;">This is an automated message from HikeFue5. Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    `,
    text: `🎉 Welcome to HikeFue5 - Your Organizer Account is Approved!

Dear ${organizerName},

Congratulations! Your organizer application${organizationName ? ` for ${organizationName}` : ''} has been approved. You can now create and manage hiking events on our platform.

Your Account Information:
Email: ${organizerEmail}
Login Status: APPROVED ✓

🔐 LOGIN INFORMATION: Use the email and password you provided during registration to access your dashboard.

Getting Started:
1. Access Your Dashboard - Visit the organizer portal and log in with your registration credentials
2. Log In to Your Account - Use your registration email and password to access your organizer dashboard
3. Complete Your Profile - Add your company logo, description, and contact information
4. Create Your First Event - Start organizing amazing hiking experiences for the community!

Features Available:
📊 Analytics Dashboard - Track your events' performance and participant engagement
💬 Communication Tools - Chat with participants and send event updates

Access Organizer Dashboard: https://hikefue5-8f6ae.firebaseapp.com/organizer/login

If you have any questions or need assistance getting started, our support team is here to help. We're excited to see the amazing events you'll create!

Welcome to the team!
The HikeFue5 Team 🏔️

Need Help?
📧 Email: support@hikefue5.com
📞 Phone: +60 12-345-6789

This is an automated message from HikeFue5. Please do not reply to this email.`
  };

  try {
    console.log(`Attempting to send approval email to: ${organizerEmail}`);
    console.log(`From: hikefue@gmail.com`);
    console.log(`Subject: ${msg.subject}`);
    
    await sgMail.send(msg);
    console.log(`Approval email sent successfully to ${organizerEmail}`);
    return { success: true, message: 'Approval email sent successfully' };
  } catch (error) {
    console.error('Error sending approval email:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));
    
    // Return the specific error message for debugging
    const errorMessage = (error as any).response?.body?.errors?.[0]?.message || (error as any).message || 'Unknown error';
    throw new functions.https.HttpsError('internal', `Failed to send email: ${errorMessage}`);
  }
});

// Function to send organizer rejection email
export const sendOrganizerRejectionEmail = functions.https.onCall(async (data, context) => {
  // Verify that the request is from an authenticated admin
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated to send emails');
  }

  // Verify admin role
  const adminDoc = await admin.firestore().collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Must be an admin to send emails');
  }

  const { organizerEmail, organizerName, organizationName, rejectionReason } = data;

  if (!organizerEmail || !organizerName || !rejectionReason) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  if (!sendGridApiKey) {
    console.error('SendGrid API key not configured');
    throw new functions.https.HttpsError('failed-precondition', 'Email service not configured');
  }

  const msg = {
    to: organizerEmail,
    from: 'hikefue@gmail.com', // Your verified SendGrid sender email
    subject: 'Organizer Application Status - HikeFue5',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Application Status Update</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #4B7F3F, #94BC45); color: white; padding: 30px 20px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: white; padding: 30px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 10px 10px; }
          .rejection-box { background: #fee; border-left: 4px solid #dc3545; padding: 20px; margin: 20px 0; border-radius: 5px; }
          .footer { text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; color: #666; font-size: 14px; }
          .button { display: inline-block; background: #4B7F3F; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>HikeFue5</h1>
          <h2>Organizer Application Update</h2>
        </div>
        <div class="content">
          <p>Dear ${organizerName},</p>
          
          <p>Thank you for your interest in becoming an organizer with HikeFue5${organizationName ? ` and for submitting your application on behalf of ${organizationName}` : ''}.</p>
          
          <p>After careful review of your application, we regret to inform you that we cannot approve your organizer account at this time.</p>
          
          <div class="rejection-box">
            <h3 style="color: #dc3545; margin-top: 0;">Reason for Rejection:</h3>
            <p style="margin-bottom: 0;">${rejectionReason}</p>
          </div>
          
          <p>We appreciate the time and effort you put into your application. If you believe this decision was made in error or if you would like to address the concerns mentioned above, please feel free to reach out to our support team.</p>
          
          <p>You may also reapply in the future once any issues have been resolved.</p>
          
          <p>Thank you for your understanding, and we wish you the best in your future endeavors.</p>
          
          <p>Best regards,<br>
          The HikeFue5 Team</p>
          
          <a href="mailto:support@hikefue5.com" class="button">Contact Support</a>
        </div>
        <div class="footer">
          <p>This is an automated message from HikeFue5. Please do not reply to this email.</p>
          <p>If you have questions, contact us at support@hikefue5.com</p>
        </div>
      </body>
      </html>
    `,
    text: `Dear ${organizerName},

Thank you for your interest in becoming an organizer with HikeFue5${organizationName ? ` and for submitting your application on behalf of ${organizationName}` : ''}.

After careful review of your application, we regret to inform you that we cannot approve your organizer account at this time.

Reason for Rejection:
${rejectionReason}

We appreciate the time and effort you put into your application. If you believe this decision was made in error or if you would like to address the concerns mentioned above, please feel free to reach out to our support team.

You may also reapply in the future once any issues have been resolved.

Thank you for your understanding, and we wish you the best in your future endeavors.

Best regards,
The HikeFue5 Team

Contact Support: support@hikefue5.com

This is an automated message from HikeFue5. Please do not reply to this email.`
  };

  try {
    console.log(`Attempting to send rejection email to: ${organizerEmail}`);
    console.log(`From: hikefue@gmail.com`);
    console.log(`Subject: ${msg.subject}`);
    
    await sgMail.send(msg);
    console.log(`Rejection email sent successfully to ${organizerEmail}`);
    return { success: true, message: 'Rejection email sent successfully' };
  } catch (error) {
    console.error('Error sending rejection email:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));
    
    // Return the specific error message for debugging
    const errorMessage = (error as any).response?.body?.errors?.[0]?.message || (error as any).message || 'Unknown error';
    throw new functions.https.HttpsError('internal', `Failed to send email: ${errorMessage}`);
  }
});