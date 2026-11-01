/// <summary>
/// Displays Quake frames (320x200, palette indexed), plays Quake's sounds and sends keyboard and mouse input back to Business Central.
/// </summary>
controladdin "Quake Screen"
{
    Scripts = 'src/controladdin/screen.js';
    StartupScript = 'src/controladdin/quake.js';
    StyleSheets = 'src/controladdin/quake.css';
    RequestedHeight = 640;
    MinimumHeight = 300;
    RequestedWidth = 800;
    MinimumWidth = 320;
    VerticalStretch = true;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    /// <summary>The add-in is loaded and ready.</summary>
    event ControlReady();

    /// <summary>
    /// Asks for the next batch of frames. Input is a JSON array of input events since the last request:
    /// [0,key] key down, [1,key] key up (Quake key numbers, mouse buttons are keys 200-202), [2,dx,dy] mouse move.
    /// ElapsedMs is the wall clock time since the previous request, FrameCount the number of frames to render.
    /// </summary>
    event RequestFrames(Input: Text; ElapsedMs: Integer; FrameCount: Integer);

    /// <summary>
    /// Shows a batch of frames, separated by ';'. Each frame is "palette!rows!sounds": palette is empty or the base64
    /// RGB palette, rows is base64 of the changed rows (row number byte + 320 palette indexes per row),
    /// sounds are the sound events of the frame (see "Quake Engine".GetSoundEvents).
    /// ServerMs is the time the server spent producing the batch.
    /// </summary>
    procedure DrawFrames(Frames: Text; ServerMs: Integer);

    /// <summary>Shows a small diagnostics text (timings) in the corner of the screen (F12 shows it).</summary>
    procedure ShowInfo(Info: Text);

    /// <summary>Shows a status text over the screen, or hides it (empty text).</summary>
    procedure ShowStatus(Message: Text);

    /// <summary>The sound effects (WAV files from the PAK): name relative to sound/:base64 WAV, separated by '|'.</summary>
    procedure LoadAudio(Sounds: Text);

    /// <summary>Starts the frame loop.</summary>
    procedure Start();
}
