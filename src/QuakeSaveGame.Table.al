/// <summary>
/// Quake save games, per user: the slots of the Save Game and Load Game menus (s0.sav .. s11.sav), the quicksave
/// (quick.sav) and saves made in the console with save &lt;name&gt;. The "Quake Engine" codeunit reads and writes them;
/// what a save game holds (level, skill, ...) comes from the first lines of the save file.
/// </summary>
table 65002 "Quake Save Game"
{
    Caption = 'Quake Save Game';
    DataClassification = CustomerContent;
    DataPerCompany = false;
    LookupPageId = "Quake Save Games";
    DrillDownPageId = "Quake Save Games";

    fields
    {
        field(1; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(2; Name; Text[100])
        {
            Caption = 'Name';
        }
        field(3; "Slot No."; Integer)
        {
            Caption = 'Slot No.';
            BlankZero = true;
        }
        field(4; "Level Name"; Text[50])
        {
            Caption = 'Level Name';
        }
        field(5; Map; Text[50])
        {
            Caption = 'Map';
        }
        field(6; Skill; Option)
        {
            Caption = 'Skill';
            OptionMembers = Easy,Normal,Hard,Nightmare;
            OptionCaption = 'Easy,Normal,Hard,Nightmare';
        }
        field(7; Kills; Text[20])
        {
            Caption = 'Kills';
        }
        field(8; "Game Time"; Duration)
        {
            Caption = 'Game Time';
        }
        field(9; "Saved At"; DateTime)
        {
            Caption = 'Saved At';
        }
        field(10; Size; Integer)
        {
            Caption = 'Size (bytes)';
        }
        field(11; Data; Blob)
        {
            Caption = 'Data';
        }
    }

    keys
    {
        key(PK; "User ID", Name)
        {
            Clustered = true;
        }
        key(SavedAt; "User ID", "Saved At")
        {
        }
    }
}
