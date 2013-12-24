open Core.Std
open Async.Std
open Cohttp_async

type t

type params = (string * string) List.t

type auth_result = Authorized
                 | Halt of Server.response Deferred.t

type auth_handler = body:string Pipe.Reader.t option ->
               Socket.Address.Inet.t ->
               params ->
               Request.t ->
               auth_result

type handler = body:string Pipe.Reader.t option ->
               Socket.Address.Inet.t ->
               params ->
               Request.t ->
               Server.response Deferred.t

val get : t -> string -> ?authorizer:auth_handler -> handler -> t
val head : t -> string -> ?authorizer:auth_handler -> handler -> t
val delete : t -> string -> ?authorizer:auth_handler -> handler -> t
val post : t -> string -> ?authorizer:auth_handler -> handler -> t
val put : t -> string -> ?authorizer:auth_handler -> handler ->  t
val patch : t -> string -> ?authorizer:auth_handler -> handler -> t
val options : t -> string -> ?authorizer:auth_handler -> handler -> t
val set_authorization_handler: t -> auth_handler -> t
val set_routing_error_handler: t -> handler -> t

val base_system: t

val serve: ?listen_on:string ->
           ?max_connections:int ->
           ?max_pending_connections:int ->
           ?on_handler_error:[ `Call of Socket.Address.Inet.t -> exn -> unit
                             | `Ignore
                             | `Raise ] ->
           t ->
           int ->
           ((Socket.Address.Inet.t, int) Cohttp_async.Server.t Deferred.t)

val to_string: t -> string
