using System.Net;
using System.Net.Mail;

namespace TrafficJam.Api.Infrastructure;

public interface IEmailSender
{
    /// <summary>
    /// Sends one message. Throws on failure — the caller decides whether that
    /// should reach the user, and for sign-in codes it must, since a code the
    /// user never receives is worse than an error they can act on.
    /// </summary>
    Task SendAsync(string toAddress, string subject, string body, CancellationToken ct);
}

/// <summary>
/// Plain SMTP, configured from Smtp:* in appsettings.
///
/// Deliberately not a transactional-email provider (SendGrid, SES, Postmark).
/// Those are the right answer at volume — they handle deliverability,
/// reputation, bounces and suppression lists, which a raw SMTP relay does not
/// — but wiring one up is out of scope for now. This is the stopgap: it will
/// deliver reliably enough for a small user base, and swapping it later means
/// writing one more IEmailSender rather than touching any calling code.
///
/// Uses System.Net.Mail rather than adding MailKit. MailKit is the better
/// library and the usual recommendation, but this needs plain
/// username/password SMTP over STARTTLS and nothing more, and avoiding a
/// dependency for a component we intend to replace is the better trade.
/// </summary>
public class SmtpEmailSender(IConfiguration configuration, ILogger<SmtpEmailSender> logger) : IEmailSender
{
    public async Task SendAsync(string toAddress, string subject, string body, CancellationToken ct)
    {
        var host = configuration["Smtp:Host"];
        var fromAddress = configuration["Smtp:FromAddress"];

        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(fromAddress))
        {
            throw new InvalidOperationException(
                "Smtp:Host and Smtp:FromAddress are not configured — see appsettings.");
        }

        var port = configuration.GetValue<int?>("Smtp:Port") ?? 587;
        var username = configuration["Smtp:Username"];
        var password = configuration["Smtp:Password"];

        using var client = new SmtpClient(host, port)
        {
            // STARTTLS on the submission port. A code in a plaintext SMTP
            // session is a code on the wire.
            EnableSsl = configuration.GetValue<bool?>("Smtp:UseSsl") ?? true,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            Timeout = 15_000,
        };

        if (!string.IsNullOrWhiteSpace(username))
        {
            client.Credentials = new NetworkCredential(username, password);
        }

        using var message = new MailMessage
        {
            From = new MailAddress(fromAddress, configuration["Smtp:FromName"] ?? "TrafficJam.Life"),
            Subject = subject,
            Body = body,
            IsBodyHtml = false,
        };
        message.To.Add(toAddress);

        try
        {
            await client.SendMailAsync(message, ct);
        }
        catch (Exception e)
        {
            // The address is not logged: a sign-in code's recipient is exactly
            // the kind of thing that shouldn't end up in a log aggregator.
            logger.LogError(e, "SMTP send failed for subject {Subject}.", subject);
            throw;
        }
    }
}

/// <summary>
/// Stands in when no SMTP host is configured — the same shape as
/// NotConfiguredPaymentGateway. In Development it writes the message to the
/// log so the flow can be exercised end to end without a mail server;
/// anywhere else it throws, because silently not sending a sign-in code would
/// look exactly like a working system to everyone except the person waiting
/// for the email.
/// </summary>
public class LoggingEmailSender(IHostEnvironment environment, ILogger<LoggingEmailSender> logger) : IEmailSender
{
    public Task SendAsync(string toAddress, string subject, string body, CancellationToken ct)
    {
        if (!environment.IsDevelopment())
        {
            throw new InvalidOperationException(
                "No SMTP host is configured, so no email can be sent. Set Smtp:Host and Smtp:FromAddress.");
        }

        logger.LogWarning(
            "SMTP not configured — email NOT sent. To: {To} | Subject: {Subject}\n{Body}",
            toAddress, subject, body);
        return Task.CompletedTask;
    }
}
