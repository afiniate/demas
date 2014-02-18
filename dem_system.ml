open Core.Std
open Async.Std
open Async_extra
open Cohttp
open Cohttp_async

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

type ('a) target = 'a auth_handler Option.t * 'a handler with sexp_of

type ('a) t = {get: 'a target Ouija.t;
               head: 'a target Ouija.t;
               delete: 'a target Ouija.t;
               post: 'a target Ouija.t;
               put: 'a target Ouija.t;
               patch: 'a target Ouija.t;
               options: 'a target Ouija.t;
               authorizer: 'a auth_handler Option.t;
               routing_error_handler: 'a handler Option.t} with sexp_of

let insert_handler ouija route ?authorizer handler =
  Ouija.insert_handler ouija route (authorizer, handler)

let get sys ~route ?authorizer ~handler =
  {sys with get = insert_handler sys.get route ?authorizer handler}

let head sys ~route ?authorizer ~handler =
  {sys with head = insert_handler sys.head route ?authorizer handler}

let delete sys ~route ?authorizer ~handler =
  {sys with delete = insert_handler sys.delete route ?authorizer handler}

let post sys ~route ?authorizer ~handler =
  {sys with post = insert_handler sys.post route ?authorizer handler}

let put sys ~route ?authorizer ~handler =
  {sys with put = insert_handler sys.put route ?authorizer handler}

let patch sys ~route ?authorizer ~handler =
  {sys with patch = insert_handler sys.patch route ?authorizer handler}

let options sys ~route ?authorizer ~handler =
  {sys with options = insert_handler sys.options route ?authorizer handler}

let set_authorization_handler sys ~authorizer =
  {sys with authorizer = Some authorizer}

let set_routing_error_handler sys ~handler =
  {sys with routing_error_handler = Some handler}

let empty () = {get = Ouija.init '/';
                head = Ouija.init '/';
                delete = Ouija.init '/';
                post = Ouija.init '/';
                put = Ouija.init '/';
                patch = Ouija.init '/';
                options = Ouija.init '/';
                authorizer = None;
                routing_error_handler = None}

let default_error_handler ~body auth_data address req =
  ignore auth_data;
  ignore body;
  ignore address;
  ignore req;
  Server.respond_with_string ~headers:(Header.init ()) ~code:(`Code 404)
                             "Route not found"

let error_handler sys ~body address params req =
  match sys.routing_error_handler with
  | Some handler ->
     handler ~body ~auth_data:None address params req
  | None ->
     (default_error_handler ~body None address req)

let get_node sys req =
  match Request.meth req with
  | `GET -> sys.get
  | `POST -> sys.post
  | `HEAD -> sys.head
  | `DELETE -> sys.delete
  | `PATCH -> sys.patch
  | `PUT -> sys.put
  | `OPTIONS -> sys.options

let handle_auth authorizer handler ~body address params req =
  match authorizer ~body address params req with
  | Authorized auth_data ->
     handler ~body ~auth_data address params req
  | Halt resp ->
     resp

let handler sys (handler_group:'a auth_handler Option.t * 'a handler)  =
  match handler_group with
  | (Some local_auth, body_handler) ->
     handle_auth local_auth body_handler
  | (None, body_handler) ->
     (match sys.authorizer with
      | Some global_auth ->
         handle_auth global_auth body_handler
      | None ->
         body_handler ~auth_data:None)

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
