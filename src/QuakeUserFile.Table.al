/// <summary>
/// The files Quake writes, per user: config.cfg (key bindings and settings) and the save games (s0.sav .. s11.sav).
/// </summary>
table 65001 "Quake User File"
{
    Caption = 'Quake User File';
    DataClassification = CustomerContent;
    DataPerCompany = false;
    LookupPageId = "Quake User Files";
    DrillDownPageId = "Quake User Files";

    fields
    {
        field(1; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(2; Name; Text[100])
        {
            Caption = 'File Name';
        }
        field(3; Size; Integer)
        {
            Caption = 'Size (bytes)';
        }
        field(4; "Modified At"; DateTime)
        {
            Caption = 'Modified At';
        }
        field(5; Data; Blob)
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
    }
}
