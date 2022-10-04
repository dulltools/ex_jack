# ExJack
JACK audio interface for Elixir using Rustler-based NIF.

The purpose of this library is to provide an audio outlet for Elixir through all platforms. However, if you're on Linux, and don't need JACK outright, it's probably preferable to use [ExAlsa](https://github.com/FraihaAV/ex_alsa) and interface with ALSA directly.

## Requirements
```
Tested with:
JACK 2 (see https://github.com/RustAudio/rust-jack)
Elixir 1.12
Rust 1.56.1
```

## Set-up
### OSX
```
brew install jack
brew services start jack

mix test
```

It may help to view what's going with JACK using a GUI like https://qjackctl.sourceforge.io/. If you want to capture sound this is simplest way to connect until an API is added to assist with this.

See GOTCHAS section for working through issues.


## Usage
This is an example of piping your capture to output, be wary of feedback. You have to explicity connect your capture with "ExJackDemo:in", if you're unsure how to do this, install QJackCTL.

```elixir
$ iex -s mix
> ExJack.Server.start_link(%{name: "ExJackDemo"})
> ExJack.Server.set_input_func(fn frames -> ExJack.Server.send_frames(frames) end)
```

## TODO
### Road to stable version 1
The first three are necessary to make this library useable beyond hobby projects.
- [ ] Better support for expected frames per cycle from JACK
- [ ] Handle variable channels with definable sources
- [ ] Handle JACK notifications
- [ ] Handling for cases that drop the JACK client such as underruns.
- [ ] Additional tests in Elixir
- [ ] Additional tests in Rust
- [ ] MCU demo
- [ ] Improve documentation with additional examples
- [ ] Autocorrection for xruns

## GOTCHAS
###  Could not open requested library
You may get something like the following:
```
thread '<unnamed>' panicked at 'called `Result::unwrap()` on an `Err` value: LoadLibraryError("Could not open the requested library: dlopen(libjack.0.dylib, 0x0005): tried: 'libjack.0.dylib' (no such file), '/usr/local/lib/libjack.0.dylib' (no such file), '/usr/lib/libjack.0.dylib' (no such file), '/Users/adrian/Dev/ex_jack/libjack.0.dylib' (no such file)")', src/lib.rs:45:79
note: run with `RUST_BACKTRACE=1` environment variable to display a RUST_BACKTRACE
```

To fix, try the following:
```
$ brew --prefix jack
> /opt/homebrew/opt/jack # this may differ for you, make sure to update the below path if it does...
$ sudo ln -s /opt/homebrew/opt/jack/lib/libjack.0.dylib /usr/local/lib/libjack.0.dylib
```

## Dev
### Releases
Taken from https://hexdocs.pm/rustler_precompiled/precompilation_guide.html#the-release-flow
```
    release a new tag
    push the code to your repository with the new tag: git push origin main --tags
    wait for all NIFs to be built
    run the mix rustler_precompiled.download task (with the flag --all)
    release the package to Hex.pm.
```
