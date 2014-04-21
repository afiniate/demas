open Core.Std
open Async.Std
open Cohttp_async

type 'state t

type params = Ouija.params

type ('state) handler = body:Cohttp_async.Body.t ->
                        Socket.Address.Inet.t ->
                        'state ->
                        params ->
                        Request.t ->
                        ('state * Server.response) Deferred.t with sexp_of

(** Get based REST actions. The rest actions `list` and `retrieve`
are simple aliases that exist for deadability *)
val get : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t
val list : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t
val retrieve : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t

val head : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t
val delete : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t

(** Post based REST actions. `create` is an alias that exists for readability *)
val post : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t
val create : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t

(** Put based REST actions. `replace` is an alias that exists for readability *)
val put : 'state t -> route:string -> init:'state -> handler:'state handler ->  'state t
val replace : 'state t -> route:string -> init:'state -> handler:'state handler ->  'state t

val patch : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t
val options : 'state t -> route:string -> init:'state -> handler:'state handler -> 'state t
val set_routing_error_handler: 'state t -> init:'state -> handler:'state handler -> 'state t

val init: default:'state -> 'state t

val serve: ?listen_on:string ->
           ?max_connections:int ->
           ?max_pending_connections:int ->
           ?on_handler_error:[ `Call of Socket.Address.Inet.t -> exn -> unit
                             | `Ignore
                             | `Raise ] ->
           'state t ->
           int ->
           ((Socket.Address.Inet.t, int) Cohttp_async.Server.t Deferred.t)
