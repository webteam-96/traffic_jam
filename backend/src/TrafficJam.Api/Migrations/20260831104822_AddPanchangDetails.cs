using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrafficJam.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddPanchangDetails : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<DateTime>(
                name: "Sunset",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                oldClrType: typeof(TimeOnly),
                oldType: "time(6)");

            migrationBuilder.AlterColumn<DateTime>(
                name: "Sunrise",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                oldClrType: typeof(TimeOnly),
                oldType: "time(6)");

            migrationBuilder.AlterColumn<DateTime>(
                name: "RahuKaalStart",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                oldClrType: typeof(TimeOnly),
                oldType: "time(6)");

            migrationBuilder.AlterColumn<DateTime>(
                name: "RahuKaalEnd",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                oldClrType: typeof(TimeOnly),
                oldType: "time(6)");

            migrationBuilder.AlterColumn<DateTime>(
                name: "AbhijitStart",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                oldClrType: typeof(TimeOnly),
                oldType: "time(6)");

            migrationBuilder.AlterColumn<DateTime>(
                name: "AbhijitEnd",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                oldClrType: typeof(TimeOnly),
                oldType: "time(6)");

            migrationBuilder.AddColumn<DateTime>(
                name: "GulikaKaalEnd",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "GulikaKaalStart",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "KaranaEndsAt",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "Moonrise",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "Moonset",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "NakshatraEndsAt",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<string>(
                name: "Paksha",
                table: "PanchangCache",
                type: "longtext",
                nullable: false)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "TithiEndsAt",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "YamagandaKaalEnd",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "YamagandaKaalStart",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "YogaEndsAt",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GulikaKaalEnd",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "GulikaKaalStart",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "KaranaEndsAt",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "Moonrise",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "Moonset",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "NakshatraEndsAt",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "Paksha",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "TithiEndsAt",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "YamagandaKaalEnd",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "YamagandaKaalStart",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "YogaEndsAt",
                table: "PanchangCache");

            migrationBuilder.AlterColumn<TimeOnly>(
                name: "Sunset",
                table: "PanchangCache",
                type: "time(6)",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "datetime(6)");

            migrationBuilder.AlterColumn<TimeOnly>(
                name: "Sunrise",
                table: "PanchangCache",
                type: "time(6)",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "datetime(6)");

            migrationBuilder.AlterColumn<TimeOnly>(
                name: "RahuKaalStart",
                table: "PanchangCache",
                type: "time(6)",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "datetime(6)");

            migrationBuilder.AlterColumn<TimeOnly>(
                name: "RahuKaalEnd",
                table: "PanchangCache",
                type: "time(6)",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "datetime(6)");

            migrationBuilder.AlterColumn<TimeOnly>(
                name: "AbhijitStart",
                table: "PanchangCache",
                type: "time(6)",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "datetime(6)");

            migrationBuilder.AlterColumn<TimeOnly>(
                name: "AbhijitEnd",
                table: "PanchangCache",
                type: "time(6)",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "datetime(6)");
        }
    }
}
