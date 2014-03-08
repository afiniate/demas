open Core.Std
open Async.Std
open Async_extra
open Cohttp
open Cohttp_async

type params = Ouija.params

type handler = body:Cohttp_async.Body.t ->
               Socket.Address.Inet.t ->
               params ->
               Request.t ->
               Server.response Deferred.t with sexp_of

type t = {get: handler Ouija.t;
          head: handler Ouija.t;
          delete: handler Ouija.t;
          post: handler Ouija.t;
          put: handler Ouija.t;
          patch: handler Ouija.t;
          options: handler Ouija.t;
          routing_error_handler: handler Option.t} with sexp_of

let insert_handler ouija route handler =
  Ouija.insert_handler ouija route handler

let get sys ~route ~handler =
  {sys with get = insert_handler sys.get route handler}

let head sys ~route ~handler =
  {sys with head = insert_handler sys.head route handler}

let delete sys ~route ~handler =
  {sys with delete = insert_handler sys.delete route handler}

let post sys ~route ~handler =
  {sys with post = insert_handler sys.post route handler}

let put sys ~route ~handler =
  {sys with put = insert_handler sys.put route handler}

let patch sys ~route ~handler =
  {sys with patch = insert_handler sys.patch route handler}

let options sys ~route ~handler =
  {sys with options = insert_handler sys.options route handler}

let set_routing_error_handler sys ~handler =
  {sys with routing_error_handler = Some handler}

let empty () = {get = Ouija.init '/';
                head = Ouija.init '/';
                delete = Ouija.init '/';
                post = Ouija.init '/';
                put = Ouija.init '/';
                patch = Ouija.init '/';
                options = Ouija.init '/';
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
     (default_error_handler ~body address req)

let get_node sys req =
  match Request.meth req with
  | `GET -> sys.get
  | `POST -> sys.post
  | `HEAD -> sys.head
  | `DELETE -> sys.delete
  | `PATCH -> sys.patch
  | `PUT -> sys.put
  | `OPTIONS -> sys.options

let server sys ~body address req =
  let uri = Uri.path (Request.uri req) in
  let node = get_node sys req in
  match Ouija.resolve_path node uri with
  | [] -> error_handler sys ~body:body address [] req
  | (params, handler)::_ ->
     handler ~body:body address params req

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
