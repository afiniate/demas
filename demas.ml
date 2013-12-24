open Core.Std
open Async.Std
open Async_extra
open Cohttp
open Cohttp_async

type params = Ouija.params

type auth_result = Authorized
                 | Halt of Server.response Deferred.t

type auth_handler = body:string Pipe.Reader.t option ->
               Socket.Address.Inet.t ->
               params ->
               Request.t ->
               auth_result with sexp_of

type handler = body:string Pipe.Reader.t option ->
               Socket.Address.Inet.t ->
               params ->
               Request.t ->
               Server.response Deferred.t with sexp_of

type target = auth_handler Option.t * handler with sexp_of

type t = {get: target Ouija.t;
          head: target Ouija.t;
          delete: target Ouija.t;
          post: target Ouija.t;
          put: target Ouija.t;
          patch: target Ouija.t;
          options: target Ouija.t;
          authorizer: auth_handler Option.t;
          routing_error_handler: handler Option.t} with sexp_of

let insert_handler ouija uri_spec ?authorizer handler =
  Ouija.insert_handler ouija uri_spec (authorizer, handler)

let get sys uri_spec ?authorizer handler =
  {sys with get = insert_handler sys.get uri_spec ?authorizer handler}

let head sys uri_spec ?authorizer handler =
  {sys with head = insert_handler sys.head uri_spec ?authorizer handler}

let delete sys uri_spec ?authorizer handler =
  {sys with delete = insert_handler sys.delete uri_spec ?authorizer handler}

let post sys uri_spec ?authorizer handler =
  {sys with post = insert_handler sys.post uri_spec ?authorizer handler}

let put sys uri_spec ?authorizer handler =
  {sys with put = insert_handler sys.put uri_spec ?authorizer handler}

let patch sys uri_spec ?authorizer handler =
  {sys with patch = insert_handler sys.patch uri_spec ?authorizer handler}

let options sys uri_spec ?authorizer handler =
  {sys with options = insert_handler sys.options uri_spec ?authorizer handler}

let set_authorization_handler sys handler =
  {sys with authorizer = Some handler}

let set_routing_error_handler sys error_handler =
  {sys with routing_error_handler = Some error_handler}

let base_system = {get = Ouija.init '/';
                   head = Ouija.init '/';
                   delete = Ouija.init '/';
                   post = Ouija.init '/';
                   put = Ouija.init '/';
                   patch = Ouija.init '/';
                   options = Ouija.init '/';
                   authorizer = None;
                   routing_error_handler = None}

let default_error_handler ~body address req =
  ignore body;
  ignore address;
  ignore req;
  Server.respond_with_string ~headers:(Header.init ()) ~code:(`Code 404)
                             "Route not found"

let error_handler sys ~body address params req =
  match sys.routing_error_handler with
  | Some handler ->
     handler ~body address params req
  | None ->
     default_error_handler ~body address req

let get_node sys req =
  match Request.meth req with
  | `GET -> sys.get
  | `POST -> sys.post
  | `HEAD -> sys.head
  | `DELETE -> sys.delete
  | `PATCH -> sys.patch
  | `PUT -> sys.put
  | `OPTIONS -> sys.options

let handle_auth authorizer handler ~body address params (req:Cohttp.Request.t) =
  match authorizer ~body address params req with
  | Authorized ->
     handler ~body address params req
  | Halt resp ->
     resp

let handler sys handler_group  =
  match handler_group with
  | (Some local_auth, handler) ->
     handle_auth local_auth handler
  | (None, handler) ->
     (match sys.authorizer with
      | Some global_auth ->
         handle_auth global_auth handler
      | None ->
         handler)

let server sys ~body address req =
  let uri = Uri.path (Request.uri req) in
  let node = get_node sys req in
  match Ouija.resolve_path node uri with
  | [] -> error_handler sys ~body address [] req
  | (params, handler_group)::_ -> (handler sys handler_group) ~body address params req

let listen_to_any port =
  Tcp.Where_to_listen.create
    ~socket_type:Socket.Type.tcp
    ~address:(Socket.Address.Inet.create_bind_any ~port:port)
    ~listening_on:(fun (`Inet (_, port)) -> port)

let listen_to_ip ip port =
  Tcp.Where_to_listen.create
    ~socket_type:Socket.Type.tcp
    ~address:(Socket.Address.Inet.create (Unix.Inet_addr.of_string ip)
                                         ~port:port)
    ~listening_on:(fun (`Inet (_, port)) -> port)

let serve ?listen_on
          ?(max_connections = 10)
          ?(max_pending_connections = 10)
          ?(on_handler_error = `Raise)
          system port =
  let listen_target = match listen_on with
    | Some ip -> listen_to_ip ip port
    | None -> listen_to_any port in
  Server.create ~max_connections
                ~max_pending_connections
                ~on_handler_error
                listen_target (server system)


let to_string system =
  Sexp.to_string (sexp_of_t system)
