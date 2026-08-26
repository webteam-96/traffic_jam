using System.Security.Cryptography;
using System.Text;

namespace TrafficJam.Api.Modules.Auth;

/// <summary>
/// SHA-256 hash of an E.164 phone number for <see cref="Data.Entities.User.PhoneHash"/>
/// — we key users by phone without ever storing the number itself.
/// </summary>
public static class PhoneHasher
{
    public static string Hash(string e164PhoneNumber)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(e164PhoneNumber));
        return Convert.ToHexStringLower(bytes);
    }
}
