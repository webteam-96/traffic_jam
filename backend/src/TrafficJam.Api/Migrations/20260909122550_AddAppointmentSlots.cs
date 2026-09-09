using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrafficJam.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAppointmentSlots : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ScheduledAt",
                table: "Appointments",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "SlotId",
                table: "Appointments",
                type: "char(36)",
                nullable: true,
                collation: "ascii_general_ci");

            migrationBuilder.AddColumn<string>(
                name: "Timezone",
                table: "Appointments",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "AppointmentSlots",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "char(36)", nullable: false, collation: "ascii_general_ci"),
                    StartsAt = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    DurationMinutes = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AppointmentSlots", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_Appointments_SlotId",
                table: "Appointments",
                column: "SlotId",
                unique: true,
                filter: "`SlotId` IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_AppointmentSlots_StartsAt",
                table: "AppointmentSlots",
                column: "StartsAt");

            migrationBuilder.AddForeignKey(
                name: "FK_Appointments_AppointmentSlots_SlotId",
                table: "Appointments",
                column: "SlotId",
                principalTable: "AppointmentSlots",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Appointments_AppointmentSlots_SlotId",
                table: "Appointments");

            migrationBuilder.DropTable(
                name: "AppointmentSlots");

            migrationBuilder.DropIndex(
                name: "IX_Appointments_SlotId",
                table: "Appointments");

            migrationBuilder.DropColumn(
                name: "ScheduledAt",
                table: "Appointments");

            migrationBuilder.DropColumn(
                name: "SlotId",
                table: "Appointments");

            migrationBuilder.DropColumn(
                name: "Timezone",
                table: "Appointments");
        }
    }
}
