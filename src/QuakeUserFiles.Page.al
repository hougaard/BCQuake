/// <summary>The files Quake wrote for the current user: the settings (config.cfg). Save games are on page "Quake Save Games".</summary>
page 65002 "Quake User Files"
{
    PageType = List;
    Caption = 'Quake Settings';
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
                    ToolTip = 'The file name: config.cfg holds the settings and key bindings.';
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
