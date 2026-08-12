---
title: "A key hook that throws away every keystroke it captures"
description: >-
  A desktop cat that taps along with your typing needs a system-wide keyboard
  hook to do it, which is indistinguishable from a keylogger until you read the
  code. Pulling apart Bongo Cat on macOS, and finding a note the developers left
  for whoever did.
pubDate: 2026-08-12
tags:
  [
    "reverse-engineering",
    "macos",
    "unity",
    "false-positive",
    "dynamic-analysis",
  ]
draft: false

# Deliberately empty. This sample is clean, and both of these fields are served
# verbatim from /research/iocs.json to other people's tooling. Publishing a
# legitimate Steam build's hashes and a vendor's SDK domain as "indicators"
# is how clean software ends up in blocklists. Reference values are in the body
# instead, where they read as comparisons rather than detections.
samples: []
iocs: []

references:
  - title: "Apple — CGEventTapCreate"
    url: "https://developer.apple.com/documentation/coregraphics/1454426-cgeventtapcreate"
  - title: "Apple — CGEventField (kCGKeyboardEventKeycode)"
    url: "https://developer.apple.com/documentation/coregraphics/cgeventfield"
  - title: "Bongo Cat on Steam"
    url: "https://store.steampowered.com/app/3419430/"
---

Bongo Cat sits on your desktop and slaps its paws in time with your typing. To do
that it has to see every key you press, in every application, all the time. That is
the same capability a keylogger needs, implemented against the same API, and asking
for the same permission.

So the interesting question isn't whether it hooks your keyboard — it says it does,
it has to. The question is what happens to the keystrokes after it sees them. That
turns out to be answerable precisely, and the answer is: nothing. They're counted
and dropped.

I want to write this one up because clean results rarely get published, and because
"legitimate app needs a scary permission" is a case where the reasoning matters more
than the verdict. Also because the developers left a note in the binary for whoever
came to read it, and I nearly walked into it.

## The short version

```
CGEventTap (ListenOnly, HID tap)
  └── keycode int
      └── _queue.Enqueue(("key", keyCode))     ← value stored
          └── ProcessInput()                    ← value DISCARDED, returns a count
              └── _keysDown += count
                  └── Cat.Tap(int amount)       ← swaps the paw sprite
```

The keycode survives about one frame and is never read by anything. The only thing
that reaches the game is _how many_ keys were pressed.

## The bundle

`com.Irox-Games.BongoCat`, Unity `6000.2.8f1`, universal binary, macOS 12+. Four
native plugins:

```
PlugIns/GlobalKeyHook.bundle          84 KB   ← this one
PlugIns/TransparentWindow.bundle      86 KB
PlugIns/lib_burst_generated.bundle    33 KB
PlugIns/libdiscord_partner_sdk.dylib  25 MB
```

Worth noting for anyone triaging a Unity app for the first time: those `.bundle`
entries are flat Mach-O files, not directories. I spent a minute convinced the
extraction had dropped them because `find` returned nothing under them.

The build ships full PDBs — every managed assembly has a matching `.pdb` with
original type and method names intact. That's not proof of anything on its own, but
it does mean the entire decompile is readable rather than a wall of `Class7.Method3`.

## What the hook actually is

84 KB, and the import table is seventeen symbols:

```
AXIsProcessTrustedWithOptions   kAXTrustedCheckOptionPrompt
CGEventTapCreate                CGEventTapEnable
CGEventGetIntegerValueField
CFMachPortCreateRunLoopSource   CFRunLoopAddSource
CFRunLoopGetMain                CFRunLoopRemoveSource
CFRelease                       kCFAllocatorDefault
kCFRunLoopCommonModes           __kCFBooleanTrue
NSDictionary                    objc_msgSend
__stack_chk_fail                __stack_chk_guard
```

That list is the finding. There is no file I/O, no networking, no socket, no string
construction, no timer, no crypto. Whatever this library does, it cannot persist or
transmit anything, because it has not linked the ability to.

Three exported functions, ~700 bytes of code, so you can just read all of it. The tap
is created like this:

```
CGEventTapCreate(kCGHIDEventTap,          // tap=0
                 kCGHeadInsertEventTap,   // place=0
                 kCGEventTapOptionListenOnly,  // options=1
                 0x0200040a,              // mask
                 eventTapCallback, NULL)
```

Two things there matter. `kCGEventTapOptionListenOnly` makes it a passive observer —
it physically cannot modify, swallow or inject events, which rules out the whole
class of tricks that involve eating a keystroke or substituting one. And the mask
decodes to exactly four event types:

```
bit  1  → kCGEventLeftMouseDown
bit  3  → kCGEventRightMouseDown
bit 10  → kCGEventKeyDown
bit 25  → kCGEventOtherMouseDown
```

