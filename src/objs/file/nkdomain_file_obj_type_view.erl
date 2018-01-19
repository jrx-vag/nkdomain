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

%% @doc File View Object

-module(nkdomain_file_obj_type_view).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-export([view/2, fields/0, sort_field/1, filter_field/3, entry/2, element_updated/3]).

-include("nkdomain.hrl").
-include("nkdomain_admin.hrl").
-include_lib("nkadmin/include/nkadmin.hrl").

%% @doc
view(Path, _Session) ->
    #{
        columns => [
            #{
                id => checkbox,
                type => checkbox
            },
            #{
                id => domain,
                type => text,
                name => domain_column_domain,
                sort => true,
                is_html => true,
                options => get_agg_name(<<"domain_id">>, Path)
            },
            #{
                id => obj_name,
                type => text,
                fillspace => <<"0.5">>,
                name => domain_column_id,
                sort => true,
                is_html => true % Will allow us to return HTML inside the column data
            },
            #{
                id => name,
                type => text,
                name => domain_column_name,
                sort => true,
                editor => text
            },
            #{
                id => file_type,
                type => text,
                fillspace => <<"0.5">>,
                name => domain_column_type,
                options => get_agg_term(<<"file.content_type">>, Path),
                sort => true
            },
            #{
                id => file_size,
                type => text,
                fillspace => <<"0.5">>,
                name => domain_column_size,
                sort => true
            },
            #{
                id => store_id,
                type => text,
                name => domain_column_store_id,
                fillspace => <<"0.5">>,
                options => get_agg_name(<<"file.store_id">>, Path),
                sort => true,
                is_html => true
            },
            #{
                id => created_by,
                type => text,
                name => domain_column_created_by,
                sort => true,
                options => get_agg_name(<<"created_by">>, Path),
                is_html => true % Will allow us to return HTML inside the column data
            },
            #{
                id => created_time,
                type => date,
                name => domain_column_created_time,
                sort => true
            }
        ],
        left_split => 1,
        on_click => []
    }.


%% @doc
fields() ->
    [
        <<"path">>,
        <<"obj_name">>,
        <<"name">>,
        <<"created_time">>,
        <<"created_by">>,
        <<"enabled">>,
        <<"file.content_type">>,
        <<"file.size">>,
        <<"file.store_id">>
    ].


%% @doc
sort_field(<<"type">>) -> <<"file.content_type">>;
sort_field(<<"size">>) -> <<"file.size">>;
sort_field(_) -> <<>>.


%% @doc
filter_field(<<"file_type">>, Data, Acc) ->
    nkdomain_admin_util:add_filter(<<"file.content_type">>, Data, Acc);
filter_field(<<"file_size">>, Data, Acc) ->
    nkdomain_admin_util:add_search_filter(<<"file.size">>, Data, Acc);
filter_field(_Field, _Data, Acc) ->
    Acc.


%% @doc
entry(Entry, Base) ->
    #{
        ?DOMAIN_FILE := #{
            <<"content_type">> := Type,
            <<"size">> := Size,
            <<"store_id">> := StoreId
        }
    } = Entry,
    Size2 = <<(nklib_util:to_binary(Size div 1024))/binary, "KB">>,
    Base#{
        file_type => Type,
        file_size => Size2,
        store_id => nkdomain_admin_util:obj_id_url(StoreId)
    }.


%% @private
element_updated(_ObjId, Value, _Session) ->
    #{
        <<"name">> := Name
    } = Value,
    Update = #{
        ?DOMAIN_FILE => #{
            name => Name
        }
    },
    {ok, Update}.


%% @private
get_agg_name(Field, Path) ->
    nkdomain_admin_util:get_agg_name(Field, ?DOMAIN_FILE, Path).



%% @private
get_agg_term(Field, Path) ->
    nkdomain_admin_util:get_agg_term(Field, ?DOMAIN_FILE, Path).

