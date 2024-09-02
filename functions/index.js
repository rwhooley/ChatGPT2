const functions = require('firebase-functions');
const admin = require('firebase-admin');
const stripe = require('stripe')(functions.config().stripe.secret_key);

admin.initializeApp();

exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  console.log('createPaymentIntent function called');
  console.log('Received data:', JSON.stringify(data));
  console.log('Auth context:', JSON.stringify(context.auth));

  if (!context.auth) {
    console.error('No auth context');
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { amount } = data;

  if (!amount) {
    console.error('Missing required fields');
    throw new functions.https.HttpsError('invalid-argument', 'The function must be called with an "amount" argument.');
  }

  try {
    const user = await admin.auth().getUser(context.auth.uid);
    console.log('User verified:', user.uid);

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: 'usd',
    });

    console.log('PaymentIntent created successfully');
    return { clientSecret: paymentIntent.client_secret };
  } catch (error) {
    console.error('Error in createPaymentIntent:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});