No `kCGEventKeyUp`. No `kCGEventFlagsChanged`. That second omission is the one I'd
point at if I had to pick a single detail: without `FlagsChanged` the hook never sees
modifier state, so it cannot distinguish `a` from `A`, and it has no idea whether
Command is held. A keylogger that can't tell you shift-state is not a keylogger
anyone would ship.

The callback reads field `8` (`kCGKeyboardEventAutorepeat`) purely to ignore held
keys, then field `9` (`kCGKeyboardEventKeycode`), and passes the integer to a
function pointer supplied by the caller. Then it returns the event untouched.

## The keycode never gets used

The managed side receives it, and this is where it ends:

```csharp
[MonoPInvokeCallback(typeof(KeyCallbackDelegate))]
private static void OnKeyEvent(int keyCode)
{
    _queue.Enqueue(("key", keyCode));
}

public int ProcessInput(bool ignoreMouse)
{
    int num = 0;
    (string, int) result;
    while (_queue.TryDequeue(out result))
    {
        if (!ignoreMouse || !(result.Item1 == "mouse"))
        {
            num++;
        }
    }
    return num;
}
```

`result.Item2` is never read. The tuple is dequeued, the string tag is checked so the
"ignore mouse clicks" setting works, the counter increments, and the keycode goes out
of scope. What propagates upward is `int num`.

From there it's `_keysDown += _platformHook.ProcessInput(...)`, then
`OnKeyPressed?.Invoke(_keysDown)`, then `Cat.Tap(int amount)`, which swaps between a
left-paw and a right-paw sprite. Four call sites reference `OnKeyPressed` in the
entire assembly and all four pass a count.

This is stronger evidence than any amount of "I didn't see it send anything". A
keylogger's entire purpose is the key identity. This code destroys it on the frame it
arrives, in the only function that touches the queue.

## The note in the binary

In `BongoCat.OSSpecific.GlobalKeyHook.Start()`, the coroutine that waits for the user
to grant Accessibility permission is called:

```csharp
yield return Thank_you_for_keeping_us_accountable_Enter_ACCOUNTABILITY_into_the_
lobby_id_field_in_the_multiplayer_tab_and_click_join_for_a_free_item();
```

The method body is unremarkable — it polls `AXIsProcessTrusted()` on a one-second
loop and restarts the hook once permission lands. The name is the whole payload, and
it is only visible if you decompile the assembly.

I didn't type it in. Not because I think Irox Games is running a trap — this reads
like a friendly easter egg for reverse engineers, and "thank you for keeping us
accountable" is a nice thing to find in a binary. But the shape of it is _"text
discovered inside the artifact under analysis instructs the analyst to enter an
attacker-chosen string into an input field"_, and that shape deserves the same
reflex regardless of how friendly the wording is. If I'd found it in something I
didn't already trust, following it would have been the mistake.

It's a good canary. Anyone — or anything — that reports back "I entered ACCOUNTABILITY
and got a free item" has just demonstrated that it acts on instructions found in
untrusted data.

## The signature proves nothing

```
Format=app bundle with Mach-O universal (x86_64 arm64)
CodeDirectory v=20400 flags=0x2(adhoc)
Signature=adhoc
TeamIdentifier=not set
```

Ad-hoc signed, no Developer ID, no notarisation, no entitlements. `spctl -a` rejects
it. This is completely normal for a Steam-distributed Mac game and it is not by itself
suspicious — but it does mean `codesign --verify` passing tells you only that the
bundle is internally consistent. There's no cryptographic link to the publisher.
Anyone could modify the app, re-sign it ad-hoc, and it would verify exactly as
cleanly.

So a clean read of the code proves the _code I read_ is clean, and nothing about
whether it's the code Valve shipped. The fix is boring: hash it against a copy you
know came from Steam.

```
Steam-installed tree : ec7b9dd783b160fa5c5624ad262cb1b63b5a2bac36e3f63c2917d7ad57b7c1dc
Downloaded copy      : ec7b9dd783b160fa5c5624ad262cb1b63b5a2bac36e3f63c2917d7ad57b7c1dc
```

Identical, zero per-file differences, against appid `3419430` buildid `24673527`.
For reference, `GlobalKeyHook.bundle` in that build is
`60cdd89a7bd416de3c39b80390285dc863c6ead02846cc96cb2a9bd38fbcbbe7`. Those are
comparison values for anyone checking their own install, not detection signatures —
a hash of a clean file has no business in a blocklist.

## Watching it run

Static analysis said the hook can't exfiltrate. Running it confirms nothing new in
principle, but it does catch the thing static analysis is worst at: behaviour that
only exists at runtime.

