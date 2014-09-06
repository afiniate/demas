open Core.Std
open Async.Std

val read_form: Cohttp_async.Body.t -> (String.t * String.t List.t) List.t Deferred.t
(**
 * Read www-form-encoded string
*)
