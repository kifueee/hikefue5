# Admin Account Creation

This directory contains scripts for managing admin accounts in the application.

## Creating an Admin Account

To create a new admin account, follow these steps:

1. First, make sure you have the Firebase configuration values. You can find these in your Firebase Console:
   - Go to Project Settings
   - Scroll down to "Your apps"
   - Find your web app or create a new one
   - Copy the configuration values

2. Open `create_admin.dart` and replace the Firebase configuration values:
   ```dart
   options: const FirebaseOptions(
     apiKey: "YOUR_API_KEY",
     authDomain: "YOUR_AUTH_DOMAIN",
     projectId: "YOUR_PROJECT_ID",
     storageBucket: "YOUR_STORAGE_BUCKET",
     messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
     appId: "YOUR_APP_ID",
   ),
   ```

3. Run the script:
   ```bash
   dart lib/web/scripts/create_admin.dart
   ```

4. Follow the prompts to enter:
   - Admin email address
   - Admin password (minimum 6 characters)

5. The script will:
   - Create a new user in Firebase Authentication
   - Create an admin document in the 'admins' collection
   - Display the created admin's email and user ID

## Security Notes

- Keep the admin credentials secure
- Use a strong password
- Don't share admin access with unauthorized users
- Regularly audit admin accounts
- Consider implementing 2FA for admin accounts

## Troubleshooting

If you encounter any errors:

1. Check your Firebase configuration values
2. Ensure you have the necessary permissions in Firebase
3. Verify that your Firebase project is properly set up
4. Check the Firebase Console for any error messages

## Additional Information

- Admin accounts have full access to the application
- Admins can manage organizers and participants
- Admins can create, update, and delete events
- Admins can manage system settings

For more information about admin privileges, refer to the Firebase security rules in `firestore.rules`. 