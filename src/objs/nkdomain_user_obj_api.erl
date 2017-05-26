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

%% @doc User Object API
-module(nkdomain_user_obj_api).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-export([cmd/3]).


-include("nkdomain.hrl").
-include_lib("nkservice/include/nkservice.hrl").


%% ===================================================================
%% API
%% ===================================================================

%% @doc
cmd(<<"login">>, Req, State) ->
    #nkreq{data=#{id:=User}=Data, srv_id=SrvId, session_id=SessId, session_meta=SessMeta} = Req,
    LoginMeta1 = maps:with([local, remote], SessMeta),
    LoginMeta2 = LoginMeta1#{
        session_id => SessId,
        password => maps:get(password, Data, <<>>),
        login_meta => maps:get(meta, Data, #{}),
        api_server_pid => self()
    },
    case nkdomain_user_obj:login(SrvId, User, LoginMeta2) of
        {ok, UserId, SessId, LoginMeta3} ->
            Reply = #{obj_id=>UserId, session_id=>SessId},
            Domain = nkdomain_api_util:get_domain(#{}, State),
            State2 = nkdomain_api_util:add_id(?DOMAIN_DOMAIN, Domain, State),
            State3 = nkdomain_api_util:add_id(?DOMAIN_USER, UserId, State2),
            State4 = nkdomain_api_util:add_id(?DOMAIN_SESSION, SessId, State3),
            {login, Reply, UserId, LoginMeta3, State4};
        {error, Error} ->
            {error, Error, State}
    end;

cmd(Cmd, Req, State) ->
    nkdomain_obj_api:api(Cmd, ?DOMAIN_USER, Req, State).
