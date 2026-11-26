# MacroVaultPro 1.0.2

For World of Warcraft: Forever (interface 16001), build 2026-11-26a.

- **The version the addon reports is the version you installed.** The line in
  chat on login, and the version `/mvpro selftest` prints, now match the number
  in the archive's name. They used to say 1.0.0 whichever build was loaded, so a
  bug report could not be tied to the file it came from.
- **Nothing else changed** — same commands, same window, same behaviour. The
  release script now writes the `.toc` version, the version the addon prints and
  the build stamp together, so they cannot drift apart again.