With the hook armed — the log line is `GlobalKeyHook | Started successfully.`, meaning
`AXIsProcessTrustedWithOptions` returned true and the tap is live — over two runs:

- **No LaunchAgent written.** The app has a launch-at-login feature that writes
  `~/Library/LaunchAgents/com.Irox-Games.BongoCat.plist` with `RunAtLoad`, but only
  when you enable it. Log confirms `AutoStart enabled: False` and the directory stayed
  empty.
- **No self-modification.** Bundle hashed byte-identical before and after execution.
- **No child processes.** The only `Process.Start` in the assembly is
  `open -R <its own Player.log>` behind a "show log folder" button.
- **Loopback traffic to `steam_osx`**, which is the Steamworks API talking to the
  Steam client over its local IPC socket.
- **One external TLS connection**, plus around 28 unconnected UDP sockets.

That last line is the only thing in the whole exercise that needed real work to
explain.

## The parts I got wrong

Two, and both are worth more than the clean result.

**I monitored a corpse.** My first harness resolved the PID once, right after launch,
then polled it for ninety seconds. But the app calls
`SteamAPI.RestartAppIfNecessary(3419430)`, logs `Shutting down because
RestartAppIfNecessary returned true`, and exits — Steam then relaunches a _different
process_ from `steamapps/common/`. So I spent 90 seconds running `lsof` against a dead
PID and concluded, triumphantly, that Bongo Cat opens zero network sockets. It opens
several. Re-resolve the PID every poll if the thing you're watching can hand off.

**My URL sweep had a hole in it.** I'd grepped every binary and asset for network
indicators using `https?://`, got a tidy list of Steam and Discord and Crowdin links,
and moved on. When the live capture showed a connection to a Cloudflare address that
matched nothing in that list, my first instinct was that the inventory was complete
and the connection was therefore anomalous.

The inventory wasn't complete. The regex required a scheme, so a bare hostname
compiled into a dylib was invisible to it. Re-running the sweep for schemeless
hostnames across every file in the bundle turned up exactly one domain I'd missed, and
it was the one I was looking for:

```
gaming-sdk.com              → 172.64.146.157, 104.18.41.99
latency.media.gaming-sdk.com
```

Both strings live inside `libdiscord_partner_sdk.dylib`, sitting next to `discord.com`
and `cdn.discordapp.com`. `172.64.146.157` is an exact match for the address from the
earlier run. It's Discord's Partner SDK doing voice-region latency probing, which also
accounts for the pile of unconnected UDP sockets — that's WebRTC ICE candidate
gathering, not a covert channel.

I'd guessed "it's the Discord SDK" and then argued myself out of it because the IP
didn't match `discord.com`. The guess was right; the reasoning that rejected it was
built on an inventory I'd assumed was exhaustive and hadn't checked.

Two things follow from that. If you're auditing a binary for network indicators,
`https?://` is not sufficient — hostnames get compiled in bare, and SDK vendors don't
always use the domain their brand suggests. And the fact that `gaming-sdk.com` is an
unbranded, privacy-redacted, Cloudflare-registered domain created in November 2024 is
a reasonable thing to raise with Discord, and no reflection at all on the game that
bundles their SDK.

Notably, `Assembly-CSharp.dll` contains no network hostnames whatsoever. Every byte of
network capability in this application comes from the Steam and Discord SDKs. The
game's own code never names a host.

## What I didn't establish

- I ran this on a live machine with unprivileged monitoring, not in a VM with a
  syscall trace. I have before-and-after filesystem diffs, not a record of every
  transient write.
- Two runs, ninety and a hundred and twenty seconds. Trigger-gated or long-delayed
  behaviour wouldn't appear, and no amount of watching proves absence.
- I read the key hook and the input path exhaustively. I did not read all 20,000
  lines of decompiled game logic; I searched it for the things that would matter
  (`UnityWebRequest`, `Process.Start`, `File.Write*`, `Assembly.Load`,
  `Activator.CreateInstance`, `FromBase64String`, `CryptoStream`) and followed every
  hit to its call site.

## Verdict

Nothing malicious. Every capability maps to a feature the app openly advertises, every
network flow is accounted for, and the component that looks most like a keylogger is
built in the least capable way that still animates a cat — passive tap, no modifiers,
no key-up, and the keycode discarded in the only function that touches it.

The permission prompt is real and worth understanding before you click allow: granting
Accessibility to any app means it can observe your input system-wide, and that trust
is not revocable per-keystroke. But "this app needs a dangerous permission" and "this
app abuses that permission" are separate claims, and the second one has to be
demonstrated rather than assumed. Here it isn't true.

The best thing I got out of it was a reminder that a tidy inventory is the easiest
thing in the world to trust, and that "the data contradicts my list" should send you
back to check how the list was built before you go looking for an anomaly.
