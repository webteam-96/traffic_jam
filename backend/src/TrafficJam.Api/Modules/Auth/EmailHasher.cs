using System.Security.Cryptography;
using System.Text;

namespace TrafficJam.Api.Modules.Auth;

/// <summary>
/// Normalises and hashes an email address, the counterpart to
/// <see cref="PhoneHasher"/>.
///
/// Normalisation matters more here than for phone numbers: "Jay@Example.COM "
/// and "jay@example.com" are the same mailbox, and without trimming and
/// lower-casing they would hash differently and quietly create two accounts
/// for one person.
/// </summary>
public static class EmailHasher
{
    public static string Normalise(string email) => email.Trim().ToLowerInvariant();

    public static string Hash(string email)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(Normalise(email)));
        return Convert.ToHexStringLower(bytes);
    }

    /// <summary>
    /// Deliberately permissive: enough to catch a typo or an empty box, not an
    /// attempt to decide what RFC 5322 allows. The real test of an address is
    /// whether the code reaches it.
    /// </summary>
    public static bool LooksValid(string email)
    {
        var value = Normalise(email);
        if (value.Length is < 5 or > 254) return false;

        var at = value.IndexOf('@');
        if (at <= 0 || at != value.LastIndexOf('@') || at == value.Length - 1) return false;

        var domain = value[(at + 1)..];
        return domain.Contains('.') && !domain.StartsWith('.') && !domain.EndsWith('.');
    }
}
