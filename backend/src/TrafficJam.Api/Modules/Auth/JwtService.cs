using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Auth;

public class JwtService : IJwtService
{
    private readonly SymmetricSecurityKey _signingKey;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _accessTokenMinutes;
    private readonly int _refreshTokenDays;
    private readonly JsonWebTokenHandler _handler = new();

    public JwtService(IConfiguration configuration)
    {
        var keyBase64 = configuration["Jwt:SigningKey"]
            ?? throw new InvalidOperationException(
                "Jwt:SigningKey is not configured. Generate one with " +
                "`openssl rand -base64 32` — never commit a production key.");

        _signingKey = new SymmetricSecurityKey(Convert.FromBase64String(keyBase64));
        _issuer = configuration["Jwt:Issuer"] ?? "trafficjam.life";
        _audience = configuration["Jwt:Audience"] ?? "trafficjam.app";
        _accessTokenMinutes = int.TryParse(configuration["Jwt:AccessTokenMinutes"], out var m) ? m : 15;
        _refreshTokenDays = int.TryParse(configuration["Jwt:RefreshTokenDays"], out var d) ? d : 30;
    }

    public string IssueAccessToken(User user)
    {
        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _issuer,
            Audience = _audience,
            Subject = new ClaimsIdentity([
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            ]),
            Expires = DateTime.UtcNow.AddMinutes(_accessTokenMinutes),
            SigningCredentials = new SigningCredentials(_signingKey, SecurityAlgorithms.HmacSha256),
        };

        return _handler.CreateToken(descriptor);
    }

    public RefreshTokenIssued IssueRefreshToken()
    {
        var raw = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
        return new RefreshTokenIssued(raw, HashRefreshToken(raw), DateTime.UtcNow.AddDays(_refreshTokenDays));
    }

    public string HashRefreshToken(string rawToken) =>
        Convert.ToHexStringLower(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(rawToken)));
}
