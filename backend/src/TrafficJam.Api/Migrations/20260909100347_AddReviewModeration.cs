using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrafficJam.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddReviewModeration : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ModeratedAt",
                table: "AstrologerReviews",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Rating",
                table: "AstrologerReviews",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Status",
                table: "AstrologerReviews",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Before moderation existed, every review in this table was
            // published by definition — the column's Pending default would
            // otherwise silently unpublish any the team had already added.
            // The seeded rows are handled by the UpdateData calls below; this
            // covers anything created through the admin panel.
            migrationBuilder.Sql("UPDATE `AstrologerReviews` SET `Status` = 1, `ModeratedAt` = UTC_TIMESTAMP();");

            migrationBuilder.AddColumn<Guid>(
                name: "UserId",
                table: "AstrologerReviews",
                type: "char(36)",
                nullable: true,
                collation: "ascii_general_ci");

            migrationBuilder.UpdateData(
                table: "AstrologerReviews",
                keyColumn: "Id",
                keyValue: new Guid("a57e10c9-0000-4000-8000-000000000101"),
                columns: new[] { "ModeratedAt", "Rating", "Status", "UserId" },
                values: new object[] { null, null, 1, null });

            migrationBuilder.UpdateData(
                table: "AstrologerReviews",
                keyColumn: "Id",
                keyValue: new Guid("a57e10c9-0000-4000-8000-000000000102"),
                columns: new[] { "ModeratedAt", "Rating", "Status", "UserId" },
                values: new object[] { null, null, 1, null });

            migrationBuilder.UpdateData(
                table: "AstrologerReviews",
                keyColumn: "Id",
                keyValue: new Guid("a57e10c9-0000-4000-8000-000000000103"),
                columns: new[] { "ModeratedAt", "Rating", "Status", "UserId" },
                values: new object[] { null, null, 1, null });

            migrationBuilder.CreateIndex(
                name: "IX_AstrologerReviews_UserId",
                table: "AstrologerReviews",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_AstrologerReviews_Users_UserId",
                table: "AstrologerReviews",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_AstrologerReviews_Users_UserId",
                table: "AstrologerReviews");

            migrationBuilder.DropIndex(
                name: "IX_AstrologerReviews_UserId",
                table: "AstrologerReviews");

            migrationBuilder.DropColumn(
                name: "ModeratedAt",
                table: "AstrologerReviews");

            migrationBuilder.DropColumn(
                name: "Rating",
                table: "AstrologerReviews");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "AstrologerReviews");

            migrationBuilder.DropColumn(
                name: "UserId",
                table: "AstrologerReviews");
        }
    }
}
