using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrafficJam.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAbhijitCleanWindow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "AbhijitCleanEnd",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "AbhijitCleanStart",
                table: "PanchangCache",
                type: "datetime(6)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AbhijitCleanEnd",
                table: "PanchangCache");

            migrationBuilder.DropColumn(
                name: "AbhijitCleanStart",
                table: "PanchangCache");
        }
    }
}
