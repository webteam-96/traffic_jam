using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrafficJam.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddDevLoginDemoAccounts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "Users",
                columns: new[] { "Id", "AvatarUrl", "CreatedAt", "FirebaseUid", "Name", "PhoneHash" },
                values: new object[,]
                {
                    { new Guid("10000000-0000-0000-0000-000000000001"), null, new DateTime(2026, 9, 2, 0, 0, 0, 0, DateTimeKind.Utc), "dev:+919999900001", "Demo (Free)", "2ec2c1d2994802d3bba5aa6e697c7d132bcdf9a5c4c5af59a5a9c5e428fedf1" },
                    { new Guid("10000000-0000-0000-0000-000000000002"), null, new DateTime(2026, 9, 2, 0, 0, 0, 0, DateTimeKind.Utc), "dev:+919999900002", "Demo (Saga+ Monthly)", "6a6cbd5fd6f9a693465f6dc2f36698de2502492eec8c4c739cc214b82c02dfe" },
                    { new Guid("10000000-0000-0000-0000-000000000003"), null, new DateTime(2026, 9, 2, 0, 0, 0, 0, DateTimeKind.Utc), "dev:+919999900003", "Demo (Saga+ Annual)", "6acfb35b135a02360298fcb372d6672718fb65c1f36cfcb396012deaea2a89a" },
                });

            migrationBuilder.InsertData(
                table: "Subscriptions",
                columns: new[] { "UserId", "Cycle", "GatewayRef", "RenewsAt", "Tier" },
                values: new object[,]
                {
                    { new Guid("10000000-0000-0000-0000-000000000002"), "Monthly", "demo-seed", new DateTime(2030, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "SagaPlus" },
                    { new Guid("10000000-0000-0000-0000-000000000003"), "Yearly", "demo-seed", new DateTime(2030, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), "SagaPlus" },
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "Subscriptions",
                keyColumn: "UserId",
                keyValue: new Guid("10000000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "Subscriptions",
                keyColumn: "UserId",
                keyValue: new Guid("10000000-0000-0000-0000-000000000003"));

            migrationBuilder.DeleteData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("10000000-0000-0000-0000-000000000001"));

            migrationBuilder.DeleteData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("10000000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "Users",
                keyColumn: "Id",
                keyValue: new Guid("10000000-0000-0000-0000-000000000003"));
        }
    }
}
