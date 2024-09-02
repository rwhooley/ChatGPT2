const functions = require('firebase-functions');
const stripe = require('stripe')(functions.config().stripe.secret_key);

exports.stripeCreatePaymentIntent = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to create a payment intent.');
    }

    const { amount } = data;

    if (!amount || amount <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Amount must be a positive number.');
    }

    try {
        const paymentIntent = await stripe.paymentIntents.create({
            amount: amount,
            currency: 'usd',
        });

        return {
            clientSecret: paymentIntent.client_secret,
        };
    } catch (error) {
        console.error('Error creating PaymentIntent:', error);
        throw new functions.https.HttpsError('internal', 'Unable to create PaymentIntent');
    }
});
