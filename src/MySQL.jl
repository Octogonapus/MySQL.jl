module MySQL

using Dates, DBInterface, Tables, Parsers, DecFP

export DBInterface

# For non-C-api errors that happen in MySQL.jl
struct MySQLInterfaceError
    msg::String
end
Base.showerror(io::IO, e::MySQLInterfaceError) = print(io, e.msg)

include("api/API.jl")
using .API

mutable struct Connection <: DBInterface.Connection
    mysql::API.MYSQL
    host::String
    user::String
    port::String
    db::String
    lastexecute::Any

    function Connection(host::String, user::String, passwd::String, db::String, port::Integer, unix_socket::String; kw...)
        mysql = API.init()
        API.setoption(mysql, API.MYSQL_PLUGIN_DIR, API.PLUGIN_DIR)
        API.setoption(mysql, API.MYSQL_SET_CHARSET_NAME, "utf8mb4")
        client_flag = clientflags(; kw...)
        setoptions!(mysql; kw...)
        mysql = API.connect(mysql, host, user, passwd, db, port, unix_socket, client_flag)
        return new(mysql, host, user, string(port), db, nothing)
    end
end

function Base.show(io::IO, conn::Connection)
    opts = conn.mysql.ptr == C_NULL ? "disconnected" :
        "host=\"$(conn.host)\", user=\"$(conn.user)\", port=\"$(conn.port)\", db=\"$(conn.db)\""
    print(io, "MySQL.Connection($opts)")
end

@noinline checkconn(conn::Connection) = conn.mysql.ptr == C_NULL && error("mysql connection has been closed or disconnected")

function clear!(conn)
    conn.lastexecute === nothing || clear!(conn, conn.lastexecute)
    return
end

function clear!(conn, result::API.MYSQL_RES)
    if result.ptr != C_NULL
        while API.fetchrow(conn.mysql, result) != C_NULL
        end
        finalize(result)
    end
    return
end

function clear!(conn, stmt::API.MYSQL_STMT)
    if stmt.ptr != C_NULL
        while API.fetch(stmt) == 0
        end
    end
    return
end

function clientflags(;
        found_rows::Bool=false,
        no_schema::Bool=false,
        compress::Bool=false,
        ignore_space::Bool=false,
        local_files::Bool=false,
        multi_statements::Bool=false,
        multi_results::Bool=false,
        kw...
    )
    flags = UInt64(0)
    if found_rows
        flags |= API.CLIENT_FOUND_ROWS
    elseif no_schema
        flags |= API.CLIENT_NO_SCHEMA
    elseif compress
        flags |= API.CLIENT_COMPRESS
    elseif ignore_space
        flags |= API.CLIENT_IGNORE_SPACE
    elseif local_files
        flags |= API.CLIENT_LOCAL_FILES
    elseif multi_statements
        flags |= API.CLIENT_MULTI_STATEMENTS
    elseif multi_results
        error("CLIENT_MULTI_RESULTS not currently supported by MySQL.jl")
    end
    return flags
end

