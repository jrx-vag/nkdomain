%% -------------------------------------------------------------------
%%
%% Copyright (c) 2017 Carlos Gonzalez Florido.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
%%

-module(nkdomain_all_types).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').
-behaviour(gen_server).

-export([get_module/1, get_modules/0, get_submodule/2]).
-export([get_type/1, get_types/0, get_subtype/1]).
-export([register/1]).
-export([get_counters/0, get_counters/1, get_global_counters/0, get_global_counters/1]).
-export([start_link/0]).
-export([init/1, terminate/2, code_change/3, handle_call/3,
         handle_cast/2, handle_info/2]).
-export_type([ets/0]).

-define(LLOG(Type, Txt, Args),
    lager:Type("NkDOMAIN Types "++Txt, Args)).


%% ===================================================================
%% Types
%% ===================================================================




%% ===================================================================
%% Public
%% ===================================================================


%% @doc Finds a type's module
-spec get_module(nkdomain:type()) ->
    module() | undefined.

get_module(Type) when is_binary(Type) ->
    lookup({type, Type}, undefined);

get_module(Type) ->
    get_module(to_bin(Type)).


%% @doc Gets all registered modules
-spec get_modules() ->
    [module()].

get_modules() ->
    lookup(all_modules, []).


%% @doc Finds a subtype's module
-spec get_submodule(nkdomain:type(), nkdomain:subtype()) ->
    module() | undefined.

get_submodule(Type, SubType) when is_binary(Type), is_binary(SubType) ->
    lookup({subtype, Type, SubType}, undefined);

get_submodule(Type, SubType) ->
    get_submodule(to_bin(Type), to_bin(SubType)).


%% @doc Finds a module's type
-spec get_type(module()) ->
    nkdomain:type() | {nkdomain:type(), nkdomain:subtype()} | undefined.

get_type(Module) ->
    case lookup({module, Module}, undefined) of
        Type when is_binary(Type) -> Type;
        _ -> undefined
    end.


%% @doc Gets all registered types
-spec get_types() ->
    [nkdomain:type()].

get_types() ->
    lookup(all_types, []).


%% @doc Finds a module's type
-spec get_subtype(module()) ->
    nkdomain:type() | {nkdomain:type(), nkdomain:subtype()} | undefined.

get_subtype(Module) ->
    case lookup({module, Module}, undefined) of
        {Type, SubType} -> {Type, SubType};
        _ -> undefined
    end.


%% @doc Gets the obj module for a type or subtype
-spec register(module()) ->
    ok.

register(Module) ->
    #{type:=Type} = Info = Module:object_get_info(),
    Type2 = to_bin(Type),
    % Ensure we have the corresponding atom loaded
    _ = binary_to_atom(Type2, utf8),
    Module2 = maps:get(module, Info, Module),
    case maps:find(subtype, Info) of
        error ->
            gen_server:call(?MODULE, {register_type, Type2, Module2});
        {ok, SubType} ->
            SubType2 = to_bin(SubType),
            _ = binary_to_atom(SubType2, utf8),
            gen_server:call(?MODULE, {register_subtype, Type2, SubType2, Module2})
    end.


get_counters() ->
    do_get_counters(false).

get_counters(Domain) ->
    do_get_counters(to_bin(Domain), false).


get_global_counters() ->
    do_get_counters(true).

get_global_counters(Domain) ->
    do_get_counters(to_bin(Domain), true).


