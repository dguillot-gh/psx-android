Task: write tools\make-game-toml-in.ps1 (PowerShell only, no .bat or .cmd files).
It turns a game's desktop game.toml into the Android template app\src\main\assets\game.toml.in.
Parameters: -GameToml <path to game.toml>, -Out <path of the file to write>.
Example of a correct result: tests\fixtures\tomba\game.toml -> tests\fixtures\tomba\expected.game.toml.in

Output, in this order:
1. Two comment lines:
   # Android runtime config, written by the start menu after the user selects
   # their own disc image (it fills the disc placeholder).
2. [game] with these keys copied unchanged from the input [game] section, if present:
   name, id, players, exe, load_address, entry_pc, text_size, stack_base, disc_serials.
   Instead of the input's discs list, write one placeholder per input disc:
   discs = [
     @@DISC1@@,
     @@DISC2@@,
   ]
   (as many lines as the input [game] discs list has entries; placeholders are NOT quoted).
   Do NOT copy the single `disc = ...` key.
3. [recompiler] copied unchanged from the input.
4. [runtime] with exactly: video_renderer = "software" and overlay_cache = true.
5. [controller] copied unchanged from the input (default_mode etc.), if present.
6. [widescreen] copied unchanged from the input, if present.
7. [bios] with exactly: path = "bios/openbios.bin"
Leave out everything else: [prepare_disc], [netplay], [video], window_title, memcard_dir, digests, G:/ paths.
Put one blank line between sections. Write UTF-8 without BOM.
Read the input as text line by line; no TOML module is installed. Sections start with a line like [name].
A key's value can span several lines when it is a list that starts with [ and ends with a line holding only ].
If a detail is unclear, write UNKNOWN: <what you need> and stop.
Never modify the input file. Never touch disc, saves, or memory card files.
DONE WHEN tools\check-02.ps1 exits 0.
