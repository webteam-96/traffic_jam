using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace TrafficJam.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAstrologerProfileAndReviews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AstrologerProfile",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    Name = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Title = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Bio = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Philosophy = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Expertise = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    ImageDataUri = table.Column<string>(type: "longtext", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AstrologerProfile", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "AstrologerReviews",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    Quote = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Author = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AstrologerReviews", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "AstrologerProfile",
                columns: new[] { "Id", "Bio", "Expertise", "ImageDataUri", "Name", "Philosophy", "Title", "UpdatedAt" },
                values: new object[] { new Guid("a57e10c9-0000-4000-8000-000000000001"), "Jay Kotecha is a practicing Vedic astrologer with over 18 years of experience guiding individuals and businesses through life's critical intersections. Trained in the traditional guru-shishya parampara under the lineage of Pt. Sanjay Rath, he holds advanced certifications in Jaimini Sutras, Prashna (horary), and KP (Krishnamurti Paddhati) systems.\nBefore dedicating himself fully to Jyotish, Jay spent a decade in corporate finance and strategy consulting — an experience that grounds his readings in practical decision-making rather than abstract prediction. He has served clients across 22 countries and is a regular contributor to leading wellness platforms.\nJay founded TrafficJam.Life to democratize access to authentic, birth-chart-level guidance — moving astrology from entertainment to a daily decision engine for the modern seeker.", "Vedic Astrology (Parashara)\nKP System (Krishnamurti Paddhati)\nPrashna / Horary Astrology\nRemedial Astrology (Mantra, Yantra, Dana)\nFinancial & Business Astrology\nRelationship & Compatibility Analysis\nMuhurat / Electional Astrology\nNakshatra & Dasha Deep-Dives", null, "Jay Kotecha", "Astrology is a compass, not a verdict. The planets show the weather; you choose the path. My role is to read the sky clearly so you can walk with confidence — whether the signal is green, yellow, or red.", "Founder & Chief Astrologer", new DateTime(2026, 9, 9, 0, 0, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.InsertData(
                table: "AstrologerReviews",
                columns: new[] { "Id", "Author", "CreatedAt", "Quote", "SortOrder" },
                values: new object[,]
                {
                    { new Guid("a57e10c9-0000-4000-8000-000000000101"), "Rohan M., Software Architect", new DateTime(2026, 9, 9, 0, 0, 0, 0, DateTimeKind.Utc), "Jay's reading on my Saturn return timing was uncannily precise. He identified the exact month my career would pivot — and it did.", 0 },
                    { new Guid("a57e10c9-0000-4000-8000-000000000102"), "Anjali S., Entrepreneur", new DateTime(2026, 9, 9, 0, 0, 0, 0, DateTimeKind.Utc), "The remedy suggestions were practical, not ritualistic. Drinking water from a copper vessel during my Mars transit genuinely shifted my energy.", 1 },
                    { new Guid("a57e10c9-0000-4000-8000-000000000103"), "Vikram P., Founder", new DateTime(2026, 9, 9, 0, 0, 0, 0, DateTimeKind.Utc), "Business Muhurat for our Series A close — we timed the term sheet signing to Abhijit Muhurat. Round oversubscribed in 48 hours.", 2 }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AstrologerProfile");

            migrationBuilder.DropTable(
                name: "AstrologerReviews");
        }
    }
}
