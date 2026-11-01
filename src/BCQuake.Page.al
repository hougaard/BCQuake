/// <summary>
/// Plays Quake. The page hosts the "Quake Screen" control add-in: it receives input events from the add-in,
/// runs the "Quake Engine" codeunit (Quake translated from C to AL) for the requested frames and sends them back.
/// </summary>
page 65000 "BC Quake"
{
    PageType = UserControlHost;
    Caption = 'BC Quake';
    ApplicationArea = All;
    UsageCategory = Tasks;

    layout
    {
        area(Content)
        {
            usercontrol(Screen; "Quake Screen")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    StartQuake();
                end;

                trigger RequestFrames(Input: Text; ElapsedMs: Integer; FrameCount: Integer)
                var
                    T0: DateTime;
                    T1: DateTime;
                    Frames: TextBuilder;
                    FrameMs: Integer;
                    i: Integer;
                begin
                    T0 := CurrentDateTime;
                    ApplyInput(Input);
                    if FrameCount < 1 then
                        FrameCount := 1;
                    // game time follows the wall clock; Quake itself runs at most 0.1 seconds per frame
                    FrameMs := ElapsedMs div FrameCount;
                    for i := 1 to FrameCount do begin
                        T1 := CurrentDateTime;
                        Quake.Frame(FrameMs);
                        FrameTimeMs += CurrentDateTime - T1;
                        if Quake.IsQuitRequested() then begin
                            // the player quit from the menu (the settings are stored)
                            CurrPage.Close();
                            exit;
                        end;
                        T1 := CurrentDateTime;
                        if i > 1 then
                            Frames.Append(';');
                        Frames.Append(Quake.GetPaletteIfChanged());
                        Frames.Append('!');
                        Frames.Append(Quake.GetFrameDelta());
                        Frames.Append('!');
                        Frames.Append(Quake.GetSoundEvents());
                        EncodeMs += CurrentDateTime - T1;
                        FramesTimed += 1;
                    end;
                    if FramesTimed >= 10 then begin
                        CurrPage.Screen.ShowInfo(StrSubstNo('per frame: Quake %1ms, encode %2ms || %3 || %4',
                            Round(FrameTimeMs / FramesTimed, 1), Round(EncodeMs / FramesTimed, 1), StartInfo, Quake.GetWarnings()));
                        FramesTimed := 0;
                        FrameTimeMs := 0;
                        EncodeMs := 0;
                    end;
                    CurrPage.Screen.DrawFrames(Frames.ToText(), CurrentDateTime - T0);
                end;
            }
        }
    }

    var
        Quake: Codeunit "Quake Engine";
        FramesTimed: Integer;
        FrameTimeMs: Decimal;
        EncodeMs: Decimal;
        StartInfo: Text;
        ImportingTxt: Label 'Importing the Quake shareware PAK into Business Central (once)...';
        StartingTxt: Label 'Starting Quake...';

    local procedure StartQuake()
    var
        PakImport: Codeunit "Quake Pak Import";
        Window: Dialog;
        T0: DateTime;
    begin
        if not PakImport.IsImported('pak0.pak') then begin
            // deserialize the shareware PAK (shipped zipped in the app's resources) into the PAK table
            CurrPage.Screen.ShowStatus(ImportingTxt);
            Window.Open(ImportingTxt);
            PakImport.ImportFromResource('PAK0.zip', 'pak0.pak');
            Window.Close();
            Commit();
        end;
        if not Quake.IsStarted() then begin
            CurrPage.Screen.ShowStatus(StartingTxt);
            T0 := CurrentDateTime;
            Quake.StartQuake();
            StartInfo := StrSubstNo('start %1', CurrentDateTime - T0);
            // what the translated code's operations cost on this server (per million; F12 shows it)
            StartInfo += ' | ' + Quake.RunBenchmark();
        end;
        // the add-in plays the sounds itself: send it the WAV files of the PAK
        CurrPage.Screen.LoadAudio(PakImport.GetSoundData());
        Quake.GetSoundEvents(); // drop sounds from before the screen was (re)loaded
        // the screen may have been (re)loaded: send a complete first frame
        Quake.ResetFrameDelta();
        CurrPage.Screen.DrawFrames(Quake.GetPaletteIfChanged() + '!' + Quake.GetFrameDelta() + '!', 0);
        CurrPage.Screen.ShowInfo(StartInfo + ' || ' + Quake.GetWarnings());
        CurrPage.Screen.Start();
    end;

    local procedure ApplyInput(Input: Text)
    var
        Events: JsonArray;
        EventToken: JsonToken;
        Values: JsonArray;
    begin
        if (Input = '') or (Input = '[]') then
            exit;
        if not Events.ReadFrom(Input) then
            exit;
        foreach EventToken in Events do begin
            Values := EventToken.AsArray();
            case GetInt(Values, 0) of
                0:
                    Quake.KeyEvent(GetInt(Values, 1), true);
                1:
                    Quake.KeyEvent(GetInt(Values, 1), false);
                2:
                    Quake.MouseMove(GetInt(Values, 1), GetInt(Values, 2));
            end;
        end;
    end;

    local procedure GetInt(Values: JsonArray; Index: Integer): Integer
    var
        Token: JsonToken;
    begin
        Values.Get(Index, Token);
        exit(Token.AsValue().AsInteger());
    end;
}
