namespace TrafficJam.Api.Data.Entities;

/// <summary>
/// One issued email sign-in code.
///
/// The code itself is never stored — only a hash, the same reasoning as a
/// password: anyone reading this table (a backup, a support query, a leak)
/// must not be able to sign in as someone else. Verification hashes what the
/// caller typed and compares.
///
/// Rows are kept after use rather than deleted so a code can't be replayed and
/// so there is a record of when sign-in was attempted; a periodic cleanup of
/// expired rows is a later concern, not a correctness one.
/// </summary>
public class EmailOtp
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>
    /// SHA-256 of the normalised address — the queryable key, for the same
    /// reason <see cref="User.PhoneHash"/> exists: <see cref="Email"/> is
    /// encrypted at rest and its ciphertext can't be matched in a WHERE.
    /// </summary>
    public required string EmailHash { get; set; }

    /// <summary>The readable address, AES-encrypted at rest. Kept so support
    /// can see which address a code went to without decrypting a whole table.</summary>
    public required string Email { get; set; }

    /// <summary>SHA-256 of the six-digit code, salted with the email hash so
    /// the same code issued to two people produces different rows and a
    /// precomputed table of a million digests is useless.</summary>
    public required string CodeHash { get; set; }

    public DateTime ExpiresAt { get; set; }

    /// <summary>Set the moment a code is accepted, which is what makes it
    /// single-use. A consumed code is never valid again even before expiry.</summary>
    public DateTime? ConsumedAt { get; set; }

    /// <summary>Wrong guesses so far. A code is burned after a handful, so six
    /// digits can't be brute-forced inside its ten-minute life.</summary>
    public int AttemptCount { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
