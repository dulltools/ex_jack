# ExJack

[![Elixir CI](https://github.com/dulltools/ex_jack/actions/workflows/release.yaml/badge.svg)](https://github.com/dulltools/ex_jack/actions/workflows/release.yaml)
[![Module Version](https://img.shields.io/hexpm/v/ex_jack.svg)](https://hex.pm/packages/ex_jack)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_jack/)
[![Total Download](https://img.shields.io/hexpm/dt/ex_jack.svg)](https://hex.pm/packages/ex_jack)
[![License](https://img.shields.io/hexpm/l/ex_jack.svg)](https://github.com/dulltools/ex_jack/blob/main/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/dulltools/ex_jack.svg)](https://github.com/dulltools/ex_jack/commits/main)

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


## Usage
This is an example of piping your capture to output, be wary of feedback. You have to explicity connect your capture with "ExJackDemo:in", if you're unsure how to do this, install QJackCTL.

```elixir
$ iex -s mix
> ExJack.Server.start_link(%{name: "ExJackDemo"})
> ExJack.Server.set_input_func(fn frames -> ExJack.Server.send_frames(frames) end )
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
