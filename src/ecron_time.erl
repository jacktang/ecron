%%------------------------------------------------------------------------------
%% @author Ulf Wiger <ulf.wiger@erlang-solutions.com>
%% @doc Ecron counterparts of the built-in time functions.
%%
%% This module wraps the standard time functions, `erlang:localtime()',
%% `erlang:universaltime()', `erlang:now()' and `os:timestamp()'.
%%
%% The reason for this is to enable mocking to simulate time within ecron.
%% @end
%%
-module(ecron_time).
-export([localtime/0,
         universaltime/0,
         now/0,
         timestamp/0]).

-export([next_sec/2, match_date/2, match_date/5]).
-export([expired/2]).
-export([validate/1]).

localtime() ->
    erlang:localtime().

universaltime() ->
    erlang:universaltime().

now() ->
    erlang:now().

timestamp() ->
    os:timestamp().

next_sec({Date, Time}, {S, M, H, _, _, _, _}) ->
    Now  = calendar:datetime_to_gregorian_seconds({Date, Time}),
    Next = calendar:datetime_to_gregorian_seconds({Date, {H, M, S}}),
    case Next > Now of
        true ->
            Next;
        false ->
            Next + 24 * 3600
    end.

expired({Date, Time}, {SS, MM, HH, D, M, Y, _W}) ->
    expired(Date, Time, {Y, M, D}, {HH, MM, SS}).

expired(Date, Time, {Y, M, D} = SD, {HH, MM, SS} = ST) when is_integer(Y), is_integer(M), is_integer(D),
                                                            is_integer(HH), is_integer(MM), is_integer(SS) ->
    {Date, Time} > {SD, ST};
expired(Date, {HH0, MM0, _SS0},  {Y, M, D} = SD, {HH, MM, _SS}) when is_integer(Y), is_integer(M),
                                                                     is_integer(D), is_integer(HH),
                                                                     is_integer(MM) ->
    {Date, HH0, MM0} > {SD, HH, MM};
expired(Date, {HH0, _MM0, _SS0}, {Y, M, D} = SD, {HH, _MM, _SS}) when is_integer(Y), is_integer(M),
                                                                      is_integer(D), is_integer(HH) ->
    {Date, HH0} > {SD, HH};
expired(Date, _Time, {Y, M, D} = SD, _ST) when is_integer(Y), is_integer(M), is_integer(D) ->
    Date > SD;
expired({Y0, M0, _D0}, _Time, {Y, M, _D}, _ST) when is_integer(Y), is_integer(M) ->
    {Y0, M0} > {Y, M};
expired({Y0, _M0, _D0}, _Time, {Y, _M, _D}, _ST) when is_integer(Y) ->
    Y0 > Y;
expired(_Date, _Time, _SD, _ST) ->
    false.

match_date({Date, _Time}, {_SS, _MM, _HH, D, M, Y, W}) ->
    match_date(Date, D, M, Y, W).

match_date({YYYY, MM, DD} = Date, D, M, Y, W) ->
    lists:all(
      fun({Type, Time, Target}) ->
              match(Type, Time, Target)
      end, [{date, {Y, M, D}, Date}, {year, Y, YYYY}, {month, M, MM}, {day, D, DD},
            {week, W, calendar:day_of_the_week(Date)}]).

match(_Type, Date, Date) ->
    true;
match(_Type, D, _Date) when is_integer(D) ->
    false;
match(_Type, D, Date) when is_list(D) ->
    lists:member(Date, D);
match(_Type, '*' , _Date) ->
    true;
match(day, last, _) ->
    true;
match(date, {_Y, _M, last}, {Y0, M0, D0}) ->
    calendar:last_day_of_the_month(Y0, M0) =:= D0;
match(date, _, _) ->
    true;
match(week, weekday, Week) ->
    match(week, [1, 2, 3, 4, 5], Week);
match(week, weekend, Week) ->
    match(week, [6, 7], Week);
match(_Type, _D, _Date) ->
    false.

validate({SS, MM, HH, D, M, Y, W}) ->
    lists:all(
      fun({Type, Time}) ->
              validate(Type, Time)
      end, [{date, {Y, M, D}}, {week, W}, {year, Y}, {month, M}, {day, D},
            {hour, HH}, {minute, MM}, {sec, SS}]);
validate(ScheduleTime) ->
    throw({invalid_value, schedule_time, ScheduleTime}).
    
validate(date, {Year, 2, Day}) when is_integer(Year), is_integer(Day), Day > 0, Day =< 29 ->
    case calendar:is_leap_year(Year) of
        true ->
            true;
        false ->
            case Day of
                29 ->
                    exit({invalid_value, date, {Year, 2, Day}});
                _ ->
                    true
            end
    end;
validate(date, {_Year, 2, Day}) when is_integer(Day), Day > 0, Day =< 29 ->
    true;
validate(date, {_Year, 2, Day}) when is_integer(Day) ->
    exit({invalid_value, date, {2, Day}});
validate(date, {_Year, Month, Day}) when is_integer(Month), is_integer(Day),
                                  Month > 0, Month =< 12, Day > 0 ->
    ShortMonths = [4,6,9,11],
    V = 
        case lists:member(Month, ShortMonths) of
            true  -> Day =< 30;
            false -> Day =< 31
        end,
    case V of
        true ->
            true;
        false ->
            exit({invalid_value, date, {Month, Day}})
    end;
validate(date, _) ->
    true;
validate(week, weekday) ->
    true;
validate(week, weekend) ->
    true;
validate(day, last) ->
    true;
validate(hour, Hour) when is_integer(Hour), Hour >= 0, Hour < 24 ->
    true;
validate(hour, Hour) when is_integer(Hour) ->
    throw({invalid_value, hour, Hour});
validate(minute, Minute) when is_integer(Minute), Minute >= 0, Minute < 60 ->
    true;
validate(minute, Minute) when is_integer(Minute) ->
    false;
validate(second, Second) when is_integer(Second), Second >= 0, Second < 60 ->
    true;
validate(second, Second) when is_integer(Second) ->
    false;
validate(_Type, '*') ->
    true;
validate(_Type, T) when is_integer(T) ->
    true;
validate(Type, Ts) when is_list(Ts) ->
    lists:all(fun(T) -> validate(Type, T) end, Ts);
validate(Type, Value) ->
    throw({invalid_value, Type, Value}).
