open Core.Std
open Async.Std

(**
 * Read www-form-encoded string
 *)
val read_form: string Pipe.Reader.t ->
               (string * string list) list Deferred.t

val require_or_bad_request: ?body:string ->
                            'a Option.t ->
                            f:('a -> Cohttp_async.Server.response Deferred.t) ->
                            Cohttp_async.Server.response Deferred.t
