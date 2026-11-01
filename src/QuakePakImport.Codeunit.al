/// <summary>
/// Imports Quake PAK files into table "Quake Pak File": from the app's resources (the shareware pak0.pak, zipped)
/// or from an uploaded file (pak1.pak from the registered version).
/// </summary>
codeunit 65001 "Quake Pak Import"
{
    var
        NotAPakErr: Label 'This is not a Quake PAK file.';
        NoPakInZipErr: Label 'The resource %1 does not contain a .pak file.', Comment = '%1 = resource name';

    /// <summary>True when the PAK file (e.g. pak0.pak) is in the table.</summary>
    procedure IsImported(PakName: Text): Boolean
    var
        PakFile: Record "Quake Pak File";
    begin
        PakFile.SetRange("Pak Name", LowerCase(PakName));
        exit(not PakFile.IsEmpty());
    end;

    /// <summary>Imports the PAK file in a zip archive that ships with the app as a resource (resources are limited to 16 MB).</summary>
    procedure ImportFromResource(ResourceName: Text; PakName: Text): Integer
    var
        DataCompression: Codeunit "Data Compression";
        ZipBlob: Codeunit "Temp Blob";
        PakBlob: Codeunit "Temp Blob";
        ResIn: InStream;
        ZipOut: OutStream;
        Entries: List of [Text];
        Entry: Text;
    begin
        NavApp.GetResource(ResourceName, ResIn);
        ZipBlob.CreateOutStream(ZipOut);
        CopyStream(ZipOut, ResIn);
        DataCompression.OpenZipArchive(ZipBlob, false);
        DataCompression.GetEntryList(Entries);
        foreach Entry in Entries do
            if LowerCase(Entry).EndsWith('.pak') then begin
                DataCompression.ExtractEntry(Entry, PakBlob);
                DataCompression.CloseZipArchive();
                exit(ImportPak(PakBlob, PakName));
            end;
        Error(NoPakInZipErr, ResourceName);
    end;

    /// <summary>
    /// Deserializes a PAK file: header ('PACK', directory offset, directory length), the files, and the directory of
    /// 64 byte entries (name, file position, size). Replaces a PAK with the same name. Returns the number of files.
    /// </summary>
    procedure ImportPak(var TempBlob: Codeunit "Temp Blob"; PakName: Text): Integer
    var
        PakFile: Record "Quake Pak File";
        InS: InStream;
        Names: List of [Text];
        Positions: List of [Integer];
        Sizes: List of [Integer];
        Order: List of [Integer];
        DirOffset: Integer;
        DirLength: Integer;
        CurPos: Integer;
        Pos: Integer;
        i: Integer;
    begin
        PakName := LowerCase(PakName);
        if TempBlob.Length() < 12 then
            Error(NotAPakErr);
        TempBlob.CreateInStream(InS);
        if ReadChars(InS, 4) <> 'PACK' then
            Error(NotAPakErr);
        DirOffset := ReadInt32(InS);
        DirLength := ReadInt32(InS);
        Skip(InS, DirOffset - 12);
        for i := 1 to DirLength div 64 do begin
            Names.Add(LowerCase(ReadChars(InS, 56)));
            Positions.Add(ReadInt32(InS));
            Sizes.Add(ReadInt32(InS));
        end;

        PakFile.SetRange("Pak Name", PakName);
        PakFile.DeleteAll();

        // the header and the directory are records too: every byte of the PAK file is in the table
        Names.Insert(1, '(header)');
        Positions.Insert(1, 0);
        Sizes.Insert(1, 12);
        Names.Add('(directory)');
        Positions.Add(DirOffset);
        Sizes.Add(DirLength);
        Order := SortByPosition(Positions);
        // one pass through the PAK in file order
        TempBlob.CreateInStream(InS);
        CurPos := 0;
        foreach i in Order do begin
            Pos := Positions.Get(i);
            if Pos < CurPos then begin
                TempBlob.CreateInStream(InS);
                CurPos := 0;
            end;
            Skip(InS, Pos - CurPos);
            InsertEntry(InS, PakName, i - 1, Names.Get(i), Pos, Sizes.Get(i));
            CurPos := Pos + Sizes.Get(i);
        end;
        exit(Names.Count() - 2);
    end;

    // indexes of Positions, ordered by position
    local procedure SortByPosition(Positions: List of [Integer]) Order: List of [Integer]
    var
        i: Integer;
        j: Integer;
    begin
        for i := 1 to Positions.Count() do begin
            // AL evaluates both sides of 'and': test j before reading Order
            j := Order.Count();
            while j >= 1 do begin
                if Positions.Get(Order.Get(j)) <= Positions.Get(i) then
                    break;
                j -= 1;
            end;
            Order.Insert(j + 1, i);
        end;
    end;

    // copies the next Size bytes of the PAK stream into a new record
    local procedure InsertEntry(var InS: InStream; PakName: Text; EntryNo: Integer; Name: Text; Position: Integer; Size: Integer)
    var
        PakFile: Record "Quake Pak File";
        EntryBlob: Codeunit "Temp Blob";
        EntryIn: InStream;
        EntryOut: OutStream;
        DataOut: OutStream;
    begin
        PakFile.Init();
        PakFile."Pak Name" := CopyStr(PakName, 1, MaxStrLen(PakFile."Pak Name"));
        PakFile."Entry No." := EntryNo;
        PakFile.Name := CopyStr(Name, 1, MaxStrLen(PakFile.Name));
        PakFile."File Position" := Position;
        PakFile.Size := Size;
        if Size > 0 then begin
            EntryBlob.CreateOutStream(EntryOut);
            CopyStream(EntryOut, InS, Size);
            if Name.StartsWith('sound/') and Name.EndsWith('.wav') then
                ReadWavInfo(EntryBlob, PakFile);
            EntryBlob.CreateInStream(EntryIn);
            PakFile.Data.CreateOutStream(DataOut);
            CopyStream(DataOut, EntryIn);
        end;
        PakFile.Insert();
    end;

    /// <summary>The WAV's format, length and loop, as Quake's GetWavinfo (snd_mem.c) reads them.</summary>
    local procedure ReadWavInfo(var WavBlob: Codeunit "Temp Blob"; var PakFile: Record "Quake Pak File")
    var
        InS: InStream;
        ChunkId: Text;
        Total: Integer;
        Pos: Integer;
        Len: Integer;
        Used: Integer;
        DataLength: Integer;
        LoopLength: Integer;
        SawCue: Boolean;
        SawList: Boolean;
        HasMark: Boolean;
    begin
        Total := WavBlob.Length();
        WavBlob.CreateInStream(InS);
        if (Total < 12) or (ReadChars(InS, 4) <> 'RIFF') then
            exit;
        ReadInt32(InS);
        if ReadChars(InS, 4) <> 'WAVE' then
            exit;
        Pos := 12;
        PakFile."Loop Start" := -1;
        while Pos + 8 <= Total do begin
            ChunkId := ReadChars(InS, 4);
            Len := ReadInt32(InS);
            Pos += 8;
            if (Len < 0) or (Len > Total - Pos) then
                break;
            Used := 0;
            case ChunkId of
                'fmt ':
                    if Len >= 16 then begin
                        ReadInt16(InS); // format
                        PakFile.Channels := ReadInt16(InS);
                        PakFile."Sample Rate" := ReadInt32(InS);
                        Skip(InS, 6); // bytes per second, block align
                        PakFile."Sample Width" := ReadInt16(InS) div 8;
                        Used := 16;
                    end;
                'cue ':
                    if (Len >= 24) and not SawCue then begin
                        Skip(InS, 20);
                        PakFile."Loop Start" := ReadInt32(InS);
                        SawCue := true;
                        Used := 24;
                    end;
                'LIST':
                    // the first LIST after the cue chunk may hold the loop length (a cooledit 'mark')
                    if SawCue and not SawList and (Len >= 24) then begin
                        SawList := true;
                        Skip(InS, 16);
                        LoopLength := ReadInt32(InS);
                        HasMark := ReadChars(InS, 4) = 'mark';
                        Used := 24;
                    end;
                'data':
                    DataLength := Len;
            end;
            Skip(InS, (Len + 1) div 2 * 2 - Used);
            Pos += (Len + 1) div 2 * 2;
        end;
        if PakFile."Sample Width" < 1 then begin
            PakFile."Sample Rate" := 0;
            exit;
        end;
        if HasMark then
            PakFile."Sample Count" := PakFile."Loop Start" + LoopLength
        else
            PakFile."Sample Count" := DataLength div PakFile."Sample Width";
    end;

    /// <summary>
    /// The sound effects for the control add-in, which plays them itself: name (relative to sound/):base64 WAV file,
    /// separated by '|'. A PAK imported later (pak1.pak) replaces sounds with the same name.
    /// </summary>
    procedure GetSoundData(): Text
    var
        PakFile: Record "Quake Pak File";
        Base64Convert: Codeunit "Base64 Convert";
        Sounds: Dictionary of [Text, Text];
        Result: TextBuilder;
        InS: InStream;
        SoundName: Text;
    begin
        PakFile.SetFilter(Name, 'sound/*');
        PakFile.SetFilter("Sample Rate", '>0');
        PakFile.SetAutoCalcFields(Data);
        if PakFile.FindSet() then
            repeat
                PakFile.Data.CreateInStream(InS);
                SoundName := CopyStr(PakFile.Name, 7);
                if Sounds.ContainsKey(SoundName) then
                    Sounds.Set(SoundName, Base64Convert.ToBase64(InS))
                else
                    Sounds.Add(SoundName, Base64Convert.ToBase64(InS));
            until PakFile.Next() = 0;
        foreach SoundName in Sounds.Keys() do begin
            if Result.Length > 0 then
                Result.Append('|');
            Result.Append(SoundName);
            Result.Append(':');
            Result.Append(Sounds.Get(SoundName));
        end;
        exit(Result.ToText());
    end;

    local procedure ReadInt32(var InS: InStream): Integer
    var
        b: array[4] of Byte;
        Top: Integer;
        i: Integer;
    begin
        for i := 1 to 4 do
            InS.Read(b[i]);
        Top := b[4];
        if Top >= 128 then
            Top -= 256;
        exit(b[1] + 256 * (b[2] + 256 * (b[3] + 256 * Top)));
    end;

    local procedure ReadInt16(var InS: InStream): Integer
    var
        b1: Byte;
        b2: Byte;
        v: Integer;
    begin
        InS.Read(b1);
        InS.Read(b2);
        v := b1 + 256 * b2;
        if v >= 32768 then
            v -= 65536;
        exit(v);
    end;

    // Length bytes as characters, up to the first zero byte
    local procedure ReadChars(var InS: InStream; Length: Integer): Text
    var
        TB: TextBuilder;
        b: Byte;
        ch: Char;
        i: Integer;
        Ended: Boolean;
    begin
        for i := 1 to Length do begin
            InS.Read(b);
            if b = 0 then
                Ended := true;
            if not Ended then begin
                ch := b;
                TB.Append(ch);
            end;
        end;
        exit(TB.ToText());
    end;

    local procedure Skip(var InS: InStream; Count: Integer)
    var
        TempBlob: Codeunit "Temp Blob";
        Dummy: OutStream;
    begin
        if Count <= 0 then
            exit;
        TempBlob.CreateOutStream(Dummy);
        CopyStream(Dummy, InS, Count);
    end;
}
