/// <summary>
/// A Quake PAK file (pak0.pak), deserialized into one record per file in the PAK.
/// The PAK header and directory are records too, so every byte of the original PAK is in a record at its
/// original file position: the "Quake Engine" reads the PAK through this table as if it were the file.
/// </summary>
table 65000 "Quake Pak File"
{
    Caption = 'Quake Pak File';
    DataClassification = SystemMetadata;
    DataPerCompany = false;
    LookupPageId = "Quake Pak Files";
    DrillDownPageId = "Quake Pak Files";

    fields
    {
        field(1; "Pak Name"; Text[30])
        {
            Caption = 'Pak Name';
        }
        field(2; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(3; Name; Text[60])
        {
            Caption = 'Name';
        }
        field(4; "File Position"; Integer)
        {
            Caption = 'File Position';
        }
        field(5; Size; Integer)
        {
            Caption = 'Size';
        }
        field(6; Data; Blob)
        {
            Caption = 'Data';
        }
        // WAV files (sound/*.wav): what Quake's GetWavinfo reads from the file
        field(10; "Sample Rate"; Integer)
        {
            Caption = 'Sample Rate';
        }
        field(11; "Sample Width"; Integer)
        {
            Caption = 'Sample Width (bytes)';
        }
        field(12; Channels; Integer)
        {
            Caption = 'Channels';
        }
        field(13; "Sample Count"; Integer)
        {
            Caption = 'Sample Count';
        }
        field(14; "Loop Start"; Integer)
        {
            Caption = 'Loop Start';
            InitValue = -1;
        }
    }

    keys
    {
        key(PK; "Pak Name", "Entry No.")
        {
            Clustered = true;
        }
        key(Position; "Pak Name", "File Position")
        {
        }
        key(FileName; Name)
        {
        }
    }
}
