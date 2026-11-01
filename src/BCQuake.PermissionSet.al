permissionset 65000 "BC Quake"
{
    Assignable = true;
    Caption = 'BC Quake';

    Permissions =
        tabledata "Quake Pak File" = RIMD,
        tabledata "Quake User File" = RIMD,
        tabledata "Quake Save Game" = RIMD,
        table "Quake Pak File" = X,
        table "Quake User File" = X,
        table "Quake Save Game" = X,
        codeunit "Quake Engine" = X,
        codeunit "Quake Pak Import" = X,
        page "BC Quake" = X,
        page "Quake Pak Files" = X,
        page "Quake User Files" = X,
        page "Quake Save Games" = X;
}
