const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(functions.config().stripe.secret_key);

admin.initializeApp();

// Helper function to get or create a connected account
async function getOrCreateConnectedAccount(userId) {
  const userRef = admin.firestore().collection('users').doc(userId);
  const userDoc = await userRef.get();
  let accountId = userDoc.data()?.stripeAccountId;

  if (!accountId) {
    const account = await stripe.accounts.create({
      type: 'express',
      capabilities: {
        transfers: { requested: true },
      },
      metadata: { firebaseUserId: userId }
    });

    accountId = account.id;
    await userRef.update({ stripeAccountId: accountId });
  }

  return accountId;
}

// Create Payment Intent (for deposits)
exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
  }

  const { amount } = data;

  if (!amount || amount <= 0) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid amount provided.");
  }

  try {
      const paymentIntent = await stripe.paymentIntents.create({
          amount,
          currency: "usd",
          metadata: { userId: context.auth.uid }
      });

      return { clientSecret: paymentIntent.client_secret };
  } catch (error) {
      console.error("Error creating PaymentIntent:", error);
      throw new functions.https.HttpsError("internal", "Unable to create PaymentIntent");
  }
});

// Initiate withdrawal
exports.initiateStripeWithdrawal = functions.https.onCall(async (data, context) => {
  console.log("Withdrawal function called", { data, userId: context.auth?.uid });

  if (!context.auth) {
    console.log("Authentication failed");
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
  }

  const { amount } = data;
  const userId = context.auth.uid;

  if (!amount || amount <= 0) {
    console.log("Invalid amount", amount);
    throw new functions.https.HttpsError("invalid-argument", "Invalid amount provided.");
  }

  try {
    const userRef = admin.firestore().collection('users').doc(userId);
    const userDoc = await userRef.get();
    console.log("User document retrieved", userDoc.exists);

    const accountId = userDoc.data()?.stripeAccountId;
    console.log("Stripe account ID", accountId);

    if (!accountId) {
      console.log("No Stripe account found for user");
      throw new functions.https.HttpsError("failed-precondition", "User has no connected Stripe account.");
    }

    // Check user's balance in Firestore
    const balance = userDoc.data()?.totalBalance || 0;
    console.log("User's total balance in Firestore:", balance);

    if (balance < amount / 100) {
      console.log("Insufficient funds in Firestore balance.");
      throw new functions.https.HttpsError("failed-precondition", "Insufficient funds.");
    }

    // Create a transfer to the user's Stripe account
    const transfer = await stripe.transfers.create({
      amount,
      currency: 'usd',
      destination: accountId,
    });
    console.log("Transfer created", transfer.id);

    // Update user's balance in Firestore
    await userRef.update({
      totalBalance: admin.firestore.FieldValue.increment(-amount / 100)
    });
    console.log("User balance updated in Firestore");

    return { success: true, transferId: transfer.id };
  } catch (error) {
    console.error("Error processing withdrawal:", error);
    throw new functions.https.HttpsError("internal", "Failed to process withdrawal: " + error.message);
  }
});

// Webhook handler
// Webhook handler
// Webhook handler
// Webhook handler
exports.handleStripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, functions.config().stripe.webhook_secret);
  } catch (err) {
      console.error('Webhook signature verification failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'payment_intent.succeeded') {
      const paymentIntent = event.data.object;
      const userId = paymentIntent.metadata.userId;
      const amount = paymentIntent.amount / 100; // Convert amount from cents to dollars

      if (userId) {
          const userRef = admin.firestore().collection('users').doc(userId);

          await admin.firestore().runTransaction(async (transaction) => {
              const userDoc = await transaction.get(userRef);

              let currentTotalBalance = 0;
              let currentInvestedBalance = 0;
              let currentFreeBalance = 0;

              if (userDoc.exists) {
                  currentTotalBalance = userDoc.data().totalBalance || 0;
                  currentInvestedBalance = userDoc.data().investedBalance || 0;
                  currentFreeBalance = userDoc.data().freeBalance || (currentTotalBalance - currentInvestedBalance);
              } else {
                  // Initialize balances for a new user
                  currentInvestedBalance = 0;
                  currentFreeBalance = amount;  // First deposit goes into free balance
              }

              const newTotalBalance = currentTotalBalance + amount;
              const newFreeBalance = newTotalBalance - currentInvestedBalance;

              // Update Firestore within the transaction
              transaction.set(userRef, {
                  totalBalance: newTotalBalance,
                  investedBalance: currentInvestedBalance, // Ensure investedBalance is initialized
                  freeBalance: newFreeBalance,             // Ensure freeBalance is initialized
              }, { merge: true });
          });

          console.log(`Successfully updated balances for user ${userId}`);
      }
  }

  res.json({ received: true });
});




// Check and create Stripe account
exports.checkAndCreateStripeAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const userId = context.auth.uid;
  const accountId = await getOrCreateConnectedAccount(userId);

  const account = await stripe.accounts.retrieve(accountId);
  if (account.payouts_enabled) {
    return { status: 'active', accountId: accountId };
  } else {
    const accountLink = await createAccountLink(accountId);
    return { status: 'pending', accountId: accountId, accountLink: accountLink.url };
  }
});

