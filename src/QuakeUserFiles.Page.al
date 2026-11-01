/// <summary>The files Quake wrote for the current user: settings (config.cfg) and save games.</summary>
page 65002 "Quake User Files"
{
    PageType = List;
    Caption = 'Quake Settings and Save Games';
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Quake User File";
    Editable = false;
    DeleteAllowed = true;

    layout
    {
        area(Content)
        {
            repeater(Files)
            {
                field(Name; Rec.Name)
                {
                    ToolTip = 'The file name: config.cfg holds the settings, s0.sav .. s11.sav are save games.';
                }
                field(Size; Rec.Size)
                {
                    ToolTip = 'The size of the file in bytes.';
                }
                field("Modified At"; Rec."Modified At")
                {
                    ToolTip = 'When Quake last wrote the file.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.FilterGroup(2);
        Rec.SetRange("User ID", UserId());
        Rec.FilterGroup(0);
    end;
}
