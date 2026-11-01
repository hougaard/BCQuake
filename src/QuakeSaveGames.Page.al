/// <summary>Lists your Quake save games, newest first. Save and load them in the game; delete them here.</summary>
page 65003 "Quake Save Games"
{
    PageType = List;
    Caption = 'Quake Save Games';
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Quake Save Game";
    SourceTableView = sorting("User ID", "Saved At") order(descending);
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = true;

    layout
    {
        area(Content)
        {
            repeater(Saves)
            {
                field("Slot No."; Rec."Slot No.")
                {
                    Caption = 'Slot';
                    ToolTip = 'The slot in the game''s Save Game and Load Game menus, counted from the top.';
                }
                field(Name; Rec.Name)
                {
                    ToolTip = 'The save game''s name in Quake: s0 .. s11 for the menu slots, quick for the quicksave (F6), or the name used with the console command save.';
                }
                field("Level Name"; Rec."Level Name")
                {
                    ToolTip = 'The level the game was saved in.';
                }
                field(Map; Rec.Map)
                {
                    ToolTip = 'The map of the level, for example e1m3.';
                }
                field(Skill; Rec.Skill)
                {
                    ToolTip = 'The skill the game is played at.';
                }
                field(Kills; Rec.Kills)
                {
                    ToolTip = 'Monsters killed in the level, of the total.';
                }
                field("Game Time"; Rec."Game Time")
                {
                    ToolTip = 'How long the level had been played.';
                }
                field("Saved At"; Rec."Saved At")
                {
                    ToolTip = 'When the game was saved.';
                }
                field(Size; Rec.Size)
                {
                    ToolTip = 'The size of the save game in bytes.';
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
