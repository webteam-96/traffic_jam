using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace TrafficJam.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAdminPanel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AdminUsers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    Email = table.Column<string>(type: "varchar(255)", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    PasswordHash = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Name = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminUsers", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "ConsultPlanRows",
                columns: table => new
                {
                    Id = table.Column<string>(type: "varchar(255)", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Name = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    PriceRupees = table.Column<long>(type: "bigint", nullable: false),
                    SlaHours = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConsultPlanRows", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "SubscriptionPlanRows",
                columns: table => new
                {
                    Id = table.Column<string>(type: "varchar(255)", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Name = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Tier = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Cycle = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    PriceRupees = table.Column<long>(type: "bigint", nullable: false),
                    FeaturesJson = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SubscriptionPlanRows", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.InsertData(
                table: "AdminUsers",
                columns: new[] { "Id", "CreatedAt", "Email", "Name", "PasswordHash" },
                values: new object[] { new Guid("00000000-0000-0000-0000-000000000001"), new DateTime(2026, 9, 1, 0, 0, 0, 0, DateTimeKind.Utc), "admin@trafficjam.life", "Traffic Jam Admin", "210000.sBvGgNG4BNIZo1TOLt0P1w==.D8IqhFYqaSICrUItAR/LrOUjll5Rjayp7mZtdppxldE=" });

            migrationBuilder.InsertData(
                table: "ConsultPlanRows",
                columns: new[] { "Id", "Name", "PriceRupees", "SlaHours" },
                values: new object[,]
                {
                    { "priority", "Priority", 299L, 1 },
                    { "standard", "Standard", 99L, 4 }
                });

            migrationBuilder.InsertData(
                table: "SubscriptionPlanRows",
                columns: new[] { "Id", "Cycle", "FeaturesJson", "Name", "PriceRupees", "Tier" },
                values: new object[,]
                {
                    { "free", "None", "[\"Daily Traffic Signal\",\"Basic Panchang\"]", "Free", 0L, "Free" },
                    { "saga_plus_annual", "Yearly", "[\"Deep-space transits\",\"Unlimited Panchang\",\"Priority Ask Jay\",\"2 months free\"]", "Saga+ Annual", 2999L, "SagaPlus" },
                    { "saga_plus_monthly", "Monthly", "[\"Deep-space transits\",\"Unlimited Panchang\",\"Priority Ask Jay\"]", "Saga+ Monthly", 299L, "SagaPlus" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_AdminUsers_Email",
                table: "AdminUsers",
                column: "Email",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AdminUsers");

            migrationBuilder.DropTable(
                name: "ConsultPlanRows");

            migrationBuilder.DropTable(
                name: "SubscriptionPlanRows");
        }
    }
}
