open Core.Std
open Async.Std
open Cohttp_async

type t

type params = Ouija.params

type handler = body:string Pipe.Reader.t option ->
               Socket.Address.Inet.t ->
               params ->
               Request.t ->
               Server.response Deferred.t with sexp_of

val get : t -> route:string -> handler:handler -> t
val head : t -> route:string -> handler:handler -> t
val delete : t -> route:string -> handler:handler -> t
val post : t -> route:string -> handler:handler -> t
val put : t -> route:string -> handler:handler ->  t
val patch : t -> route:string -> handler:handler -> t
val options : t -> route:string -> handler:handler -> t
val set_routing_error_handler: t -> handler:handler -> t

val empty: unit -> t

val serve: ?listen_on:string ->
           ?max_connections:int ->
           ?max_pending_connections:int ->
           ?on_handler_error:[ `Call of Socket.Address.Inet.t -> exn -> unit
                             | `Ignore
                             | `Raise ] ->
           t ->
           int ->
           ((Socket.Address.Inet.t, int) Cohttp_async.Server.t Deferred.t)
