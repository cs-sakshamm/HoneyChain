/**
 * Single Firebase Web SDK initialization for HoneyChain.
 *
 * Configuration comes from Vite env vars (VITE_FIREBASE_*). The fallbacks
 * mirror the public client identifiers already shipped in
 * mobile_app/lib/firebase_options.dart — these are not secrets.
 */
import { initializeApp, getApps, getApp, type FirebaseApp } from 'firebase/app';
import { getAuth, useDeviceLanguage, type Auth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY ?? 'AIzaSyDJFOj7F7I7-NIqclH4JLBhDZzvqb9_uIU',
  appId: import.meta.env.VITE_FIREBASE_APP_ID ?? '1:314717495726:web:d71b1db1dd5c01dbc0a83f',
  messagingSenderId: import.meta.env.VITE_FIREBASE_SENDER_ID ?? '314717495726',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID ?? 'honeychain-40065',
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN ?? 'honeychain-40065.firebaseapp.com',
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET ?? 'honeychain-40065.firebasestorage.app',
};

/** Returns the single app instance (never initializes twice). */
export function getFirebaseApp(): FirebaseApp {
  return getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
}

/** Returns the single Auth instance. Uses the browser's language for SMS templates. */
export function getFirebaseAuth(): Auth {
  const auth = getAuth(getFirebaseApp());
  useDeviceLanguage(auth);
  return auth;
}

export const FIREBASE_PROJECT_ID = firebaseConfig.projectId;
