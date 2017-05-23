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

%% @private Main types supervisor
-module(nkdomain_types_sup).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').
-behaviour(supervisor).

-export([add_type/1, init/1, start_link/0]).


%% @doc
add_type(Module) ->
    {ok, _} = supervisor:start_child(?MODULE, [Module]).


%% @private
start_link() ->
    Childs = [#{id=>type, start=>{nkdomain_type, start_link, []}}],
    supervisor:start_link({local, ?MODULE}, ?MODULE, {{simple_one_for_one, 10, 60}, Childs}).


%% @private
init(ChildSpecs) ->
    {ok, ChildSpecs}.

