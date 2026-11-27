// One-time script: give every Firebase user the custom claim
//   { "role": "authenticated" }
// which Supabase third-party auth needs in order to map the request to the
// `authenticated` role (otherwise RLS policies return zero rows).
//
// Prerequisites:
//   1. Firebase Console -> Project Settings -> Service accounts -> Generate new private key
//   2. Save the downloaded JSON as tools/firebase_claim/service-account.json
//      (this file is git-ignored)
//   3. npm install   (in this folder)
//
// Run:   npm run set-claims
// Re-run whenever you create a new staff account in the Firebase Console.
const admin = require('firebase-admin');
const path = require('path');

const keyPath = path.join(__dirname, 'service-account.json');
let serviceAccount;
try {
  serviceAccount = require(keyPath);
} catch (e) {
  console.error('Missing service-account.json. Download it from the Firebase Console.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

(async () => {
  let nextPageToken;
  let count = 0;
  do {
    const list = await admin.auth().listUsers(1000, nextPageToken);
    await Promise.all(
      list.users.map(async (user) => {
        const claims = { ...(user.customClaims || {}), role: 'authenticated' };
        await admin.auth().setCustomUserClaims(user.uid, claims);
        count++;
        console.log(`Set role=authenticated for ${user.email || user.uid}`);
      }),
    );
    nextPageToken = list.pageToken;
  } while (nextPageToken);
  console.log(`Done. Updated ${count} user(s).`);
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});