using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Infrastructure;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Astrologer;

public record AstrologerReviewResponse(Guid Id, string Quote, string Author, int? Rating);

public record SubmitReviewRequest(string Quote, int Rating);

/// <summary>The caller's own review and where it stands, so the app can show
/// "awaiting approval" rather than looking like the submission vanished.</summary>
public record MyReviewResponse(Guid Id, string Quote, int? Rating, string Status, DateTime CreatedAt);

public record AstrologerProfileResponse(
    string Name,
    string Title,
    IReadOnlyList<string> Bio,
    string Philosophy,
    IReadOnlyList<string> Expertise,
    string? ImageDataUri,
    IReadOnlyList<AstrologerReviewResponse> Reviews);

/// <summary>
/// What the app's About screen reads. Bio and Expertise are stored as
/// newline-separated text and split here, so the client renders a list
/// without needing to know the storage shape.
/// </summary>
public static class AstrologerEndpoints
{
    public static void MapAstrologerEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/astrologer", async (AppDbContext db, CancellationToken ct) =>
        {
            var profile = await db.AstrologerProfile.AsNoTracking().FirstOrDefaultAsync(ct);
            if (profile is null) return Results.NotFound();

            // Approved only. Pending and rejected submissions must never
            // reach the app — this is the single gate between what a user
            // typed and what every other user sees.
            var reviews = await db.AstrologerReviews.AsNoTracking()
                .Where(r => r.Status == ReviewStatus.Approved)
                .OrderBy(r => r.SortOrder).ThenBy(r => r.CreatedAt)
                .Select(r => new AstrologerReviewResponse(r.Id, r.Quote, r.Author, r.Rating))
                .ToListAsync(ct);

            return Results.Ok(new AstrologerProfileResponse(
                profile.Name,
                profile.Title,
                SplitLines(profile.Bio),
                profile.Philosophy,
                SplitLines(profile.Expertise),
                profile.ImageDataUri,
                reviews));
        }).RequireAuthorization();

        var reviews = app.MapGroup("/reviews").RequireAuthorization();

        // What the caller has already submitted, if anything — drives the
        // app's "under review" state instead of it offering the form again.
        reviews.MapGet("/mine", async (
            System.Security.Claims.ClaimsPrincipal principal, AppDbContext db, CancellationToken ct) =>
        {
            var userId = principal.UserId();
            var mine = await db.AstrologerReviews.AsNoTracking()
                .Where(r => r.UserId == userId)
                .OrderByDescending(r => r.CreatedAt)
                .Select(r => new MyReviewResponse(r.Id, r.Quote, r.Rating, r.Status.ToString(), r.CreatedAt))
                .FirstOrDefaultAsync(ct);

            return mine is null ? Results.NoContent() : Results.Ok(mine);
        });

        reviews.MapPost("", async (
            SubmitReviewRequest request, System.Security.Claims.ClaimsPrincipal principal,
            AppDbContext db, CancellationToken ct) =>
        {
            var quote = request.Quote.Trim();
            if (quote.Length < 10)
            {
                return Results.BadRequest(new { error = new { code = "REVIEW_TOO_SHORT", message = "Please write a little more." } });
            }

            if (quote.Length > 600)
            {
                return Results.BadRequest(new { error = new { code = "REVIEW_TOO_LONG", message = "Please keep it under 600 characters." } });
            }

            if (request.Rating is < 1 or > 5)
            {
                return Results.BadRequest(new { error = new { code = "INVALID_RATING", message = "Rating must be 1 to 5 stars." } });
            }

            var userId = principal.UserId();

            // One review per person. Resubmitting replaces the previous one
            // rather than stacking, so a user can fix a typo — but an already
            // approved review can't be silently edited into something else
            // after the team vetted it.
            var existing = await db.AstrologerReviews
                .Where(r => r.UserId == userId)
                .OrderByDescending(r => r.CreatedAt)
                .FirstOrDefaultAsync(ct);

            if (existing is { Status: ReviewStatus.Approved })
            {
                return Results.Conflict(new
                {
                    error = new
                    {
                        code = "ALREADY_REVIEWED",
                        message = "Your review is already published. Contact support to change it.",
                    },
                });
            }

            var user = await db.Users.SingleOrDefaultAsync(u => u.Id == userId, ct);
            var author = string.IsNullOrWhiteSpace(user?.Name) ? "A TrafficJam.Life user" : user!.Name!;

            if (existing is not null)
            {
                existing.Quote = quote;
                existing.Rating = request.Rating;
                existing.Author = author;
                existing.Status = ReviewStatus.Pending;
                existing.CreatedAt = DateTime.UtcNow;
                existing.ModeratedAt = null;
            }
            else
            {
                db.AstrologerReviews.Add(new AstrologerReview
                {
                    Quote = quote,
                    Author = author,
                    Rating = request.Rating,
                    UserId = userId,
                    Status = ReviewStatus.Pending,
                    // Newest user reviews sort after the team's curated ones
                    // until an admin gives them an explicit position.
                    SortOrder = 100,
                });
            }

            await db.SaveChangesAsync(ct);
            return Results.Ok(new { status = "Pending" });
        });
    }

    internal static IReadOnlyList<string> SplitLines(string value) =>
        value.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}
