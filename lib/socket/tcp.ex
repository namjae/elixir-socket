#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Socket.TCP do
  @moduledoc """
  This module wraps a passive TCP socket using `gen_tcp`.

  ## Options

  When creating a socket you can pass a serie of options to use for it.

  * `:as` sets the kind of value returned by recv, either `:binary` or `:list`,
    the default is `:binary`
  * `:mode` can be either `:passive` or `:active`, default is `:passive`
  * `:automatic` tells it whether to use smart garbage collection or not, when
    passive the default is `true`, when active the default is `false`
  * `:local` must be a keyword list
    - `:address` the local address to use
    - `:port` the local port to use
    - `:fd` an already opened file descriptor to use
  * `:backlog` sets the listen backlog
  * `:watermark` must be a keyword list
    - `:low` defines the `:low_watermark`, see `inet:setopts`
    - `:high` defines the `:high_watermark`, see `inet:setopts`
  * `:version` sets the IP version to use
  * `:options` must be a list of atoms
    - `:keepalive` sets `SO_KEEPALIVE`
    - `:nodelay` sets `TCP_NODELAY`
  * `:packet` see `inet:setopts`
  * `:size` sets the max length of the packet body, see `inet:setopts`

  ## Examples

      server = Socket.TCP.listen!(1337, packet: :line)

      client = server.accept!
      client.send!(client.recv!)
      client.close

  """

  @type t :: record

  defrecordp :socket, port: nil, reference: nil

  @doc """
  Wrap an existing socket.
  """
  @spec wrap(port) :: t
  def wrap(port) do
    socket(port: port)
  end

  @doc """
  Create a TCP socket connecting to the given host and port tuple.
  """
  @spec connect({ Socket.Address.t, :inet.port_number }) :: { :ok, t } | { :error, :inet.posix }
  def connect({ address, port }) do
    connect(address, port)
  end

  @doc """
  Create a TCP socket connecting to the given host and port tuple and options,
  or to the given host and port.
  """
  @spec connect({ Socket.Address.t, :inet.port_number } | Socket.Address.t, Keyword.t | :inet.port_number) :: { :ok, t } | { :error, :inet.posix }
  def connect({ address, port }, options) when is_list(options) do
    connect(address, port, options)
  end

  def connect(address, port) when is_integer(port) do
    connect(address, port, [])
  end

  @doc """
  Create a TCP socket connecting to the given host and port.
  """
  @spec connect(String.t | :inet.ip_address, :inet.port_number)            :: { :ok, t } | { :error, :inet.posix }
  @spec connect(String.t | :inet.ip_address, :inet.port_number, Keyword.t) :: { :ok, t } | { :error, :inet.posix }
  def connect(address, port, options) do
    if is_binary(address) do
      address = binary_to_list(address)
    end

    options = Keyword.put_new(options, :mode, :passive)

    case :gen_tcp.connect(address, port, arguments(options), options[:timeout] || :infinity) do
      { :ok, sock } ->
        reference = if (options[:mode] == :passive and options[:automatic] != false) or
                       (options[:mode] == :active  and options[:automatic] == true) do
          :gen_tcp.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, :tcp, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, socket(port: sock, reference: reference) }

      error ->
        error
    end
  end

  @doc """
  Create a TCP socket connecting to the given host and port tuple, raising if
  an error occurs.
  """
  @spec connect!({ Socket.Address.t, :inet.port_number }) :: t | no_return
  def connect!({ address, port }) do
    connect!(address, port)
  end

  @doc """
  Create a TCP socket connecting to the given host and port tuple and options,
  or to the given host and port, raising if an error occurs.
  """
  @spec connect!({ Socket.Address.t, :inet.port_number } | Socket.Address.t, Keyword.t | :inet.port_number) :: t | no_return
  def connect!({ address, port }, options) when is_list(options) do
    connect!(address, port, options)
  end

  def connect!(address, port) when is_integer(port) do
    connect!(address, port, [])
  end

  @doc """
  Create a TCP socket connecting to the given host and port, raising in case of
  error.
  """
  @spec connect!(String.t | :inet.ip_address, :inet.port_number)            :: t | no_return
  @spec connect!(String.t | :inet.ip_address, :inet.port_number, Keyword.t) :: t | no_return
  def connect!(address, port, options) do
    case connect(address, port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Create a TCP socket listening on an OS chosen port, use `local` to know the
  port it was bound on.
  """
  @spec listen :: { :ok, t } | { :error, :inet.posix }
  def listen do
    listen(0, [])
  end

  @doc """
  Create a TCP socket listening on an OS chosen port using the given options or
  listening on the given port.
  """
  @spec listen(:inet.port_number | Keyword.t) :: { :ok, t } | { :error, :inet.posix }
  def listen(port) when is_integer(port) do
    listen(port, [])
  end

  def listen(options) do
    listen(0, options)
  end

  @doc """
  Create a TCP socket listening on the given port and using the given options.
  """
  @spec listen(:inet.port_number, Keyword.t) :: { :ok, t } | { :error, :inet.posix }
  def listen(port, options) do
    options = Keyword.put(options, :mode, :passive)

    case :gen_tcp.listen(port, arguments(options)) do
      { :ok, sock } ->
        reference = if options[:automatic] != false do
          :gen_tcp.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, :tcp, sock }, Process.whereis(Socket.Manager))
        end

        { :ok, socket(port: sock, reference: reference) }

      error ->
        error
    end
  end

  @doc """
  Create a TCP socket listening on an OS chosen port, use `local` to know the
  port it was bound on, raising in case of error.
  """
  @spec listen! :: t | no_return
  def listen! do
    listen!(0, [])
  end

  @doc """
  Create a TCP socket listening on an OS chosen port using the given options or
  listening on the given port, raising in case of error.
  """
  @spec listen!(:inet.port_number | Keyword.t) :: t | no_return
  def listen!(port) when is_integer(port) do
    listen!(port, [])
  end

  def listen!(options) do
    listen!(0, options)
  end

  @doc """
  Create a TCP socket listening on the given port and using the given options,
  raising in case of error.
  """
  @spec listen!(:inet.port_number, Keyword.t) :: t | no_return
  def listen!(port, options) do
    case listen(port, options) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Accept a new client from a listening socket, optionally passing options.
  """
  @spec accept(t)            :: { :ok, t } | { :error, :inet.posix }
  @spec accept(Keyword.t, t) :: { :ok, t } | { :error, :inet.posix }
  def accept(options // [], socket(port: sock)) do
    options = Keyword.put_new(options, :mode, :passive)

    case :gen_tcp.accept(sock, options[:timeout] || :infinity) do
      { :ok, sock } ->
        reference = if (options[:mode] == :passive and options[:automatic] != false) or
                       (options[:mode] == :active  and options[:automatic] == true) do
          :gen_tcp.controlling_process(sock, Process.whereis(Socket.Manager))
          Finalizer.define({ :close, :tcp, sock }, Process.whereis(Socket.Manager))
        end

        result = if options[:mode] == :active do
          :inet.setopts(sock, [{ :active, true }])
        else
          :ok
        end

        if result == :ok do
          { :ok, socket(port: sock, reference: reference) }
        else
          result
        end

      error ->
        error
    end
  end

  @doc """
  Accept a new client from a listening socket, optionally passing options,
  raising if an error occurs.
  """
  @spec accept!(t)            :: t | no_return
  @spec accept!(Keyword.t, t) :: t | no_return
  def accept!(options // [], self) do
    case accept(options, self) do
      { :ok, socket } ->
        socket

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Set the process which will receive the messages.
  """
  @spec process(pid, t) :: :ok | { :error, :closed | :not_owner | :inet.posix }
  def process(pid, socket(port: port)) do
    :gen_tcp.controlling_process(port, pid)
  end

  @doc """
  Set the process which will receive the messages, raising if an error occurs.
  """
  @spec process!(pid, t) :: :ok | no_return
  def process!(pid, socket(port: port)) do
    case :gen_tcp.controlling_process(port, pid) do
      :ok ->
        :ok

      :closed ->
        raise RuntimeError, message: "the socket is closed"

      :not_owner ->
        raise RuntimeError, message: "the current process isn't the owner"

      code ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Set options of the socket.
  """
  @spec options(Keyword.t, t) :: :ok | { :error, :inet.posix }
  def options(opts, socket(port: port)) do
    :inet.setopts(port, arguments(opts))
  end

  @doc """
  Set options of the socket, raising if an error occurs.
  """
  @spec options!(Keyword.t, t) :: :ok | no_return
  def options!(opts, self) do
    case options(opts, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Return the local address and port.
  """
  @spec local(t) :: { :ok, { :inet.ip_address, :inet.port_number } } | { :error, :inet.posix }
  def local(socket(port: port)) do
    :inet.sockname(port)
  end

  @doc """
  Return the local address and port, raising if an error occurs.
  """
  @spec local!(t) :: { :inet.ip_address, :inet.port_number } | no_return
  def local!(socket(port: port)) do
    case :inet.sockname(port) do
      { :ok, result } ->
        result

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Return the remote address and port.
  """
  @spec remote(t) :: { :ok, { :inet.ip_address, :inet.port_number } } | { :error, :inet.posix }
  def remote(socket(port: port)) do
    :inet.peername(port)
  end

  @doc """
  Return the remote address and port, raising if an error occurs.
  """
  @spec remote!(t) :: { :inet.ip_address, :inet.port_number } | no_return
  def remote!(socket(port: port)) do
    case :inet.peername(port) do
      { :ok, result } ->
        result

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Send a packet through the socket.
  """
  @spec send(iodata, t) :: :ok | { :error, :inet.posix }
  def send(value, socket(port: port)) do
    :gen_tcp.send(port, value)
  end

  @doc """
  Send a packet through the socket, raising if an error occurs.
  """
  @spec send!(iodata, t) :: :ok | no_return
  def send!(value, self) do
    case send(value, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Receive a packet from the socket, following the `:packet` option set at
  creation.
  """
  @spec recv(t) :: { :ok, binary | char_list } | { :error, :inet.posix }
  def recv(socket(port: port)) do
    :gen_tcp.recv(port, 0)
  end

  @doc """
  Receive a packet from the socket, with either the given length or the given
  options.
  """
  @spec recv(non_neg_integer | Keyword.t, t) :: { :ok, binary | char_list } | { :error, :inet.posix }
  def recv(length, socket(port: port)) when is_integer(length) do
    :gen_tcp.recv(port, length)
  end

  def recv(options, self) do
    recv(0, options, self)
  end

  @doc """
  Receive a packet from the socket with the given length and options.
  """
  @spec recv(non_neg_integer, Keyword.t, t) :: { :ok, binary | char_list } | { :error, :inet.posix }
  def recv(length, options, socket(port: port)) do
    if timeout = options[:timeout] do
      :gen_tcp.recv(port, length, timeout)
    else
      :gen_tcp.recv(port, length)
    end
  end

  @doc """
  Receive a packet from the socket, following the `:packet` option set at
  creation, raising if an error occurs.
  """
  @spec recv!(t) :: binary | char_list | no_return
  def recv!(self) do
    case recv(self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Receive a packet from the socket, with either the given length or the given
  options, raising if an error occurs.
  """
  @spec recv!(non_neg_integer | Keyword.t, t) :: binary | char_list | no_return
  def recv!(length_or_options, self) do
    case recv(length_or_options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Receive a packet from the socket with the given length and options, raising
  if an error occurs.
  """
  @spec recv!(non_neg_integer, Keyword.t, t) :: binary | char_list | no_return
  def recv!(length, options, self) do
    case recv(length, options, self) do
      { :ok, packet } ->
        packet

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Shutdown the socket for the given mode.
  """
  @spec shutdown(:read | :write | :both, t) :: :ok | { :error, :inet.posix }
  def shutdown(how, socket(port: sock)) do
    :gen_tcp.shutdown(sock, case how do
      :read  -> :read
      :write -> :write
      :both  -> :read_write
    end)
  end

  @doc """
  Shutdown the socket for the given mode, raising if an error occurs.
  """
  @spec shutdown!(:read | :write | :both, t) :: :ok | no_return
  def shutdown!(how, self) do
    case shutdown(how, self) do
      :ok ->
        :ok

      { :error, code } ->
        raise Socket.Error, code: code
    end
  end

  @doc """
  Close the socket, if smart garbage collection is used, the socket will be
  closed automatically when it's not referenced by anything.
  """
  @spec close(t) :: :ok
  def close(socket(port: port)) do
    :gen_tcp.close(port)
  end

  @doc """
  Get the underlying port wrapped by the socket.
  """
  @spec to_port(t) :: port
  def to_port(socket(port: port)) do
    port
  end

  @doc """
  Convert TCP options to `:inet.setopts` compatible arguments.
  """
  @spec arguments(Keyword.t) :: list
  def arguments(options) do
    args = Socket.arguments(options)

    args = case options[:as] || :binary do
      :list   -> [:list | args]
      :binary -> [:binary | args]
    end

    if options[:size] do
      args = [{ :packet_size, options[:size] } | args]
    end

    if options[:packet] do
      args = [{ :packet, options[:packet] } | args]
    end

    if options[:backlog] do
      args = [{ :backlog, options[:backlog] } | args]
    end

    if watermark = options[:watermark] do
      if watermark[:low] do
        args = [{ :low_watermark, watermark[:low] } | args]
      end

      if watermark[:high] do
        args = [{ :high_watermark, watermark[:high] } | args]
      end
    end

    if local = options[:local] do
      if address = local[:address] do
        if is_binary(address) do
          address = binary_to_list(address)
        end

        args = [{ :ip, Socket.Address.parse(address) } | args]
      end

      if local[:port] do
        args = [{ :port, local[:port] } | args]
      end

      if local[:fd] do
        args = [{ :fd, local[:fd] } | args]
      end
    end

    args = case options[:version] do
      4 -> [:inet | args]
      6 -> [:inet6 | args]

      nil -> args
    end

    if options[:options] do
      if List.member?(options[:options], :keepalive) do
        args = [{ :keepalive, true } | args]
      end

      if List.member?(options[:options], :nodelay) do
        args = [{ :nodelay, true } | args]
      end
    end

    args
  end
end
