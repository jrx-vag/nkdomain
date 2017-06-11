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

-module(nkdomain_obj_api).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-export([api/3]).

-include("nkdomain.hrl").
-include_lib("nkservice/include/nkservice.hrl").



%% ===================================================================
%% Public
%% ===================================================================

%% @doc
api(<<"create">>, Type, #nkreq{data=Data, srv_id=SrvId, user_id=UserId}=Req) ->
    Module = nkdomain_all_types:get_module(Type),
    case erlang:function_exported(Module, create, 3) of
        true ->
            Name = maps:get(obj_name, Data, <<>>),
            Data2 = Data#{
                type => Type,
                created_by => UserId
            },
            Data3 = maps:remove(obj_name, Data2),
            case get_parent(Data, Req) of
                {ok, Parent} ->
                    Data4 = Data3#{parent_id=>Parent},
                    case Module:create(SrvId, Name, Data4) of
                        {ok, Reply, _Pid} ->
                            {ok, Reply};
                        {error, Error} ->
                            {error, Error}
                    end;
                {error, Error} ->
                    {error, Error}
            end;
        false ->
            {error, not_implemented}
    end;

api(<<"get">>, Type, #nkreq{data=Data, srv_id=SrvId}=Req) ->
    case nkdomain_api_util:get_id(Type, Data, Req) of
        {ok, Id} ->
            case nkdomain_obj_lib:load(SrvId, Id, #{}) of
                #obj_id_ext{pid=Pid} ->
                    case nkdomain_obj:get_obj(Pid) of
                        {ok, Obj} ->
                            {ok, Obj};
                        {error, Error} ->
                            {error, Error}
                    end;
                {error, Error} ->
                    {error, Error}
            end;
        {error, Error} ->
            {error, Error}
    end;

api(<<"delete">>, Type, #nkreq{data=Data, srv_id=SrvId}=Req) ->
    case nkdomain_api_util:get_id(Type, Data, Req) of
        {ok, Id} ->
            case cmd_delete_childs(Data, SrvId, Id) of
                {ok, Num} ->
                    case nkdomain:delete(SrvId, Id) of
                        ok ->
                            {ok, #{deleted=>Num+1}};
                        {error, Error} ->
                            {error, Error}
                    end;
                {error, Error} ->
                    {error, Error}
            end;
        {error, Error} ->
            {error, Error}
    end;

api(<<"update">>, Type, #nkreq{data=Data, srv_id=SrvId}=Req) ->
    case nkdomain_api_util:get_id(Type, Data, Req) of
        {ok, Id} ->
            case nkdomain:update(SrvId, Id, maps:remove(id, Data)) of
                {ok, []} ->
                    {ok, #{}};
                {ok, UnknownFields} ->
                    {ok, #{unknown_fields=>UnknownFields}};
                {error, Error} ->
                    {error, Error}
            end;
        {error, Error} ->
            {error, Error}
    end;

api(<<"enable">>, Type, #nkreq{data=#{enable:=Enable}=Data, srv_id=SrvId}=Req) ->
    case nkdomain_api_util:get_id(Type, Data, Req) of
        {ok, Id} ->
            case nkdomain:enable(SrvId, Id, Enable) of
                ok ->
                    {ok, #{}};
                {error, Error} ->
                    {error, Error}
            end;
        {error, Error} ->
            {error, Error}
    end;

api(<<"find">>, Type, #nkreq{data=Data, srv_id=SrvId}) ->
    Domain = nkdomain_util:get_service_domain(SrvId),
    Filters1 = maps:get(filters, Data, #{}),
    Filters2 = Filters1#{type=>Type},
    Data2 = Data#{filters=>Filters2},
    case nkdomain_domain_obj:find(SrvId, Domain, Data2) of
        {ok, Total, List, _Meta} ->
            {ok, #{total=>Total, data=>List}};
        {error, Error} ->
            {error, Error}
    end;

api(<<"find_all">>, Type, #nkreq{data=Data, srv_id=SrvId}) ->
    Domain = nkdomain_util:get_service_domain(SrvId),
    Filters1 = maps:get(filters, Data, #{}),
    Filters2 = Filters1#{type=>Type},
    Data2 = Data#{filters=>Filters2},
    case nkdomain_domain_obj:find_all(SrvId, Domain, Data2) of
        {ok, Total, List, _Meta} ->
            {ok, #{total=>Total, data=>List}};
        {error, Error} ->
            {error, Error}
    end;

api(<<"wait_for_save">>, Type, #nkreq{data=Data, srv_id=SrvId}=Req) ->
    Time = maps:get(time, Data, 5000),
    case nkdomain_api_util:get_id(Type, Data, Req) of
        {ok, Id} ->
            case nkdomain_obj_lib:find(SrvId, Id) of
                #obj_id_ext{pid=Pid} when is_pid(Pid) ->
                    case nkdomain_obj:wait_for_save(Pid, Time) of
                        ok ->
                            {ok, #{}};
                        {error, Error} ->
                            {error, Error}
                    end;
                #?NKOBJ{} ->
                    {error, object_not_loaded};
                {error, Error} ->
                    {error, Error}
            end;
        {error, Error} ->
            {error, Error}
    end;

api(<<"make_token">>, Type, #nkreq{data=Data, srv_id=SrvId}=Req) ->
    case nkdomain_api_util:get_id(Type, Data, Req) of
        {ok, Id} ->
            case nkdomain_token_obj:create_referred(SrvId, Id, Data, #{}) of
                {ok, Reply, _Pid} ->
                    {ok, Reply};
                {error, Error} ->
                    {error, Error}
            end;
        {error, Error} ->
            {error, Error}
    end;

api(_Cmd, _Type, _Req) ->
    {error, not_implemented}.



%% ===================================================================
%% Private
%% ===================================================================

%% @private
get_parent(Data, Req) ->
    nkdomain_api_util:get_id(?DOMAIN_DOMAIN, parent_id, Data, Req).


%% @private
cmd_delete_childs(#{delete_childs:=true}, SrvId, Id) ->
    nkdomain_store:delete_all_childs(SrvId, Id);

cmd_delete_childs(_Data, _SrvId, _Id) ->
    {ok, 0}.

