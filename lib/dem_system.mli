open Core.Std
open Async.Std
open Cohttp_async

(** Provides a very, very simple, thin, restful wrapper on top of
    Cohttp. This should allow fairly straight forward creating of restful
    services on top of the base cohttp layer *)

type 'state t

type params = Ouija.params

type ('state) handler = body:Cohttp_async.Body.t ->
  Socket.Address.Inet.t ->
  'state ->
  params ->
  Request.t ->
  ('state * Server.response) Deferred.t with sexp_of

val get : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t
(** Get based REST actions. The rest actions `list` and `retrieve`
    are simple aliases that exist for readability *)

val list : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t
val retrieve : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t

val head : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t
val delete : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t

val post : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t
(** Post based REST actions. `create` is an alias that exists for readability *)

val create : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t

val put : 'state t -> route:String.t -> init:'state -> handler:'state handler ->  'state t
(** Put based REST actions. `replace` is an alias that exists for readability *)

val replace : 'state t -> route:String.t -> init:'state -> handler:'state handler ->  'state t

val patch : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t
val options : 'state t -> route:String.t -> init:'state -> handler:'state handler -> 'state t
val set_routing_error_handler: 'state t -> init:'state -> handler:'state handler -> 'state t

val init: default:'state -> 'state t

val serve: ?listen_on:String.t ->
  ?max_connections:Int.t ->
  ?max_pending_connections:Int.t ->
  ?on_handler_error:[ `Call of Socket.Address.Inet.t -> Exn.t -> Unit.t
                    | `Ignore
                    | `Raise ] ->
  'state t ->
  Int.t ->
  ((Socket.Address.Inet.t, Int.t) Cohttp_async.Server.t Deferred.t)
