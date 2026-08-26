using TrafficJam.Api.Modules.Auth;

namespace TrafficJam.Api.Tests;

/// <summary>
/// Stands in for the real Firebase Admin SDK in tests, so the Auth flow can
/// be proven end-to-end without a real Firebase project. Accepts any token
/// of the form "uid:phoneNumber" — never used outside the test project.
/// </summary>
public class FakeFirebaseTokenVerifier : IFirebaseTokenVerifier
{
    public Task<FirebaseVerifiedToken> VerifyAsync(string idToken, CancellationToken cancellationToken = default)
    {
        var parts = idToken.Split(':', 2);
        if (parts.Length != 2)
        {
            throw new InvalidFirebaseTokenException("Fake token must be in the form 'uid:phoneNumber'.");
        }

        return Task.FromResult(new FirebaseVerifiedToken(parts[0], parts[1]));
    }
}
