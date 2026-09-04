using System.Security.Cryptography;
using System.Text;

namespace TrafficJam.Api.Modules.Auth;

/// <summary>
/// SHA-256 hash of an E.164 phone number for <see cref="Data.Entities.User.PhoneHash"/>
/// — a stable, queryable key for finding a user by their number. The number
/// itself is stored separately and encrypted (<see cref="Data.Entities.User.Phone"/>);
/// this hash exists because that ciphertext can't be matched in a WHERE clause.
/// </summary>
public static class PhoneHasher
{
    public static string Hash(string e164PhoneNumber)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(e164PhoneNumber));
        return Convert.ToHexStringLower(bytes);
    }
}
