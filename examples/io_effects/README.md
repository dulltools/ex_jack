# IoEffects

```
$ iex -S mix
> IoEffects.Supervisor.start_link([])
# Open up QJackCTL and connect System Capture with IoEffects:in
# The following will delay input microphone by 2 seconds, best experienced
# with headphones to avoid feedback. Make sure to start at 0 volume and slowly
# increase it. Safety first!
> IoEffects.delay(2_000)
```