function setoptions!(mysql;
        init_command::Union{String, Nothing}=nothing,
        connect_timeout::Union{Integer, Nothing}=nothing,
        reconnect::Union{Bool, Nothing}=nothing,
        read_timeout::Union{Integer, Nothing}=nothing,
        write_timeout::Union{Integer, Nothing}=nothing,
        data_truncation::Union{Bool, Nothing}=nothing,
        charset_dir::Union{String, Nothing}=nothing,
        charset_name::Union{String, Nothing}=nothing,
        bind::Union{String, Nothing}=nothing,
        max_allowed_packet::Union{Integer, Nothing}=nothing,
        net_buffer_length::Union{Integer, Nothing}=nothing,
        named_pipe::Union{Bool, Nothing}=nothing,
        protocol::Union{API.mysql_protocol_type, Nothing}=nothing,
        ssl_key::Union{String, Nothing}=nothing,
        ssl_cert::Union{String, Nothing}=nothing,
        ssl_ca::Union{String, Nothing}=nothing,
        ssl_capath::Union{String, Nothing}=nothing,
        ssl_cipher::Union{String, Nothing}=nothing,
        ssl_crl::Union{String, Nothing}=nothing,
        ssl_crlpath::Union{String, Nothing}=nothing,
        passphrase::Union{String, Nothing}=nothing,
        ssl_verify_server_cert::Union{Bool, Nothing}=nothing,
        ssl_enforce::Union{Bool, Nothing}=nothing,
        default_auth::Union{String, Nothing}=nothing,
        connection_handler::Union{String, Nothing}=nothing,
        plugin_dir::Union{String, Nothing}=nothing,
        secure_auth::Union{Bool, Nothing}=nothing,
        server_public_key::Union{String, Nothing}=nothing,
        read_default_file::Union{Bool, Nothing}=nothing,
        option_file::Union{String, Nothing}=nothing,
        read_default_group::Union{Bool, Nothing}=nothing,
        option_group::Union{String, Nothing}=nothing,
        kw...
    )
    if init_command !== nothing
        API.setoption(mysql, API.MYSQL_INIT_COMMAND, init_command)
    elseif connect_timeout !== nothing
        API.setoption(mysql, API.MYSQL_OPT_CONNECT_TIMEOUT, connect_timeout)
    elseif reconnect !== nothing
        API.setoption(mysql, API.MYSQL_OPT_RECONNECT, reconnect)
    elseif read_timeout !== nothing
        API.setoption(mysql, API.MYSQL_OPT_READ_TIMEOUT, read_timeout)
    elseif write_timeout !== nothing
        API.setoption(mysql, API.MYSQL_OPT_WRITE_TIMEOUT, write_timeout)
    elseif data_truncation !== nothing
        API.setoption(mysql, API.MYSQL_REPORT_DATA_TRUNCATION, data_truncation)
    elseif charset_dir !== nothing
        API.setoption(mysql, API.MYSQL_SET_CHARSET_DIR, charset_dir)
    elseif charset_name !== nothing
        API.setoption(mysql, API.MYSQL_SET_CHARSET_NAME, charset_name)
    elseif bind !== nothing
        API.setoption(mysql, API.MYSQL_OPT_BIND, bind)
    elseif max_allowed_packet !== nothing
        API.setoption(mysql, API.MYSQL_OPT_MAX_ALLOWED_PACKET, max_allowed_packet)
    elseif net_buffer_length !== nothing
        API.setoption(mysql, API.MYSQL_OPT_NET_BUFFER_LENGTH, net_buffer_length)
    elseif named_pipe !== nothing
        API.setoption(mysql, API.MYSQL_OPT_NAMED_PIPE, named_pipe)
    elseif protocol !== nothing
        API.setoption(mysql, API.MYSQL_OPT_PROTOCOL, protocol)
    elseif ssl_key !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_KEY, ssl_key)
    elseif ssl_cert !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_CERT, ssl_cert)
    elseif ssl_ca !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_CA, ssl_ca)
    elseif ssl_capath !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_CAPATH, ssl_capath)
    elseif ssl_cipher !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_CIPHER, ssl_cipher)
    elseif ssl_crl !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_CRL, ssl_crl)
    elseif ssl_crlpath !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_CRLPATH, ssl_crlpath)
    elseif passphrase !== nothing
        API.setoption(mysql, API.MARIADB_OPT_TLS_PASSPHRASE, passphrase)
    elseif ssl_verify_server_cert !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_VERIFY_SERVER_CERT, ssl_verify_server_cert)
    elseif ssl_enforce !== nothing
        API.setoption(mysql, API.MYSQL_OPT_SSL_ENFORCE, ssl_enforce)
    elseif default_auth !== nothing
        API.setoption(mysql, API.MYSQL_DEFAULT_AUTH, default_auth)
    elseif connection_handler !== nothing
        API.setoption(mysql, API.MARIADB_OPT_CONNECTION_HANDLER, connection_handler)
    elseif plugin_dir !== nothing
        API.setoption(mysql, API.MYSQL_PLUGIN_DIR, plugin_dir)
    elseif secure_auth !== nothing
        API.setoption(mysql, API.MYSQL_SECURE_AUTH, secure_auth)
    elseif server_public_key !== nothing
        API.setoption(mysql, API.MYSQL_SERVER_PUBLIC_KEY, server_public_key)
    elseif read_default_file !== nothing && read_default_file
        API.setoption(mysql, API.MYSQL_READ_DEFAULT_FILE, C_NULL)
    elseif option_file !== nothing
        API.setoption(mysql, API.MYSQL_READ_DEFAULT_FILE, option_file)
    elseif read_default_group !== nothing && read_default_group
        API.setoption(mysql, API.MYSQL_READ_DEFAULT_GROUP, C_NULL)
    elseif option_group !== nothing
        API.setoption(mysql, API.MYSQL_READ_DEFAULT_GROUP, option_group)
    end
    return