%% @private
do_get_counters(Global) ->
    Modules = get_modules(),
    lists:foldl(
        fun(Module, Acc) ->
            {ok, Counters} = case Global of
                true -> nkdomain_type:get_counters(Module);
                false -> nkdomain_type:get_global_counters(Module)
            end,
            #{type:=Type} = Module:object_get_info(),
            lists:foldl(
                fun({Domain, Counter}, Acc2) ->
                    DomainMap = maps:get(Domain, Acc2, #{}),
                    OldCounter =  maps:get(Type, DomainMap, 0),
                    Acc2#{Domain => DomainMap#{Type=>OldCounter+Counter}}
                end,
                Acc,
                maps:to_list(Counters))
        end,
        #{},
        Modules).


%% @private
do_get_counters(Domain, Global) ->
    Modules = get_modules(),
    lists:foldl(
        fun(Module, Acc) ->
            {ok, Counter} = case Global of
                true -> nkdomain_type:get_counters(Module, Domain);
                false -> nkdomain_type:get_global_counters(Module, Domain)
            end,
            case Counter of
                0 ->
                    Acc;
                _ ->
                    #{type:=Type} = Module:object_get_info(),
                    OldCounter =  maps:get(Type, Acc, 0),
                    Acc#{Type=>OldCounter+Counter}
            end
        end,
        #{},
        Modules).


% ===================================================================
%% gen_server behaviour
%% ===================================================================

%% @private
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-type ets() ::
    {all_modules, [module()]} |
    {all_types, [nkdomain:type()]} |
    {{type, nkdomain:type()}, module()} |
    {{subtype, nkdomain:type(), nkdomain:subtype()}, module()} |
    {{module, module()}, nkdomain:type()} |
    {{module, module()}, {nkdomain:type(), nkdomain:subtype()}}.

-record(type, {

}).

-record(state, {
    types = #{} :: #{nkdomain:type() => #type{}}


}).


%% @private
-spec init(term()) ->
    {ok, #state{}} | {error, term()}.

init([]) ->
    ets:new(?MODULE, [named_table, public, {read_concurrency, true}]),
    {ok, #state{}}.


%% @private
-spec handle_call(term(), {pid(), term()}, #state{}) ->
    {noreply, #state{}} | {reply, term(), #state{}} |
    {stop, Reason::term(), #state{}} | {stop, Reason::term(), Reply::term(), #state{}}.

handle_call({register_type, Type, Module}, _From, #state{types=Types}=State) ->
    AllModules1 = get_modules(),
    AllModules2 = lists:usort([Module|AllModules1]),
    AllTypes1 = get_types(),
    AllTypes2 = lists:usort([Type|AllTypes1]),
    ets:insert(?MODULE, [
        {all_modules, AllModules2},
        {all_types, AllTypes2},
        {{type, Type}, Module},
        {{module, Module}, Type}
    ]),
    State2 = case maps:is_key(Type, Types) of
        false ->
            {ok, _} = nkdomain_types_sup:add_type(Module),
            Types2 = Types#{Type=>Module},
            State#state{types=Types2};
        true ->
            State
    end,
    {reply, ok, State2};

handle_call({register_subtype, Type, SubType, Module}, _From, State) ->
    ets:insert(?MODULE, [
        {{subtype, Type, SubType}, Module},
        {{module, Module}, {Type, SubType}}
    ]),
    {reply, ok, State};


handle_call(Msg, _From, State) ->
    lager:error("Module ~p received unexpected call ~p", [?MODULE, Msg]),
    {noreply, State}.


%% @private
-spec handle_cast(term(), #state{}) ->
    {noreply, #state{}} | {stop, term(), #state{}}.

handle_cast(Msg, State) ->
    lager:error("Module ~p received unexpected cast ~p", [?MODULE, Msg]),
    {noreply, State}.


%% @private
-spec handle_info(term(), #state{}) ->
    {noreply, #state{}} | {stop, term(), #state{}}.

handle_info(Info, State) ->
    lager:warning("Module ~p received unexpected info: ~p (~p)", [?MODULE, Info, State]),
    {noreply, State}.


%% @private
-spec code_change(term(), #state{}, term()) ->
    {ok, #state{}}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% @private
-spec terminate(term(), #state{}) ->
    ok.

terminate(_Reason, _State) ->
    ok.



%% ===================================================================
%% Internal
%% ===================================================================

%% @private
lookup(Term, Empty) ->
    case ets:lookup(?MODULE, Term) of
        [] -> Empty;
        [{_, Val}] -> Val
    end.


%% @private
to_bin(Term) -> nklib_util:to_binary(Term).