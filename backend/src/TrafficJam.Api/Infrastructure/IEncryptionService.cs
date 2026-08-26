namespace TrafficJam.Api.Infrastructure;

/// <summary>
/// Encrypts/decrypts sensitive personal data before it touches the database.
/// Used for every field in <see cref="Data.Entities.BirthData"/> — birth
/// data is sensitive personal data under India's DPDP Act 2023 and must be
/// AES-256 encrypted at rest (see BACKEND_REQUIREMENTS.md).
/// </summary>
public interface IEncryptionService
{
    string Encrypt(string plaintext);
    string Decrypt(string ciphertext);
}
