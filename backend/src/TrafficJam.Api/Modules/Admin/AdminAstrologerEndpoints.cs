using Microsoft.EntityFrameworkCore;
using TrafficJam.Api.Data;
using TrafficJam.Api.Data.Entities;

namespace TrafficJam.Api.Modules.Admin;

public record AdminAstrologerProfileRequest(
    string Name, string Title, string Bio, string Philosophy, string Expertise, string? ImageDataUri);

public record AdminAstrologerReviewRequest(string Quote, string Author, int SortOrder);

/// <summary>
/// Lets the team edit Jay's About page — profile copy, photo and client
/// reviews — without an app release. Before this the whole screen was
/// hardcoded in about_jay_kotecha_screen.dart.
/// </summary>
public static class AdminAstrologerEndpoints
{
    /// <summary>
    /// Ceiling on the profile photo. The admin panel crops and resizes to
    /// 400x400 before uploading (ImageCropper.tsx), which lands around
    /// 30-60 KB as JPEG — so 400 KB is generous headroom for that, while
    /// still refusing a full-resolution photo posted straight at the API.
    /// The client is the one that resizes; this is the backstop.
    /// </summary>
    private const int MaxImageDataUriLength = 400_000;

    public static void MapAdminAstrologerEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/admin/astrologer").RequireAuthorization("AdminOnly");

        group.MapGet("", async (AppDbContext db, CancellationToken ct) =>
        {
            var profile = await db.AstrologerProfile.AsNoTracking().FirstOrDefaultAsync(ct);
            // Pending first — the queue is the thing that needs attention.
            var reviews = await db.AstrologerReviews.AsNoTracking()
                .OrderBy(r => r.Status == ReviewStatus.Pending ? 0 : 1)
                .ThenBy(r => r.SortOrder).ThenBy(r => r.CreatedAt)
                .Select(r => new
                {
                    r.Id, r.Quote, r.Author, r.SortOrder, r.Rating,
                    Status = r.Status.ToString(),
                    IsFromUser = r.UserId != null,
                    r.CreatedAt,
                })
                .ToListAsync(ct);

            return Results.Ok(new { profile, reviews });
        });

        group.MapPut("", async (AdminAstrologerProfileRequest request, AppDbContext db, CancellationToken ct) =>
        {
            if (request.ImageDataUri is { Length: > MaxImageDataUriLength })
            {
                return Results.BadRequest(new
                {
                    error = new
                    {
                        code = "IMAGE_TOO_LARGE",
                        message = "That photo is too large. It should be cropped to 400x400 "
                            + "before upload — use the admin panel's photo picker.",
                    },
                });
            }

            var profile = await db.AstrologerProfile.FirstOrDefaultAsync(ct);
            if (profile is null)
            {
                profile = new AstrologerProfile
                {
                    Name = request.Name, Title = request.Title, Bio = request.Bio,
                    Philosophy = request.Philosophy, Expertise = request.Expertise,
                };
                db.AstrologerProfile.Add(profile);
            }

            profile.Name = request.Name;
            profile.Title = request.Title;
            profile.Bio = request.Bio;
            profile.Philosophy = request.Philosophy;
            profile.Expertise = request.Expertise;
            profile.UpdatedAt = DateTime.UtcNow;

            // Null means "leave the current photo alone" rather than "clear
            // it" — the admin form only sends this field when a new file was
            // actually picked, so saving a text edit must not wipe the photo.
            if (request.ImageDataUri is not null)
            {
                profile.ImageDataUri = request.ImageDataUri.Length == 0 ? null : request.ImageDataUri;
            }

            await db.SaveChangesAsync(ct);
            return Results.Ok(profile);
        });

        var reviews = app.MapGroup("/admin/astrologer/reviews").RequireAuthorization("AdminOnly");

        reviews.MapPost("", async (AdminAstrologerReviewRequest request, AppDbContext db, CancellationToken ct) =>
        {
            var review = new AstrologerReview
            {
                Quote = request.Quote, Author = request.Author, SortOrder = request.SortOrder,
                // Written by the team, so there is nobody left to approve it.
                Status = ReviewStatus.Approved,
                ModeratedAt = DateTime.UtcNow,
            };
            db.AstrologerReviews.Add(review);
            await db.SaveChangesAsync(ct);
            return Results.Ok(review);
        });

        // Moderation. A user submission arrives Pending and is invisible to
        // the app until it passes through here.
        reviews.MapPost("/{id:guid}/approve", async (Guid id, AppDbContext db, CancellationToken ct) =>
            await SetStatusAsync(id, ReviewStatus.Approved, db, ct));

        // Rejected rather than deleted: the submitter is told their review
        // wasn't published instead of it appearing to have vanished, and they
        // can revise and resubmit.
        reviews.MapPost("/{id:guid}/reject", async (Guid id, AppDbContext db, CancellationToken ct) =>
            await SetStatusAsync(id, ReviewStatus.Rejected, db, ct));

        reviews.MapPut("/{id:guid}", async (Guid id, AdminAstrologerReviewRequest request, AppDbContext db, CancellationToken ct) =>
        {
            var review = await db.AstrologerReviews.SingleOrDefaultAsync(r => r.Id == id, ct);
            if (review is null) return Results.NotFound();

            review.Quote = request.Quote;
            review.Author = request.Author;
            review.SortOrder = request.SortOrder;
            await db.SaveChangesAsync(ct);
            return Results.Ok(review);
        });

        reviews.MapDelete("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var review = await db.AstrologerReviews.SingleOrDefaultAsync(r => r.Id == id, ct);
            if (review is null) return Results.NotFound();

            db.AstrologerReviews.Remove(review);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });
    }

    private static async Task<IResult> SetStatusAsync(
        Guid id, ReviewStatus status, AppDbContext db, CancellationToken ct)
    {
        var review = await db.AstrologerReviews.SingleOrDefaultAsync(r => r.Id == id, ct);
        if (review is null) return Results.NotFound();

        review.Status = status;
        review.ModeratedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return Results.Ok(review);
    }
}
