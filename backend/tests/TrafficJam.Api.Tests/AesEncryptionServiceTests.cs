using Microsoft.Extensions.Configuration;
using TrafficJam.Api.Infrastructure;
using Xunit;

namespace TrafficJam.Api.Tests;

public class AesEncryptionServiceTests
{
    private static AesEncryptionService BuildService(string base64Key)
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Encryption:Key"] = base64Key,
            })
            .Build();
        return new AesEncryptionService(config);
    }

    [Fact]
    public void RoundTrip_ReturnsOriginalPlaintext()
    {
        var service = BuildService("tN8PuoSgs8BmWh7UWKeTVqGWmYR10rg822Eq+iR1x9s=");

        var ciphertext = service.Encrypt("24 October 1988");
        var plaintext = service.Decrypt(ciphertext);

        Assert.Equal("24 October 1988", plaintext);
    }

    [Fact]
    public void Encrypt_DoesNotReturnThePlaintext()
    {
        var service = BuildService("tN8PuoSgs8BmWh7UWKeTVqGWmYR10rg822Eq+iR1x9s=");

        var ciphertext = service.Encrypt("Mumbai, Maharashtra, India");

        Assert.DoesNotContain("Mumbai", ciphertext);
    }

    [Fact]
    public void Encrypt_IsNotDeterministic_DifferentCiphertextEachTime()
    {
        var service = BuildService("tN8PuoSgs8BmWh7UWKeTVqGWmYR10rg822Eq+iR1x9s=");

        var first = service.Encrypt("same value");
        var second = service.Encrypt("same value");

        Assert.NotEqual(first, second); // random nonce per call — prevents pattern analysis
    }

    [Fact]
    public void Decrypt_WithWrongKey_Throws()
    {
        var encryptor = BuildService("tN8PuoSgs8BmWh7UWKeTVqGWmYR10rg822Eq+iR1x9s=");
        var wrongKeyService = BuildService("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=");

        var ciphertext = encryptor.Encrypt("sensitive birth data");

        Assert.ThrowsAny<Exception>(() => wrongKeyService.Decrypt(ciphertext));
    }

    [Fact]
    public void Constructor_WithMissingKey_ThrowsClearError()
    {
        var config = new ConfigurationBuilder().Build();

        var ex = Assert.Throws<InvalidOperationException>(() => new AesEncryptionService(config));
        Assert.Contains("Encryption:Key", ex.Message);
    }
}