exports.createStripeConnectedAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const userId = context.auth.uid;

  try {
      const account = await stripe.accounts.create({
          type: 'express',
          capabilities: {
              transfers: { requested: true },
          },
          metadata: { firebaseUserId: userId }
      });

      await admin.firestore().collection('users').doc(userId).update({
          stripeAccountId: account.id
      });

      const accountLink = await createAccountLink(account.id);

      return { 
          status: 'created',
          accountId: account.id,
          onboardingUrl: accountLink.url
      };
  } catch (error) {
      console.error("Error creating Stripe Connected Account:", error);
      throw new functions.https.HttpsError('internal', 'Failed to create Stripe Connected Account');
  }
});

async function createAccountLink(accountId) {
  return await stripe.accountLinks.create({
      account: accountId,
      refresh_url: `https://DemoApp.com/refresh-account-link`,
      return_url: `https://DemoApp.com/return-from-stripe-onboarding`,
      type: 'account_onboarding',
  });
}

// Check balance
exports.checkBalance = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const userId = context.auth.uid;
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const balance = userDoc.data()?.totalBalance || 0;

  return { balance };
});

// Check Stripe account status
exports.checkStripeAccountStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const userId = context.auth.uid;

  try {
      const userRef = admin.firestore().collection('users').doc(userId);
      const userDoc = await userRef.get();
      const accountId = userDoc.data()?.stripeAccountId;

      if (!accountId) {
          // No Stripe account exists, return status for frontend to show onboarding button
          return { status: 'not_created' };
      }

      const account = await stripe.accounts.retrieve(accountId);
      
      if (account.payouts_enabled) {
          return { status: 'active', accountId: accountId };
      } else {
          // Account exists but onboarding is not complete
          const accountLink = await createAccountLink(accountId);
          return { 
              status: 'pending', 
              accountId: accountId, 
              onboardingUrl: accountLink.url 
          };
      }
  } catch (error) {
      console.error("Error checking Stripe account status:", error);
      throw new functions.https.HttpsError('internal', 'Failed to check Stripe account status');
  }
});

// Get Stripe external account info
exports.getStripeExternalAccountInfo = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    console.log('Error: User not authenticated');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const userId = context.auth.uid;
  console.log(`Fetching external account info for user: ${userId}`);
  
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log(`User document not found for userId: ${userId}`);
      throw new functions.https.HttpsError('not-found', 'User document not found.');
    }

    const stripeAccountId = userDoc.data().stripeAccountId;
    console.log(`Stripe Account ID for user: ${stripeAccountId}`);

    if (!stripeAccountId) {
      console.log('Stripe account ID not found for user');
      throw new functions.https.HttpsError('not-found', 'Stripe account not found for this user.');
    }

    // Fetch external accounts directly from Stripe
    const externalAccounts = await stripe.accounts.listExternalAccounts(
      stripeAccountId,
      {object: 'bank_account', limit: 1}
    );

    console.log(`Number of external accounts: ${externalAccounts.data.length}`);

    if (externalAccounts.data.length === 0) {
      console.log('No external accounts found');
      return { last4: null };
    }

    // Get the first (and likely only) bank account
    const bankAccount = externalAccounts.data[0];
    console.log(`Bank account last4: ${bankAccount.last4}`);
    return { last4: bankAccount.last4 };

  } catch (error) {
    console.error('Error fetching external account info:', error);
    throw new functions.https.HttpsError('internal', 'Unable to fetch external account information: ' + error.message);
  }
});

exports.confirmPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { amount } = data;
  const userId = context.auth.uid;

  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid amount provided.');
  }

  try {
    // Fetch the user's document
    const userRef = admin.firestore().collection('users').doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User document not found.');
    }

    // Update the user's balance
    await userRef.update({
      totalBalance: admin.firestore.FieldValue.increment(amount)
    });

    console.log(`Successfully updated balance for user ${userId} with amount ${amount}`);
    return { confirmed: true };
  } catch (error) {
    console.error('Error confirming payment:', error);
    throw new functions.https.HttpsError('internal', 'Failed to confirm payment: ' + error.message);
  }
});

exports.syncBalancesOnTotalBalanceUpdate = functions.firestore
    .document('users/{userId}')
    .onUpdate(async (change, context) => {
        const userId = context.params.userId;
        const newData = change.after.data();
        const previousData = change.before.data();

        // Check if totalBalance field has been added or changed
        if (newData.totalBalance !== previousData.totalBalance) {
            let totalBalance = newData.totalBalance || 0;
            let investedBalance = newData.investedBalance || 0;
            let freeBalance = newData.freeBalance || 0;

            // If freeBalance and investedBalance are not present, initialize them
            if (!newData.hasOwnProperty('investedBalance')) {
                investedBalance = 0;
            }

            if (!newData.hasOwnProperty('freeBalance')) {
                freeBalance = totalBalance - investedBalance;
            } else {
                // Recalculate freeBalance if totalBalance has changed
                freeBalance = totalBalance - investedBalance;
            }

            // Update the Firestore document with calculated balances
            await admin.firestore().collection('users').doc(userId).update({
                investedBalance: investedBalance,
                freeBalance: freeBalance,
            });

            console.log(`Balances updated for user ${userId}`);
        }
    });