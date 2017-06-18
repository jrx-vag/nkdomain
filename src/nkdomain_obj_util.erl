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


%% @doc Basic Obj utilities
-module(nkdomain_obj_util).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').
-export([event/2, status/2, search_syntax/1, get_name/1]).
-export([call_type/3]).
-export([link_server_api/3, unlink_server_api/2]).

-include("nkdomain.hrl").



%% ===================================================================
%% Public
%% ===================================================================

%% @doc
event(Event, #?NKOBJ{link_events=Links}=State) ->
    {ok, #?NKOBJ{}=State2} = do_event(Links, Event, State),
    State2.


%% @private
do_event([], Event, #?NKOBJ{srv_id=SrvId}=State) ->
    {ok, #?NKOBJ{}} = SrvId:object_event(Event, State);

do_event([Link|Rest], Event, #?NKOBJ{srv_id=SrvId}=State) ->
    {ok, State2} = SrvId:object_reg_event(Link, Event, State),
    do_event(Rest, Event,  State2).


%% @doc
status(Status, #?NKOBJ{status=Status}=State) ->
    State;

status(Status, State) ->
    State2 = State#?NKOBJ{status=Status},
    event({status, Status}, State2).


%% @doc
search_syntax(Base) ->
    Base#{
        from => {integer, 0, none},
        size => {integer, 0, none},
        sort => {list, binary},
        fields => {list, binary},
        filters => map,
        simple_query => binary,
        simple_query_opts =>
            #{
                fields => {list, binary},
                default_operator => {atom, ['OR', 'AND']}
            }
    }.


%% @doc
get_name(#?NKOBJ{type=Type, obj_id=ObjId, path=Path, obj=Obj}) ->
    {ok, _, ObjName} = nkdomain_util:get_parts(Type, Path),
    #{
        obj_id => ObjId,
        obj_name => ObjName,
        path => Path,
        name => maps:get(name, Obj, ObjName),
        description => maps:get(description, Obj, <<>>),
        icon_id => maps:get(icon_id, Obj, <<>>)
    }.


%% @private
call_type(Fun, Args, Type) ->
    case nkdomain_all_types:get_module(Type) of
        undefined ->
            ok;
        Module ->
            case erlang:function_exported(Module, Fun, length(Args)) of
                true ->
                    case apply(Module, Fun, Args) of
                        continue ->
                            ok;
                        Other ->
                            Other
                    end;
                false ->
                    ok
            end
    end.


%% @doc
link_server_api(Module, ApiPid, State) ->
    % Stop the API Server if we fail abruptly
    ok = nkapi_server:register(ApiPid, {nkdomain_stop, Module, self()}),
    % Monitor the API server, reduce usage count if it fails
    nkdomain_obj:links_add(usage, {nkdomain_api_server, ApiPid}, State).


%% @doc
unlink_server_api(Module, State) ->
    nkdomain_obj:links_iter(
        usage,
        fun
            ({nkdomain_api_server, ApiPid}, _Acc) ->
                nkapi_server:unregister(ApiPid, {nkdomain_stop, Module, self()});
            (_, _Acc) ->
                ok
        end,
        ok,
        State),
    State.






