%%% ====================================================================
%%% ``The contents of this file are subject to the Erlang Public License,
%%% Version 1.1, (the "License"); you may not use this file except in
%%% compliance with the License. You should have received a copy of the
%%% Erlang Public License along with this software. If not, it can be
%%% retrieved via the world wide web at http://www.erlang.org/.
%%% 
%%% Software distributed under the License is distributed on an "AS IS"
%%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%%% the License for the specific language governing rights and limitations
%%% under the License.
%%% 
%%% The Initial Developer of the Original Code is ProcessOne.
%%% Portions created by ProcessOne are Copyright 2006-2010, ProcessOne
%%% All Rights Reserved.''
%%% This software is copyright 2006-2010, ProcessOne.
%%%
%%% @copyright 2006-2010 ProcessOne
%%% @author Christophe Romain <christophe.romain@process-one.net>
%%%   [http://www.process-one.net/]
%%% @version {@vsn}, {@date} {@time}
%%% @end
%%% ====================================================================

-module(node_hometree_odbc).
-author('christophe.romain@process-one.net').

-include("pubsub.hrl").
-include_lib("exmpp/include/exmpp.hrl").

-behaviour(gen_pubsub_node).

%% API definition
-export([init/3, terminate/2,
	 options/0, features/0,
	 create_node_permission/6,
	 create_node/2,
	 delete_node/1,
	 purge_node/2,
	 subscribe_node/8,
	 unsubscribe_node/4,
	 publish_item/6,
	 delete_item/4,
	 remove_extra_items/3,
	 get_entity_affiliations/2,
	 get_node_affiliations/1,
	 get_affiliation/2,
	 set_affiliation/3,
	 get_entity_subscriptions/2,
	 get_node_subscriptions/1,
	 get_subscriptions/2,
	 set_subscriptions/4,
	 get_pending_nodes/2,
	 get_states/1,
	 get_state/2,
	 set_state/1,
	 get_items/6,
	 get_items/2,
	 get_item/7,
	 get_item/2,
	 set_item/1,
	 get_item_name/3,
	 get_last_items/3,
	 node_to_path/1,
	 path_to_node/1
	]).


init(Host, ServerHost, Opts) ->
    node_flat_odbc:init(Host, ServerHost, Opts).

terminate(Host, ServerHost) ->
    node_flat_odbc:terminate(Host, ServerHost).

options() ->
    [{deliver_payloads, true},
     {notify_config, false},
     {notify_delete, false},
     {notify_retract, true},
     {notify_sub, false},
     {purge_offline, false},
     {persist_items, true},
     {max_items, ?MAXITEMS},
     {subscribe, true},
     {access_model, open},
     {roster_groups_allowed, []},
     {publish_model, publishers},
     {notification_type, headline},
     {max_payload_size, ?MAX_PAYLOAD_SIZE},
     {send_last_published_item, on_sub_and_presence},
     {deliver_notifications, true},
     {presence_based_delivery, false},
     {odbc, true},
     {rsm, true}].

features() ->
    node_flat_odbc:features().

%% use same code as node_flat_odbc, but do not limite node to
%% the home/localhost/user/... hierarchy
%% any node is allowed
create_node_permission(Host, ServerHost, Node, ParentNode, Owner, Access) ->
    node_hometree:create_node_permission(Host, ServerHost, Node, ParentNode, Owner, Access).

create_node(NodeId, Owner) ->
    node_flat_odbc:create_node(NodeId, Owner).

delete_node(Removed) ->
    node_flat_odbc:delete_node(Removed).

subscribe_node(NodeId, Sender, Subscriber, AccessModel, SendLast, PresenceSubscription, RosterGroup, Options) ->
    node_flat_odbc:subscribe_node(NodeId, Sender, Subscriber, AccessModel, SendLast, PresenceSubscription, RosterGroup, Options).

unsubscribe_node(NodeId, Sender, Subscriber, SubID) ->
    node_flat_odbc:unsubscribe_node(NodeId, Sender, Subscriber, SubID).

publish_item(NodeId, Publisher, Model, MaxItems, ItemId, Payload) ->
    node_flat_odbc:publish_item(NodeId, Publisher, Model, MaxItems, ItemId, Payload).

remove_extra_items(NodeId, MaxItems, ItemIds) ->
    node_flat_odbc:remove_extra_items(NodeId, MaxItems, ItemIds).

delete_item(NodeId, Publisher, PublishModel, ItemId) ->
    node_flat_odbc:delete_item(NodeId, Publisher, PublishModel, ItemId).

purge_node(NodeId, Owner) ->
    node_flat_odbc:purge_node(NodeId, Owner).

get_entity_affiliations(Host, Owner) ->
    node_flat_odbc:get_entity_affiliations(Host, Owner).

get_node_affiliations(NodeId) ->
    node_flat_odbc:get_node_affiliations(NodeId).

get_affiliation(NodeId, Owner) ->
    node_flat_odbc:get_affiliation(NodeId, Owner).

set_affiliation(NodeId, Owner, Affiliation) ->
    node_flat_odbc:set_affiliation(NodeId, Owner, Affiliation).

get_entity_subscriptions(Host, Owner) ->
    node_flat_odbc:get_entity_subscriptions(Host, Owner).

get_node_subscriptions(NodeId) ->
    node_flat_odbc:get_node_subscriptions(NodeId).

get_subscriptions(NodeId, Owner) ->
    node_flat_odbc:get_subscriptions(NodeId, Owner).

set_subscriptions(NodeId, Owner, Subscription, SubId) ->
    node_flat_odbc:set_subscriptions(NodeId, Owner, Subscription, SubId).

get_pending_nodes(Host, Owner) ->
    node_flat_odbc:get_pending_nodes(Host, Owner).

get_states(NodeId) ->
    node_flat_odbc:get_states(NodeId).

get_state(NodeId, JID) ->
    node_flat_odbc:get_state(NodeId, JID).

set_state(State) ->
    node_flat_odbc:set_state(State).

get_items(NodeId, From) ->
    node_flat_odbc:get_items(NodeId, From).

get_items(NodeId, JID, AccessModel, PresenceSubscription, RosterGroup, SubId) ->
    node_flat_odbc:get_items(NodeId, JID, AccessModel, PresenceSubscription, RosterGroup, SubId).

get_item(NodeId, ItemId) ->
    node_flat_odbc:get_item(NodeId, ItemId).

get_item(NodeId, ItemId, JID, AccessModel, PresenceSubscription, RosterGroup, SubId) ->
    node_flat_odbc:get_item(NodeId, ItemId, JID, AccessModel, PresenceSubscription, RosterGroup, SubId).

set_item(Item) ->
    node_flat_odbc:set_item(Item).

get_item_name(Host, Node, Id) ->
    node_flat_odbc:get_item_name(Host, Node, Id).

get_last_items(NodeId, From, Count) ->
    node_flat_odbc:get_last_items(NodeId, From, Count).

node_to_path(Node) ->
    node_hometree:node_to_path(Node).

path_to_node(Path) ->
    node_hometree:path_to_node(Path).
