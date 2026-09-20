/**
 * Session state for the HoneyChain web verifier, backed by the single
 * Firebase Auth instance. Firebase web persists the session in IndexedDB by
 * default, so a signed-in user stays authenticated across reloads.
 */
import { useEffect, useState } from 'react';
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { getFirebaseAuth } from '../auth/firebase';

export function useFirebaseUser(): { user: User | null; loading: boolean } {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const auth = getFirebaseAuth();
    const unsubscribe = onAuthStateChanged(auth, (u) => {
      setUser(u);
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  return { user, loading };
}

export async function signOutFirebase(): Promise<void> {
  try {
    await signOut(getFirebaseAuth());
  } catch {
    // session already gone
  }
}
