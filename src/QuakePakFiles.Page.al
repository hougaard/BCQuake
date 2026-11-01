/// <summary>The files in the imported Quake PAK files.</summary>
page 65001 "Quake Pak Files"
{
    PageType = List;
    Caption = 'Quake PAK Files';
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Quake Pak File";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Files)
            {
                field("Pak Name"; Rec."Pak Name")
                {
                    ToolTip = 'The PAK file the file is in.';
                }
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'The number of the file in the PAK.';
                }
                field(Name; Rec.Name)
                {
                    ToolTip = 'The file name in the PAK.';
                }
                field("File Position"; Rec."File Position")
                {
                    ToolTip = 'Where the file starts in the PAK.';
                }
                field(Size; Rec.Size)
                {
                    ToolTip = 'The size of the file in bytes.';
                }
                field("Sample Rate"; Rec."Sample Rate")
                {
                    ToolTip = 'For sounds: the sample rate of the WAV file.';
                }
                field("Sample Count"; Rec."Sample Count")
                {
                    ToolTip = 'For sounds: the number of samples.';
                }
                field("Loop Start"; Rec."Loop Start")
                {
                    ToolTip = 'For sounds that loop: the sample where the loop starts.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportPak)
            {
                ApplicationArea = All;
                Caption = 'Import PAK File';
                ToolTip = 'Imports a PAK file, for example pak1.pak from the registered version of Quake.';
                Image = Import;

                trigger OnAction()
                var
                    PakImport: Codeunit "Quake Pak Import";
                    TempBlob: Codeunit "Temp Blob";
                    InS: InStream;
                    OutS: OutStream;
                    FileName: Text;
                    Count: Integer;
                begin
                    if not UploadIntoStream(ImportTxt, '', PakFilterTxt, FileName, InS) then
                        exit;
                    TempBlob.CreateOutStream(OutS);
                    CopyStream(OutS, InS);
                    Count := PakImport.ImportPak(TempBlob, GetFileName(FileName));
                    Message(ImportedMsg, FileName, Count);
                end;
            }
            action(ReimportShareware)
            {
                ApplicationArea = All;
                Caption = 'Import Shareware PAK';
                ToolTip = 'Imports pak0.pak (the shareware episode) again from the app.';
                Image = Restore;

                trigger OnAction()
                var
                    PakImport: Codeunit "Quake Pak Import";
                begin
                    Message(ImportedMsg, 'pak0.pak', PakImport.ImportFromResource('PAK0.zip', 'pak0.pak'));
                end;
            }
        }
        area(Promoted)
        {
            actionref(ImportPak_Promoted; ImportPak)
            {
            }
        }
    }

    var
        ImportTxt: Label 'Import a Quake PAK file';
        PakFilterTxt: Label 'PAK files (*.pak)|*.pak|All files (*.*)|*.*';
        ImportedMsg: Label '%1 imported: %2 files.', Comment = '%1 = file name, %2 = number of files';

    local procedure GetFileName(Path: Text): Text
    var
        i: Integer;
    begin
        for i := StrLen(Path) downto 1 do
            if Path[i] in ['\', '/'] then
                exit(LowerCase(CopyStr(Path, i + 1)));
        exit(LowerCase(Path));
    end;
}