end

"""
    DBInterface.connect(MySQL.Connection, host::String, user::String, passwd::String; db::String="", port::Integer=3306, unix_socket::String=API.MYSQL_DEFAULT_SOCKET, client_flag=API.CLIENT_MULTI_STATEMENTS, opts = Dict())

Connect to a MySQL database with provided `host`, `user`, and `passwd` positional arguments. Supported keyword arguments include:
  * `db::String=""`: attach to a database by default
  * `port::Integer=3306`: connect to the database on a specific port
  * `unix_socket::String`: specifies the socket or named pipe that should be used
  * `found_rows::Bool=false`: Return the number of matched rows instead of number of changed rows
  * `no_schema::Bool=false`: Forbids the use of database.tablename.column syntax and forces the SQL parser to generate an error.
  * `compress::Bool=false`: Use compression protocol
  * `ignore_space::Bool=false`: Allows spaces after function names. All function names will become reserved words.
  * `local_files::Bool=false`: Allows LOAD DATA LOCAL statements
  * `multi_statements::Bool=false`: Allows the client to send multiple statements in one command. Statements will be divided by a semicolon.
  * `multi_results::Bool=false`: currently not supported by MySQL.jl
  * `init_command=""`: Command(s) which will be executed when connecting and reconnecting to the server.
  * `connect_timeout::Integer`: Connect timeout in seconds
  * `reconnect::Bool`: Enable or disable automatic reconnect.
  * `read_timeout::Integer`: Specifies the timeout in seconds for reading packets from the server.
  * `write_timeout::Integer`: Specifies the timeout in seconds for reading packets from the server.
  * `data_truncation::Bool`: Enable or disable reporting data truncation errors for prepared statements
  * `charset_dir::String`: character set files directory
  * `charset_name::String`: Specify the default character set for the connection
  * `bind::String`: Specify the network interface from which to connect to the database, like `"192.168.8.3"`
  * `max_allowed_packet::Integer`: The maximum packet length to send to or receive from server. The default is 16MB, the maximum 1GB.
  * `net_buffer_length::Integer`: The buffer size for TCP/IP and socket communication. Default is 16KB.
  * `named_pipe::Bool`: For Windows operating systems only: Use named pipes for client/server communication.
  * `protocol::MySQL.API.mysql_protocol_type`: Specify the type of client/server protocol. Possible values are: `MySQL.API.MYSQL_PROTOCOL_TCP`, `MySQL.API.MYSQL_PROTOCOL_SOCKET`, `MySQL.API.MYSQL_PROTOCOL_PIPE`, `MySQL.API.MYSQL_PROTOCOL_MEMORY`.
  * `ssl_key::String`: Defines a path to a private key file to use for TLS. This option requires that you use the absolute path, not a relative path. If the key is protected with a passphrase, the passphrase needs to be specified with `passphrase` keyword argument.
  * `passphrase::String`: Specify a passphrase for a passphrase-protected private key, as configured by the `ssl_key` keyword argument.
  * `ssl_cert::String`: Defines a path to the X509 certificate file to use for TLS. This option requires that you use the absolute path, not a relative path.
  * `ssl_ca::String`: Defines a path to a PEM file that should contain one or more X509 certificates for trusted Certificate Authorities (CAs) to use for TLS. This option requires that you use the absolute path, not a relative path.
  * `ssl_capath::String`: Defines a path to a directory that contains one or more PEM files that should each contain one X509 certificate for a trusted Certificate Authority (CA) to use for TLS. This option requires that you use the absolute path, not a relative path. The directory specified by this option needs to be run through the openssl rehash command.
  * `ssl_cipher::String`: Defines a list of permitted ciphers or cipher suites to use for TLS, like `"DHE-RSA-AES256-SHA"`
  * `ssl_crl::String`: Defines a path to a PEM file that should contain one or more revoked X509 certificates to use for TLS. This option requires that you use the absolute path, not a relative path.
  * `ssl_crlpath::String`: Defines a path to a directory that contains one or more PEM files that should each contain one revoked X509 certificate to use for TLS. This option requires that you use the absolute path, not a relative path. The directory specified by this option needs to be run through the openssl rehash command.
  * `ssl_verify_server_cert::Bool`: Enables (or disables) server certificate verification.
  * `ssl_enforce::Bool`: Whether to force TLS
  * `default_auth::String`: Default authentication client-side plugin to use.
  * `connection_handler::String`: Specify the name of a connection handler plugin.
  * `plugin_dir::String`: Specify the location of client plugins. The plugin directory can also be specified with the MARIADB_PLUGIN_DIR environment variable.
  * `secure_auth::Bool`: Refuse to connect to the server if the server uses the mysql_old_password authentication plugin. This mode is off by default, which is a difference in behavior compared to MySQL 5.6 and later, where it is on by default.
  * `server_public_key::String`: Specifies the name of the file which contains the RSA public key of the database server. The format of this file must be in PEM format. This option is used by the caching_sha2_password client authentication plugin.
  * `read_default_file::Bool`: only the default option files are read
  * `option_file::String`: the argument is interpreted as a path to a custom option file, and only that option file is read.
  * `read_default_group::Bool`: only the default option groups are read from specified option file(s)
  * `option_group::String`: it is interpreted as a custom option group, and that custom option group is read in addition to the default option groups.
"""
DBInterface.connect(::Type{Connection}, host::String, user::String, passwd::String; db::String="", port::Integer=3306, unix_socket::String=API.MYSQL_DEFAULT_SOCKET, kw...) =
    Connection(host, user, passwd, db, port, unix_socket; kw...)

"""
    DBInterface.close!(conn::MySQL.Connection)

Close a `MySQL.Connection` opened by `DBInterface.connect`.
"""
function DBInterface.close!(conn::Connection)
    if conn.mysql.ptr != C_NULL
        API.mysql_close(conn.mysql.ptr)
        conn.mysql.ptr = C_NULL
    end
    return
end

Base.close(conn::Connection) = DBInterface.close!(conn)
Base.isopen(conn::Connection) = API.isopen(conn.mysql)

function juliatype(field_type, notnullable, isunsigned)
    T = API.juliatype(field_type)
    T2 = isunsigned ? unsigned(T) : T
    return notnullable ? T2 : Union{Missing, T2}
end

include("execute.jl")
include("prepare.jl")

"""
    MySQL.escape(conn::MySQL.Connection, str::String) -> String

Escapes a string using `mysql_real_escape_string()`, returns the escaped string.
"""
escape(conn::Connection, sql::String) = API.escapestring(conn.mysql, sql)

end # module
