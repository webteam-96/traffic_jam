namespace TrafficJam.Api.Modules.Auth;

/// <summary>
/// Verifies a Firebase ID token and extracts the identity claims we need.
/// This is the trust boundary between Firebase's phone-OTP identity and our
/// own user records — see API_REQUIREMENTS.md §1.2.
/// </summary>
public interface IFirebaseTokenVerifier
{
    Task<FirebaseVerifiedToken> VerifyAsync(string idToken, CancellationToken cancellationToken = default);
}

public record FirebaseVerifiedToken(string Uid, string PhoneNumber);

/// <summary>Thrown when a Firebase ID token fails verification (expired, malformed, wrong project, etc.).</summary>
public class InvalidFirebaseTokenException(string message) : Exception(message);

/// <summary>Thrown when no Firebase project is configured yet — a deployment/config problem, not a bad token.</summary>
public class FirebaseNotConfiguredException(string message) : Exception(message);
