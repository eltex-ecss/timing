-module(timing).

-export([
    function/1,
    function/2,
    function/3,
    function/4
]).

-define(N, 20000).
-define(P, 20).

%% public
-spec function(fun()) -> [tuple()].

function(Fun) ->
    function(Fun, ?N).

-spec function(fun(), pos_integer()) -> [tuple()].

function(Fun, N) ->
    function(Fun, N, ?P).

-spec function(fun(), pos_integer(), pos_integer()) -> [tuple()].

function(Fun, N, P) ->
    function(Fun, N, P, []).

-spec function(fun(), pos_integer(), pos_integer(), [proc_lib:spawn_option()]) -> [tuple()].

function(Fun, N, P, Opts) ->
    {ok, R} = hdr_histogram:open(N, 3),
    I = trunc(N / P),
    function_spawn_loop(self(), Fun, I, P, Opts),
    receive_loop(R, P),
    hdr_histogram:log(R, classic, "timing.hgrm"),
    hdr_histogram:close(R).

%% private
function_loop(_Fun, 0) ->
    [];
function_loop(Fun, I) ->
    [function_time(Fun) | function_loop(Fun, I - 1)].

function_spawn_loop(_Pid, _Fun, _I, 0, _Opts) ->
    ok;
function_spawn_loop(Pid, Fun, I, P, Opts) ->
    spawn_opt(fun () -> Pid ! function_loop(Fun, I) end, [link] ++ Opts),
    function_spawn_loop(Pid, Fun, I, P - 1, Opts).

function_time(Fun) ->
    Timestamp = os:timestamp(),
    Fun(),
    timer:now_diff(os:timestamp(), Timestamp).

receive_loop(_R, 0) ->
    ok;
receive_loop(R, N) ->
    receive
        {'EXIT', _Pid, normal} ->
            receive_loop(R, N);
        Times ->
            [hdr_histogram:record(R, Time) || Time <- Times],
            receive_loop(R, N - 1)
    end.
