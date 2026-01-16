const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// Initialize Firebase Admin with service account
// You must download a service account key from firebase console and save it as serviceAccountKey.json in this directory
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const args = process.argv.slice(2);
const email = args[0];

if (!email) {
    console.error("Please provide an email address.");
    console.error("Usage: node setAdmin.js <email>");
    process.exit(1);
}

async function grantAdminRole(email) {
    try {
        const user = await admin.auth().getUserByEmail(email);

        if (user.customClaims && user.customClaims.admin === true) {
            console.log(`${email} is already an admin.`);
            return;
        }

        await admin.auth().setCustomUserClaims(user.uid, {
            admin: true
        });

        console.log(`Successfully granted admin privileges to ${email}`);
        console.log("Ask the user to sign out and sign in again for the change to take effect.");

    } catch (error) {
        if (error.code === 'auth/user-not-found') {
            console.error(`User with email ${email} not found.`);
        } else {
            console.error("Error fetching user data:", error);
        }
        process.exit(1);
    }
}

grantAdminRole(email);
