using System.Security.Cryptography;

namespace TrafficJam.Api.Modules.Admin;

/// <summary>
/// PBKDF2-SHA256 password hashing for AdminUser — hand-rolled on stdlib
/// crypto (Rfc2898DeriveBytes) rather than pulling in ASP.NET Core Identity's
/// full framework for one table, the same "small dedicated crypto helper"
/// pattern PhoneHasher/AesEncryptionService already use elsewhere. Stored
/// format: "{iterations}.{base64 salt}.{base64 hash}" — self-describing, so
/// the iteration count can be raised later without breaking existing hashes.
/// </summary>
public static class AdminPasswordHasher
{
    private const int Iterations = 210_000; // OWASP 2023 minimum recommendation for PBKDF2-SHA256
    private const int SaltSize = 16;
    private const int HashSize = 32;

    public static string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, HashSize);
        return $"{Iterations}.{Convert.ToBase64String(salt)}.{Convert.ToBase64String(hash)}";
    }

    public static bool Verify(string password, string stored)
    {
        var parts = stored.Split('.');
        if (parts.Length != 3 || !int.TryParse(parts[0], out var iterations)) return false;

        var salt = Convert.FromBase64String(parts[1]);
        var expected = Convert.FromBase64String(parts[2]);
        var actual = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }
}
