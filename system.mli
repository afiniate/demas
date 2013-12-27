open Core.Std
open Async.Std
open Cohttp_async

type ('a) t

type params = Ouija.params

type ('a) auth_data = 'a Option.t

type ('a) auth_result = Authorized of 'a auth_data
                      | Halt of Server.response Deferred.t

type ('a) auth_handler = body:string Pipe.Reader.t option ->
                         Socket.Address.Inet.t ->
                         params ->
                         Request.t ->
                         'a auth_result with sexp_of

type ('a) handler = body:string Pipe.Reader.t option ->
                    auth_data:'a auth_data ->
                    Socket.Address.Inet.t ->
                    params ->
                    Request.t ->
                    Server.response Deferred.t with sexp_of

val get : 'a t -> route:string -> ?authorizer:'a auth_handler -> handler:'a handler -> 'a t
val head : 'a t -> route:string -> ?authorizer:'a auth_handler -> handler:'a handler -> 'a t
val delete : 'a t -> route:string -> ?authorizer:'a auth_handler -> handler:'a handler -> 'a t
val post : 'a t -> route:string -> ?authorizer:'a auth_handler -> handler:'a handler -> 'a t
val put : 'a t -> route:string -> ?authorizer:'a auth_handler -> handler:'a handler ->  'a t
val patch : 'a t -> route:string -> ?authorizer:'a auth_handler -> handler:'a handler -> 'a t
val options : 'a t -> route:string -> ?authorizer:'a auth_handler -> handler:'a handler -> 'a t
val set_authorization_handler: 'a t -> authorizer:'a auth_handler -> 'a t
val set_routing_error_handler: 'a t -> handler:'a handler -> 'a t

val empty: unit -> 'a t

val serve: ?listen_on:string ->
           ?max_connections:int ->
           ?max_pending_connections:int ->
           ?on_handler_error:[ `Call of Socket.Address.Inet.t -> exn -> unit
                             | `Ignore
                             | `Raise ] ->
           'a t ->
           int ->
           ((Socket.Address.Inet.t, int) Cohttp_async.Server.t Deferred.t)
