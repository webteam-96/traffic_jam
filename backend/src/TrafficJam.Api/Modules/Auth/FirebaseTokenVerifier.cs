using FirebaseAdmin.Auth;

namespace TrafficJam.Api.Modules.Auth;

/// <summary>
/// Real implementation, backed by the Firebase Admin SDK. Requires
/// <c>FirebaseApp.DefaultInstance</c> to have been initialized at startup
/// with a real service account (see Program.cs) — if it wasn't (no
/// Firebase project configured yet), this throws clearly rather than
/// silently accepting unverified tokens.
/// </summary>
public class FirebaseTokenVerifier : IFirebaseTokenVerifier
{
    public async Task<FirebaseVerifiedToken> VerifyAsync(string idToken, CancellationToken cancellationToken = default)
    {
        if (FirebaseAdmin.FirebaseApp.DefaultInstance is null)
        {
            throw new FirebaseNotConfiguredException(
                "Firebase is not configured — set Firebase:CredentialsPath (or " +
                "Firebase:CredentialsJson) to a real service account before /auth/session " +
                "can verify tokens. See backend/README.md.");
        }

        try
        {
            var decoded = await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(idToken, cancellationToken);

            if (!decoded.Claims.TryGetValue("phone_number", out var phoneClaim) || phoneClaim is not string phone)
            {
                throw new InvalidFirebaseTokenException(
                    "Token has no phone_number claim — expected a phone-OTP authenticated token.");
            }

            return new FirebaseVerifiedToken(decoded.Uid, phone);
        }
        catch (FirebaseAuthException ex)
        {
            throw new InvalidFirebaseTokenException($"Firebase token verification failed: {ex.Message}");
        }
    }
}
