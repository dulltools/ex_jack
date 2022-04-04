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
