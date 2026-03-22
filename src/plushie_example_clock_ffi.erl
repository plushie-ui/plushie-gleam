-module(plushie_example_clock_ffi).
-export([localtime_hms/0]).

localtime_hms() ->
    {_, {H, M, S}} = calendar:local_time(),
    {H, M, S}.
