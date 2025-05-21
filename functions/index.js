const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configure your SMTP transporter
// Replace with your SMTP server details and credentials
const transporter = nodemailer.createTransport({
  host: "smtp.example.com",
  port: 587,
  secure: false, // true for 465, false for other ports
  auth: {
    user: "your-email@example.com",
    pass: "your-email-password",
  },
});

// Cloud Function triggered on new user creation in Firebase Auth
exports.sendWelcomeEmail = functions.auth.user().onCreate(async (user) => {
  // Retrieve additional user info from Firestore if needed
  let userData = {};
  try {
    // eslint-disable-next-line max-len
    const userDoc = await admin.firestore().collection("admins").doc(user.uid).get();
    if (userDoc.exists) {
      userData = userDoc.data();
    }
  } catch (error) {
    console.error("Error fetching user data:", error);
  }

  const email = user.email;
  const displayName =
    user.displayName ||
    // eslint-disable-next-line max-len
    (userData.firstName ? `${userData.firstName} ${userData.lastName || ""}`.trim() : "");

  const mailOptions = {
    from: "\"Your App Name\" <your-email@example.com>", // sender address
    to: email,
    subject: "Welcome to Our App! Your Login Information",
    text:
      "Hello " +
      displayName +
      ",\n\nYour account has been created with the email: " +
      email +
      // eslint-disable-next-line max-len
      ".\n\nIf you forgot your password, you can reset it using the password reset feature.\n\nWelcome aboard!",
    html:
      "<p>Hello " +
      displayName +
      ",</p>" +
      "<p>Your account has been created with the email: <strong>" +
      email +
      "</strong>.</p>" +
      // eslint-disable-next-line max-len
      "<p>If you forgot your password, you can reset it using the password reset feature.</p>" +
      "<p>Welcome aboard!</p>",
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log("Welcome email with login info sent to:", email);
  } catch (error) {
    console.error("Error sending welcome email:", error);
  }
});
