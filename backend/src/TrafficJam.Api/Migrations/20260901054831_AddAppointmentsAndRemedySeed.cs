using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace TrafficJam.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAppointmentsAndRemedySeed : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Appointments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    UserId = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    Area = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Email = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Message = table.Column<string>(type: "longtext", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    PreferredDate = table.Column<DateOnly>(type: "date", nullable: false),
                    PreferredTime = table.Column<TimeOnly>(type: "time(6)", nullable: false),
                    Status = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Appointments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Appointments_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "RemedyContent",
                columns: new[] { "Id", "AudioUrl", "Detail", "Title", "TriggerRule", "Type" },
                values: new object[,]
                {
                    { new Guid("01a9d48d-f672-4f1b-bf28-85f904be726e"), null, "Chant \"Om Budhaya Namah\" on Wednesdays to support clear thinking and communication.", "Budha mantra on Wednesday", "Mercury", "mantra" },
                    { new Guid("064bc2b6-c738-4fd3-8b69-18d54bb4a343"), null, "Keep a regular sleep schedule near the full and new moon, and donate rice or milk on Mondays.", "Protect your sleep around the full and new moon", "Moon", "lifestyle" },
                    { new Guid("0dc6a08b-c4e6-4c8e-824a-d32be7240095"), null, "Chant \"Om Rahave Namah\" on Saturdays, and avoid major decisions during Rahu Kaal.", "Rahu mantra on Saturday", "Rahu", "mantra" },
                    { new Guid("12a6bc09-182f-4b55-85b2-045cb2f82816"), null, "Donate green moong dal or books on Wednesdays, and feed green vegetables to cows if you can.", "Wednesday giving", "Mercury", "charity" },
                    { new Guid("16e4c981-c631-4bad-acc4-6dee8a6c5e3b"), null, "Donate white items (rice, sugar, clothing) on Fridays, and keep your living space clean and pleasant.", "A little more beauty on Friday", "Venus", "lifestyle" },
                    { new Guid("17e0d927-0c28-467f-8514-31b1994e77fc"), null, "Donate mustard oil or black sesame seeds, or spend some time serving others on Saturdays.", "Saturday service", "Saturn", "charity" },
                    { new Guid("21091c89-b8e0-443e-9e2b-5a416a70e3dd"), null, "Donate blankets or dark-coloured grains to those in need — a grounding counterweight to Rahu's ambition.", "Grounding Rahu's restlessness", "Rahu", "charity" },
                    { new Guid("2ba89fb9-13c2-4247-9999-6ac7ebe613e5"), null, "Chant \"Om Angarakaya Namah\" 108 times on Tuesdays to channel Mars' energy constructively.", "Mangal mantra on Tuesday", "Mars", "mantra" },
                    { new Guid("32a7bbda-6a38-4e8d-9c43-249029eab11c"), null, "Set aside time for meditation or spiritual study, and consider giving anonymously when you can.", "Quiet time for Ketu", "Ketu", "lifestyle" },
                    { new Guid("4fdf37fa-09d9-498b-9e4c-5a0779a374fb"), null, "Begin each day with a few quiet minutes of reflection or meditation before checking your phone.", "Start the day before the phone does", "general", "lifestyle" },
                    { new Guid("69ce6858-5b47-4fe0-a38e-3d457c1787d3"), null, "Chant \"Om Shukraya Namah\" on Fridays to support love, beauty and harmony.", "Shukra mantra on Friday", "Venus", "mantra" },
                    { new Guid("6d37ff62-789f-4468-8f11-a944da36c44b"), null, "Chant \"Om Ketave Namah\", or a Ganesha mantra — classically believed to pacify Ketu's influence.", "Ketu mantra", "Ketu", "mantra" },
                    { new Guid("6ee467c9-cd22-4702-b341-8ac21926a9dc"), null, "Donate wheat or jaggery on Sundays — Surya's day rewards discipline, vitality and giving back.", "Sunday giving", "Sun", "charity" },
                    { new Guid("833d0c04-19fa-462a-8e61-fff2aca3a27f"), null, "Donate red lentils (masoor dal) or jaggery on Tuesdays, and avoid starting conflicts on this day.", "Tuesday giving, and a calmer temper", "Mars", "charity" },
                    { new Guid("99fba551-965e-4d17-ad79-7c8f36ace740"), null, "Chant \"Om Sham Shanicharaya Namah\" on Saturdays — Saturn rewards patience, discipline and humility.", "Shani mantra on Saturday", "Saturn", "mantra" },
                    { new Guid("acbd1d3f-e302-46b9-b46b-6c4858e1eca2"), null, "Donate turmeric, chana dal, or yellow items to teachers or those in need on Thursdays.", "Thursday giving", "Jupiter", "charity" },
                    { new Guid("afaf592c-af6e-4613-8f02-a2a4ef461285"), null, "Chant \"Om Chandraya Namah\" on Monday evenings to steady the mind and emotions.", "Chandra mantra on Monday", "Moon", "mantra" },
                    { new Guid("dc9edf2b-75ed-430d-b513-45fc88aa532b"), null, "Chant \"Om Suryaya Namah\" 108 times facing east at sunrise, and offer water (Arghya) to the rising sun.", "Surya mantra at sunrise", "Sun", "mantra" },
                    { new Guid("ea045864-241c-4b73-87d5-c7e9d9a3d4d7"), null, "Chant \"Om Gram Grim Graum Sah Gurave Namah\" on Thursdays to invite Jupiter's wisdom and growth.", "Guru mantra on Thursday", "Jupiter", "mantra" },
                    { new Guid("fa9359ab-7970-466b-a528-713dc3863f3f"), null, "Noting three things you're grateful for each day steadies the mind regardless of which planet is active. These are general, traditional practices — for anything specific to your own chart, ask Jay.", "Keep a gratitude journal", "general", "lifestyle" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_UserId",
                table: "Appointments",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Appointments");

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("01a9d48d-f672-4f1b-bf28-85f904be726e"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("064bc2b6-c738-4fd3-8b69-18d54bb4a343"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("0dc6a08b-c4e6-4c8e-824a-d32be7240095"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("12a6bc09-182f-4b55-85b2-045cb2f82816"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("16e4c981-c631-4bad-acc4-6dee8a6c5e3b"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("17e0d927-0c28-467f-8514-31b1994e77fc"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("21091c89-b8e0-443e-9e2b-5a416a70e3dd"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("2ba89fb9-13c2-4247-9999-6ac7ebe613e5"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("32a7bbda-6a38-4e8d-9c43-249029eab11c"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("4fdf37fa-09d9-498b-9e4c-5a0779a374fb"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("69ce6858-5b47-4fe0-a38e-3d457c1787d3"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("6d37ff62-789f-4468-8f11-a944da36c44b"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("6ee467c9-cd22-4702-b341-8ac21926a9dc"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("833d0c04-19fa-462a-8e61-fff2aca3a27f"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("99fba551-965e-4d17-ad79-7c8f36ace740"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("acbd1d3f-e302-46b9-b46b-6c4858e1eca2"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("afaf592c-af6e-4613-8f02-a2a4ef461285"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("dc9edf2b-75ed-430d-b513-45fc88aa532b"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("ea045864-241c-4b73-87d5-c7e9d9a3d4d7"));

            migrationBuilder.DeleteData(
                table: "RemedyContent",
                keyColumn: "Id",
                keyValue: new Guid("fa9359ab-7970-466b-a528-713dc3863f3f"));
        }
    }
}
