using System.Security.Cryptography;

namespace TrafficJam.Api.Infrastructure;

/// <summary>
/// AES-256-GCM (authenticated encryption) using a key supplied via
/// configuration (<c>Encryption:Key</c> — a base64-encoded 32-byte key).
/// Storage layout: base64( nonce[12] || tag[16] || ciphertext ).
/// </summary>
public class AesEncryptionService : IEncryptionService
{
    private const int NonceSizeBytes = 12;
    private const int TagSizeBytes = 16;

    private readonly byte[] _key;

    public AesEncryptionService(IConfiguration configuration)
    {
        var keyBase64 = configuration["Encryption:Key"]
            ?? throw new InvalidOperationException(
                "Encryption:Key is not configured. Generate one with " +
                "`openssl rand -base64 32` and set it via configuration/secrets " +
                "— never commit a production key.");

        _key = Convert.FromBase64String(keyBase64);
        if (_key.Length != 32)
        {
            throw new InvalidOperationException(
                $"Encryption:Key must decode to exactly 32 bytes (AES-256); got {_key.Length}.");
        }
    }

    public string Encrypt(string plaintext)
    {
        var plaintextBytes = System.Text.Encoding.UTF8.GetBytes(plaintext);
        var nonce = RandomNumberGenerator.GetBytes(NonceSizeBytes);
        var ciphertext = new byte[plaintextBytes.Length];
        var tag = new byte[TagSizeBytes];

        using (var aes = new AesGcm(_key, TagSizeBytes))
        {
            aes.Encrypt(nonce, plaintextBytes, ciphertext, tag);
        }

        var payload = new byte[NonceSizeBytes + TagSizeBytes + ciphertext.Length];
        Buffer.BlockCopy(nonce, 0, payload, 0, NonceSizeBytes);
        Buffer.BlockCopy(tag, 0, payload, NonceSizeBytes, TagSizeBytes);
        Buffer.BlockCopy(ciphertext, 0, payload, NonceSizeBytes + TagSizeBytes, ciphertext.Length);

        return Convert.ToBase64String(payload);
    }

    public string Decrypt(string ciphertext)
    {
        var payload = Convert.FromBase64String(ciphertext);
        var nonce = payload[..NonceSizeBytes];
        var tag = payload[NonceSizeBytes..(NonceSizeBytes + TagSizeBytes)];
        var cipherBytes = payload[(NonceSizeBytes + TagSizeBytes)..];
        var plaintextBytes = new byte[cipherBytes.Length];

        using (var aes = new AesGcm(_key, TagSizeBytes))
        {
            aes.Decrypt(nonce, cipherBytes, tag, plaintextBytes);
        }

        return System.Text.Encoding.UTF8.GetString(plaintextBytes);
    }
}
