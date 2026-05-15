-module(plushie_package_ffi).
-export([
    package/1,
    default_icon_path/0,
    default_icons_command/2,
    app_name_manifest_line/1,
    platform_manifest_section/1,
    manifest_escape_probe/1,
    portable_handoff_text/1,
    portable_package_command/3,
    package_config_text/0,
    parse_package_config_text/1,
    package_tools_check/2,
    package_target_supported/1
]).
-export([portable_handoff_text/2]).
-include_lib("kernel/include/file.hrl").

package(ProtocolVersion) ->
    try
        do_package(ProtocolVersion),
        {ok, nil}
    catch
        throw:{package_error, Message} ->
            {error, to_bin(Message)};
        Class:Reason:Stack ->
            {error, to_bin(io_lib:format("Package failed: ~p:~p~n~p", [Class, Reason, Stack]))}
    end.

do_package(ProtocolVersion) ->
    require_command("gleam"),

    case has_flag("--write-package-config") of
        true ->
            Path = flag("--package-config", "plushie-package.config.toml"),
            ok = file:write_file(Path, package_config_text()),
            io:format("Wrote ~s~n", [Path]);
        false ->
            _ = archive_tar(),
            package_payload(ProtocolVersion)
    end.

package_payload(ProtocolVersion) ->
    DistDir = flag("--dist-dir", "dist"),
    PayloadDir = filename:join(DistDir, "payload"),
    ArchiveName = flag("--payload-archive", "payload.tar.zst"),
    ArchivePath = filename:join(DistDir, ArchiveName),
    RendererPath = filename:join([PayloadDir, "bin", "plushie-renderer"]),
    RendererKind = flag("--renderer-kind", "stock"),
    RendererSource = flag("--renderer-source", default_renderer_source(RendererKind)),
    AppId = required_flag("--app-id"),
    AppName = optional_flag("--app-name"),
    AppVersion = flag("--app-version", root_string("version", "0.1.0")),
    ConnectModule = required_flag("--connect-module"),
    Target = package_target(),
    assert_package_target_supported(Target),
    HostSdkVersion = host_sdk_version(),
    PlushieRustVersion = plushie_rust_version(),
    StartConfig = package_start_config(),
    assert_renderer_kind_matches_project(RendererKind),

    reset_dir(DistDir),
    ok = filelib:ensure_dir(filename:join([PayloadDir, "bin", "dummy"])),
    ok = filelib:ensure_dir(filename:join([PayloadDir, "shipment", "dummy"])),

    install_renderer(RendererKind, RendererPath),
    build_shipment(PayloadDir),
    maybe_copy_erlang_runtime(PayloadDir),
    write_connect_script(PayloadDir, ConnectModule),
    IconPath = materialize_platform_icon(PayloadDir),

    archive_payload(PayloadDir, ArchivePath),
    PayloadHash = sha256_file(ArchivePath),
    PayloadSize = file_size(ArchivePath),
    Manifest = render_manifest(#{
        app_id => AppId,
        app_name => AppName,
        app_version => AppVersion,
        target => Target,
        host_sdk_version => HostSdkVersion,
        plushie_rust_version => PlushieRustVersion,
        protocol_version => ProtocolVersion,
        renderer_kind => RendererKind,
        renderer_source => RendererSource,
        icon_path => IconPath,
        start_config => StartConfig,
        archive => ArchiveName,
        payload_hash => PayloadHash,
        payload_size => PayloadSize
    }),
    ManifestPath = filename:join(DistDir, "plushie-package.toml"),
    ok = file:write_file(ManifestPath, Manifest),

    io:format("Wrote ~s~n", [ArchivePath]),
    io:format("Wrote ~s~n", [ManifestPath]),
    finish_portable_package(ManifestPath).

finish_portable_package(ManifestPath) ->
    case has_flag("--portable") of
        true ->
            {Command, Args} = portable_package_command(
                ManifestPath,
                optional_flag("--portable-out"),
                has_flag("--strict-tools")
            ),
            _ = run_or_fail(Command, Args),
            ok;
        false ->
            io:format("~s", [portable_handoff_text(ManifestPath, has_flag("--strict-tools"))])
    end.

portable_handoff_text(ManifestPath) ->
    portable_handoff_text(ManifestPath, false).

portable_handoff_text(ManifestPath, StrictTools) ->
    {Command, Args} = portable_package_command(ManifestPath, error, StrictTools),
    to_bin(["Build portable launcher with:\n  ", Command, " ", lists:join(<<" ">>, Args), "\n"]).

portable_package_command(ManifestPath, PortableOut, StrictTools) ->
    Base = [<<"package">>, <<"portable">>, <<"--manifest">>, to_bin(ManifestPath)],
    WithOut = case PortableOut of
        {ok, OutPath} -> Base ++ [<<"--out">>, to_bin(OutPath)];
        {error, _} -> Base;
        error -> Base
    end,
    Args = case StrictTools of
        true -> WithOut ++ [<<"--strict-tools">>];
        false -> WithOut
    end,
    {to_bin(filename:join(["bin", tool_name()])), Args}.

package_start_config() ->
    case optional_flag("--package-config") of
        {ok, Path} ->
            read_package_config(Path);
        error ->
            case filelib:is_regular("plushie-package.config.toml") of
                true -> read_package_config("plushie-package.config.toml");
                false -> default_start_config()
            end
    end.

read_package_config(Path) ->
    case file:read_file(Path) of
        {ok, Content} -> parse_package_config_text_bang(Content);
        {error, Reason} -> fail(["Could not read package config ", Path, ": ", io_lib:format("~p", [Reason])])
    end.

default_start_config() ->
    #{
        working_dir => <<".">>,
        command => [<<"bin/connect">>],
        forward_env => default_forward_env()
    }.

package_config_text() ->
    Cfg = default_start_config(),
    to_bin([
        "# Plushie standalone package config.\n",
        "# Commit this file and edit it when the packaged app needs a\n",
        "# different entry point, working directory, or forwarded environment.\n\n",
        "config_version = 1\n\n",
        "[start]\n",
        "# Relative to the extracted app package.\n",
        "working_dir = \"", maps:get(working_dir, Cfg), "\"\n",
        "# Structured argv. The first item is the packaged host executable.\n",
        "command = ", toml_array(maps:get(command, Cfg)), "\n",
        "# Environment variable names copied from the parent process.\n",
        "forward_env = [\n",
        [[<<"  \"">>, toml_string_escape(Name), <<"\",\n">>] || Name <- maps:get(forward_env, Cfg)],
        "]\n"
    ]).

parse_package_config_text(Text) ->
    try
        Config = parse_package_config_text_bang(Text),
        {ok, {
            maps:get(working_dir, Config),
            maps:get(command, Config),
            maps:get(forward_env, Config)
        }}
    catch
        throw:{package_error, Message} ->
            {error, to_bin(Message)}
    end.

parse_package_config_text_bang(Text) ->
    Content = to_bin(Text),
    case re:run(Content, <<"(?m)^\\s*config_version\\s*=\\s*(\\d+)\\s*$">>, [{capture, [1], binary}]) of
        {match, [<<"1">>]} -> ok;
        {match, [Version]} -> fail(["Unsupported package config config_version ", Version]);
        nomatch -> fail("Package config must include config_version = 1")
    end,
    Start = section(Content, <<"start">>),
    Config = #{
        working_dir => string_field(Start, <<"working_dir">>),
        command => array_field(Start, <<"command">>),
        forward_env => array_field(Start, <<"forward_env">>)
    },
    validate_start_config(Config),
    Config.

section(Text, Name) ->
    Pattern = <<"(?ms)^\\s*\\[", Name/binary, "\\]\\s*$(.*?)(?=^\\s*\\[|\\z)">>,
    case re:run(Text, Pattern, [{capture, [1], binary}]) of
        {match, [Body]} -> Body;
        nomatch -> fail(["Package config must include [", Name, "]"])
    end.

string_field(Section, Name) ->
    Value = field_value(Section, Name),
    case re:run(Value, <<"^\"((?:\\\\.|[^\"\\\\])*)\"$">>, [{capture, [1], binary}]) of
        {match, [Raw]} -> unescape_toml_string(Raw);
        nomatch -> fail(["Package config ", Name, " must be a TOML basic string"])
    end.

array_field(Section, Name) ->
    Value = field_value(Section, Name),
    case {binary:first(Value), binary:last(Value)} of
        {$[, $]} ->
            Matches = re:run(Value, <<"\"((?:\\\\.|[^\"\\\\])*)\"">>, [global, {capture, [1], binary}]),
            validate_array_has_only_strings(Value, Name),
            case Matches of
                {match, Captures} -> [unescape_toml_string(Raw) || [Raw] <- Captures];
                nomatch -> []
            end;
        _ ->
            fail(["Package config ", Name, " must be an array of strings"])
    end.

validate_array_has_only_strings(Value, Name) ->
    WithoutStrings = re:replace(Value, <<"\"(?:\\\\.|[^\"\\\\])*\"">>, <<>>, [global, {return, binary}]),
    case re:run(WithoutStrings, <<"^[\\s,\\[\\]]*$">>) of
        {match, _} -> ok;
        nomatch -> fail(["Package config ", Name, " must be an array of strings"])
    end.

field_value(Section, Name) ->
    Lines = [trim(Line) || Line <- binary:split(Section, <<"\n">>, [global])],
    collect_field(Lines, <<Name/binary, " =">>).

collect_field([], Name) ->
    fail(["Package config [start] must include ", Name]);
collect_field([Line | Rest], Prefix) ->
    case Line of
        <<>> -> collect_field(Rest, Prefix);
        <<"#", _/binary>> -> collect_field(Rest, Prefix);
        _ ->
            case binary:match(Line, Prefix) of
                {0, Size} ->
                    Value = trim(binary:part(Line, Size, byte_size(Line) - Size)),
                    case Value of
                        <<"[", _/binary>> ->
                            case binary:match(Value, <<"]">>) of
                                nomatch -> collect_array(Rest, [Value]);
                                _ -> Value
                            end;
                        _ -> Value
                    end;
                _ ->
                    collect_field(Rest, Prefix)
            end
    end.

collect_array([], _Parts) ->
    fail("Package config array is unterminated");
collect_array([Line | Rest], Parts) ->
    Trimmed = trim(strip_comment(Line)),
    Next = Parts ++ [Trimmed],
    case binary:match(Trimmed, <<"]">>) of
        nomatch -> collect_array(Rest, Next);
        _ -> to_bin(lists:join(<<"\n">>, Next))
    end.

strip_comment(Line) ->
    hd(binary:split(Line, <<"#">>)).

unescape_toml_string(Value) ->
    unescape_toml_string(Value, []).

unescape_toml_string(<<>>, Acc) ->
    to_bin(lists:reverse(Acc));
unescape_toml_string(<<"\\n", Rest/binary>>, Acc) ->
    unescape_toml_string(Rest, [<<"\n">> | Acc]);
unescape_toml_string(<<"\\r", Rest/binary>>, Acc) ->
    unescape_toml_string(Rest, [<<"\r">> | Acc]);
unescape_toml_string(<<"\\t", Rest/binary>>, Acc) ->
    unescape_toml_string(Rest, [<<"\t">> | Acc]);
unescape_toml_string(<<"\\\"", Rest/binary>>, Acc) ->
    unescape_toml_string(Rest, [<<"\"">> | Acc]);
unescape_toml_string(<<"\\\\", Rest/binary>>, Acc) ->
    unescape_toml_string(Rest, [<<"\\">> | Acc]);
unescape_toml_string(<<Char/utf8, Rest/binary>>, Acc) ->
    unescape_toml_string(Rest, [<<Char/utf8>> | Acc]).

validate_start_config(Config) ->
    validate_payload_path(<<"start.working_dir">>, maps:get(working_dir, Config)),
    case maps:get(command, Config) of
        [Program | Args] ->
            validate_payload_path(<<"start.command[0]">>, Program),
            case lists:any(fun(Arg) -> Arg =:= <<>> end, [Program | Args]) of
                true -> fail("Package config start.command must contain a non-empty argv");
                false -> ok
            end;
        _ ->
            fail("Package config start.command must contain a non-empty argv")
    end,
    lists:foreach(fun validate_forward_env/1, maps:get(forward_env, Config)),
    ok.

validate_payload_path(Name, Path) ->
    Parts = filename:split(to_list(Path)),
    case {Path, filename:pathtype(to_list(Path)), lists:member("..", Parts)} of
        {<<>>, _, _} -> fail(["Package config ", Name, " must not be empty"]);
        {_, absolute, _} -> fail(["Package config ", Name, " must be relative to the package"]);
        {_, _, true} -> fail(["Package config ", Name, " must not contain parent traversal"]);
        _ -> ok
    end.

validate_forward_env(Name) ->
    case {trim(Name), binary:match(Name, <<",">>), binary:match(Name, <<"=">>), Name} of
        {<<>>, _, _, _} -> fail("Package config start.forward_env contains invalid environment name");
        {_, {_, _}, _, _} -> fail("Package config start.forward_env contains invalid environment name");
        {_, _, {_, _}, _} -> fail("Package config start.forward_env contains invalid environment name");
        {_, _, _, <<"PLUSHIE_BINARY_PATH">>} -> fail("Package config start.forward_env must not include launcher-owned variables");
        {_, _, _, <<"PLUSHIE_PACKAGE_DIR">>} -> fail("Package config start.forward_env must not include launcher-owned variables");
        {_, _, _, <<"PLUSHIE_PACKAGE_READY_FILE">>} -> fail("Package config start.forward_env must not include launcher-owned variables");
        _ -> ok
    end.

install_renderer(<<"custom">>, RendererPath) ->
    case optional_flag("--renderer-path") of
        {ok, Existing} ->
            copy_executable(Existing, RendererPath);
        error ->
            Args0 = ["run", "-m", "plushie/build", "--", "--bin-file", RendererPath],
            Args = case has_flag("--release") of
                true -> Args0 ++ ["--release"];
                false -> Args0
            end,
            io:format("Building custom renderer...~n", []),
            run_or_fail("gleam", Args)
    end,
    ensure_package_tools_available(),
    make_executable(RendererPath);
install_renderer(<<"stock">>, RendererPath) ->
    Renderer = resolve_stock_renderer(),
    ensure_package_tools_available(),
    copy_executable(Renderer, RendererPath);
install_renderer(Kind, _RendererPath) ->
    fail(["Unsupported renderer kind: ", Kind]).

assert_renderer_kind_matches_project(<<"stock">>) ->
    case has_native_widgets() of
        true -> fail("Native widget packaging requires a custom renderer; requested renderer kind: stock");
        false -> ok
    end;
assert_renderer_kind_matches_project(_) ->
    ok.

has_native_widgets() ->
    case file:read_file("gleam.toml") of
        {ok, Content} ->
            case re:run(Content, <<"(?m)^native_widgets = \\[\\]">>) of
                {match, _} -> false;
                nomatch -> re:run(Content, <<"(?m)^native_widgets = \\[">>) =/= nomatch
            end;
        {error, _} -> false
    end.

resolve_stock_renderer() ->
    case optional_flag("--renderer-path") of
        {ok, Path} ->
            assert_executable(Path),
            Path;
        error ->
            case getenv("PLUSHIE_BINARY_PATH") of
                {ok, Path} ->
                    assert_executable(Path),
                    Path;
                error ->
                    resolve_stock_renderer_without_env()
            end
    end.

resolve_stock_renderer_without_env() ->
    ShipmentRenderer = filename:join(["build", "erlang-shipment", "plushie-renderer"]),
    case is_executable(ShipmentRenderer) of
        true ->
            ShipmentRenderer;
        false ->
            case getenv("PLUSHIE_RUST_SOURCE_PATH") of
                {ok, SourcePath} ->
                    build_stock_renderer(SourcePath);
                error ->
                    sync_stock_renderer()
            end
    end.

sync_stock_renderer() ->
    run_or_fail("gleam", ["run", "-m", "plushie/download"]),
    Renderer = filename:join(["bin", "plushie-renderer"]),
    ensure_package_tools_available(),
    ensure_managed_renderer_available(Renderer),
    Renderer.

ensure_package_tools_available() ->
    Tool = filename:join(["bin", tool_name()]),
    Launcher = filename:join(["bin", launcher_name()]),
    case package_tools_check(Tool, Launcher) of
        {ok, nil} -> ok;
        {error, Missing} ->
            fail(["Portable packaging requires the managed Plushie tool set. Missing: ", lists:join(", ", Missing), ". Run `gleam run -m plushie/download`."])
    end.

ensure_managed_renderer_available(Renderer) ->
    case filelib:is_regular(Renderer) of
        true -> ok;
        false -> fail(["Managed renderer is missing: ", Renderer])
    end.

package_tools_check(Tool, Launcher) ->
    Missing = [Path || Path <- [Tool, Launcher], not filelib:is_regular(Path)],
    case Missing of
        [] -> {ok, nil};
        _ -> {error, Missing}
    end.

tool_name() ->
    executable_name("plushie").

launcher_name() ->
    executable_name("plushie-launcher").

executable_name(Name) ->
    case os:type() of
        {win32, _} -> Name ++ ".exe";
        _ -> Name
    end.

build_stock_renderer(SourcePath) ->
    case filelib:is_regular(filename:join(SourcePath, "Cargo.toml")) of
        true -> ok;
        false -> fail(["PLUSHIE_RUST_SOURCE_PATH does not look like a Rust workspace: ", SourcePath])
    end,
    require_command("cargo"),
    TargetDir = filename:absname(filename:join(["build", "plushie-package-target"])),
    io:format("Building plushie-renderer from ~s~n", [SourcePath]),
    run_or_fail("cargo", [
        "build",
        "--release",
        "-p",
        "plushie-renderer",
        "--manifest-path",
        filename:join(SourcePath, "Cargo.toml"),
        "--target-dir",
        TargetDir
    ]),
    filename:join([TargetDir, "release", "plushie-renderer"]).

build_shipment(PayloadDir) ->
    io:format("Building Erlang shipment...~n", []),
    run_or_fail("gleam", ["export", "erlang-shipment"]),
    ShipmentDir = filename:join(["build", "erlang-shipment"]),
    copy_dir_contents(ShipmentDir, filename:join(PayloadDir, "shipment")).

maybe_copy_erlang_runtime(PayloadDir) ->
    case bundle_erlang() of
        true -> copy_erlang_runtime(PayloadDir);
        false -> io:format("Skipping Erlang runtime bundle; package will require erl on PATH.~n", [])
    end.

bundle_erlang() ->
    case getenv("PLUSHIE_BUNDLE_ERLANG") of
        error -> true;
        {ok, <<"1">>} -> true;
        {ok, <<"true">>} -> true;
        {ok, <<"yes">>} -> true;
        {ok, <<"0">>} -> false;
        {ok, <<"false">>} -> false;
        {ok, <<"no">>} -> false;
        {ok, _} -> fail("PLUSHIE_BUNDLE_ERLANG must be 1 or 0.")
    end.

copy_erlang_runtime(PayloadDir) ->
    Root = erlang_root(),
    RuntimeDir = filename:join([PayloadDir, "runtime", "erlang"]),
    ErtsDir = find_runtime_dir(Root, "erts-*"),
    LibDir = filename:join(Root, "lib"),
    CryptoDir = find_runtime_dir(LibDir, "crypto-*"),
    KernelDir = find_runtime_dir(LibDir, "kernel-*"),
    SaslDir = find_runtime_dir(LibDir, "sasl-*"),
    StdlibDir = find_runtime_dir(LibDir, "stdlib-*"),

    case is_executable(filename:join([Root, "bin", "erl"])) of
        true -> ok;
        false -> fail(["Erlang runtime root has no executable bin/erl: ", Root])
    end,
    case filelib:is_dir(filename:join(Root, "releases")) of
        true -> ok;
        false -> fail(["Erlang runtime root has no releases directory: ", Root])
    end,

    io:format("Bundling Erlang runtime from ~s~n", [Root]),
    ok = filelib:ensure_dir(filename:join([RuntimeDir, "lib", "dummy"])),
    copy_path(filename:join(Root, "bin"), filename:join(RuntimeDir, "bin")),
    copy_path(filename:join(Root, "releases"), filename:join(RuntimeDir, "releases")),
    copy_path(ErtsDir, filename:join(RuntimeDir, filename:basename(ErtsDir))),
    copy_path(CryptoDir, filename:join([RuntimeDir, "lib", filename:basename(CryptoDir)])),
    copy_path(KernelDir, filename:join([RuntimeDir, "lib", filename:basename(KernelDir)])),
    copy_path(SaslDir, filename:join([RuntimeDir, "lib", filename:basename(SaslDir)])),
    copy_path(StdlibDir, filename:join([RuntimeDir, "lib", filename:basename(StdlibDir)])),
    run_or_fail(filename:join([RuntimeDir, "bin", "erl"]), ["-noshell", "-eval", "ok = application:ensure_started(crypto), halt()."]).

erlang_root() ->
    Provider = erlang_provider(),
    Root = erlang_root_option(),
    Version = erlang_version_option(),
    case Provider of
        <<"local">> ->
            case find_executable("erl") of
                {ok, _} ->
                    trim(run_or_fail("erl", ["-noshell", "-eval", "io:format(\"~s~n\", [code:root_dir()]), halt()."]));
                error ->
                    fail("No Erlang runtime found. Install Erlang, use --erlang-provider path with --erlang-root, use --erlang-provider mise, or set PLUSHIE_BUNDLE_ERLANG=0 to package without a runtime.")
            end;
        <<"path">> ->
            case Root of
                {ok, PathRoot} -> PathRoot;
                error -> fail("--erlang-root is required when --erlang-provider path is used.")
            end;
        <<"mise">> ->
            Spec = case Version of
                {ok, ErlangVersion} -> <<"erlang@", ErlangVersion/binary>>;
                error -> <<"erlang">>
            end,
            trim(run_or_fail("mise", ["where", Spec]));
        Other ->
            fail(["Unsupported Erlang runtime provider: ", Other])
    end.

erlang_provider() ->
    case optional_flag("--erlang-provider") of
        {ok, Provider} -> Provider;
        error ->
            case getenv("PLUSHIE_ERLANG_PROVIDER") of
                {ok, Provider} -> Provider;
                error ->
                    case erlang_root_option() of
                        {ok, _} -> <<"path">>;
                        error -> <<"local">>
                    end
            end
    end.

erlang_root_option() ->
    case optional_flag("--erlang-root") of
        {ok, Root} -> {ok, Root};
        error -> getenv("PLUSHIE_ERLANG_ROOT")
    end.

erlang_version_option() ->
    case optional_flag("--erlang-version") of
        {ok, Version} -> {ok, Version};
        error -> getenv("PLUSHIE_ERLANG_VERSION")
    end.

find_runtime_dir(Root, Pattern) ->
    case filelib:wildcard(filename:join(to_list(Root), to_list(Pattern))) of
        [] -> fail(["Erlang runtime is missing ", Pattern, " under ", Root]);
        Dirs -> lists:last(lists:sort(Dirs))
    end.

write_connect_script(PayloadDir, ConnectModule) ->
    Path = filename:join([PayloadDir, "bin", "connect"]),
    Script = [
        "#!/bin/sh\n",
        "set -eu\n",
        "DIR=\"$(CDPATH= cd \"$(dirname \"$0\")/..\" && pwd)\"\n\n",
        "if [ -x \"$DIR/runtime/erlang/bin/erl\" ]; then\n",
        "  ERL=\"$DIR/runtime/erlang/bin/erl\"\n",
        "  unset ERL_ROOTDIR\n",
        "elif command -v erl >/dev/null 2>&1; then\n",
        "  ERL=\"$(command -v erl)\"\n",
        "else\n",
        "  echo \"No Erlang runtime found. Expected $DIR/runtime/erlang/bin/erl or erl on PATH.\" >&2\n",
        "  exit 127\n",
        "fi\n\n",
        "exec \"$ERL\" -pa \"$DIR\"/shipment/*/ebin -eval '", ConnectModule, ":main().' -noshell -extra \"$@\"\n"
    ],
    ok = file:write_file(Path, iolist_to_binary(Script)),
    make_executable(Path).

package_target_supported(Target) ->
    try
        assert_package_target_supported(Target),
        {ok, nil}
    catch
        throw:{package_error, Reason} -> {error, Reason}
    end.

assert_package_target_supported(<<"windows-", _/binary>> = Target) ->
    fail([
        "Windows standalone packaging is not supported by the Gleam SDK yet. ",
        "The current package flow writes a Unix bin/connect wrapper. ",
        "Add a Windows-specific host command before producing ",
        Target,
        " packages."
    ]);
assert_package_target_supported(_) ->
    ok.

materialize_platform_icon(PayloadDir) ->
    AssetsDir = filename:join(PayloadDir, "assets"),
    case optional_flag("--icon") of
        {ok, IconPath} ->
            copy_app_icon(IconPath, AssetsDir);
        error ->
            write_default_icons(AssetsDir),
            default_icon_path()
    end.

copy_app_icon(IconPath, AssetsDir) ->
    case filelib:is_regular(IconPath) of
        true -> ok;
        false -> fail(["Icon path is not a regular file: ", IconPath])
    end,
    Name = filename:basename(IconPath),
    validate_asset_file_name(Name),
    ok = filelib:ensure_dir(filename:join([AssetsDir, "dummy"])),
    Dest = filename:join(AssetsDir, Name),
    copy_path(IconPath, Dest),
    to_bin(filename:join("assets", Name)).

write_default_icons(AssetsDir) ->
    ok = filelib:ensure_dir(filename:join([AssetsDir, "dummy"])),
    SourcePath = getenv("PLUSHIE_RUST_SOURCE_PATH"),
    assert_source_path(SourcePath),
    {Command, Args} = default_icons_command(SourcePath, AssetsDir),
    io:format("Writing default app icons...~n", []),
    _ = run_or_fail(Command, Args),
    ok.

assert_source_path({ok, SourcePath}) ->
    case filelib:is_regular(filename:join(SourcePath, "Cargo.toml")) of
        true -> ok;
        false -> fail(["PLUSHIE_RUST_SOURCE_PATH does not look like a Rust workspace: ", SourcePath])
    end;
assert_source_path(error) ->
    ok.

default_icons_command({ok, SourcePath}, AssetsDir) ->
    {
        <<"cargo">>,
        [
            <<"run">>,
            <<"--manifest-path">>,
            to_bin(filename:join(SourcePath, "Cargo.toml")),
            <<"-p">>,
            <<"cargo-plushie">>,
            <<"--">>,
            <<"default-icons">>,
            <<"--out">>,
            to_bin(AssetsDir)
        ]
    };
default_icons_command({error, _}, AssetsDir) ->
    default_icons_command(error, AssetsDir);
default_icons_command(error, AssetsDir) ->
    {
        <<"cargo-plushie">>,
        [
            <<"default-icons">>,
            <<"--out">>,
            to_bin(AssetsDir)
        ]
    }.

default_icon_path() ->
    <<"assets/plushie-checkbox-512x512.png">>.

validate_asset_file_name(Name0) ->
    Name = to_bin(Name0),
    Invalid = Name =:= <<>>
        orelse Name =:= <<".">>
        orelse Name =:= <<"..">>
        orelse contains(Name, <<"\"">>)
        orelse contains(Name, <<"\\">>)
        orelse contains(Name, <<"/">>),
    case Invalid of
        true -> fail(["Icon file name is not supported in package metadata: ", Name]);
        false -> ok
    end.

contains(Value, Pattern) ->
    binary:match(to_bin(Value), to_bin(Pattern)) =/= nomatch.

archive_payload(PayloadDir, ArchivePath) ->
    validate_payload_archive_inputs(PayloadDir),
    ok = filelib:ensure_dir(ArchivePath),
    Tar = archive_tar(),
    case tar_supports_zstd(Tar) of
        true ->
            run_or_fail(Tar, ["-C", PayloadDir, "--sort=name", "--mtime=UTC 1970-01-01", "--owner=0", "--group=0", "--numeric-owner", "--zstd", "-cf", ArchivePath, "."]);
        false ->
            require_command("zstd"),
            case os:type() of
                {win32, _} ->
                    fail("tar does not support --zstd and the fallback archive pipeline requires a Unix shell. Install GNU tar with --zstd support for Windows package assembly.");
                _ ->
                    ok
            end,
            Command = shell_quote(Tar) ++ " -C " ++ shell_quote(PayloadDir) ++ " --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner -cf - . | zstd -q -o " ++ shell_quote(ArchivePath),
            run_or_fail("sh", ["-c", Command])
    end.

validate_payload_archive_inputs(PayloadDir) ->
    case filelib:fold_files(PayloadDir, ".*", true, fun(Path, Acc) ->
        case Acc of
            ok ->
                case file:read_link_info(Path) of
                    {ok, #file_info{type = symlink}} -> {error, ["Payload contains unsupported symlink: ", relative_to(PayloadDir, Path)]};
                    {ok, #file_info{type = device}} -> {error, ["Payload contains unsupported special file: ", relative_to(PayloadDir, Path)]};
                    {ok, #file_info{type = other}} -> {error, ["Payload contains unsupported special file: ", relative_to(PayloadDir, Path)]};
                    _ -> ok
                end;
            Error -> Error
        end
    end, ok) of
        ok -> ok;
        {error, Message} -> fail(Message)
    end.

archive_tar() ->
    case gnu_tar("tar") of
        true ->
            "tar";
        false ->
            case find_executable("gtar") of
                {ok, Gtar} ->
                    case gnu_tar(Gtar) of
                        true -> Gtar;
                        false -> fail("GNU tar or gtar is required for deterministic payload archives")
                    end;
                error ->
                    fail("GNU tar or gtar is required for deterministic payload archives")
            end
    end.

gnu_tar(Command) ->
    case executable_command(Command) of
        {ok, _} ->
            case run_command(Command, ["--version"], 30000) of
                {ok, Output} -> binary:match(Output, <<"GNU tar">>) =/= nomatch;
                {error, _} -> false
            end;
        error ->
            false
    end.

executable_command(Command) ->
    CommandString = to_list(Command),
    case filename:dirname(CommandString) of
        "." -> find_executable(Command);
        _ ->
            case filelib:is_regular(CommandString) of
                true -> {ok, Command};
                false -> error
            end
    end.

tar_supports_zstd(Tar) ->
    case run_command(Tar, ["--help"], 30000) of
        {ok, Output} -> binary:match(Output, <<"--zstd">>) =/= nomatch;
        {error, _} -> false
    end.

render_manifest(Values) ->
    StartConfig = maps:get(start_config, Values),
    [
        "schema_version = 1\n",
        "app_id = \"", toml_string_escape(maps:get(app_id, Values)), "\"\n",
        app_name_manifest_line(maps:get(app_name, Values, error)),
        "app_version = \"", toml_string_escape(maps:get(app_version, Values)), "\"\n",
        "target = \"", toml_string_escape(maps:get(target, Values)), "\"\n",
        "host_sdk = \"gleam\"\n",
        "host_sdk_version = \"", toml_string_escape(maps:get(host_sdk_version, Values)), "\"\n",
        "plushie_rust_version = \"", toml_string_escape(maps:get(plushie_rust_version, Values)), "\"\n",
        "protocol_version = ", integer_to_binary(maps:get(protocol_version, Values)), "\n",
        "\n[start]\n",
        "working_dir = \"", toml_string_escape(maps:get(working_dir, StartConfig)), "\"\n",
        "command = ", toml_array(maps:get(command, StartConfig)), "\n",
        "forward_env = ", toml_array(maps:get(forward_env, StartConfig)), "\n\n",
        platform_manifest_section(maps:get(icon_path, Values)),
        "[renderer]\n",
        "path = \"bin/plushie-renderer\"\n",
        "kind = \"", toml_string_escape(maps:get(renderer_kind, Values)), "\"\n",
        "source = \"", toml_string_escape(maps:get(renderer_source, Values)), "\"\n\n",
        "[payload]\n",
        "archive = \"", toml_string_escape(maps:get(archive, Values)), "\"\n",
        "hash = \"sha256:", maps:get(payload_hash, Values), "\"\n",
        "size = ", integer_to_binary(maps:get(payload_size, Values)), "\n"
    ].

app_name_manifest_line({ok, AppName}) ->
    to_bin(["app_name = \"", toml_string_escape(AppName), "\"\n"]);
app_name_manifest_line({error, _}) ->
    <<>>;
app_name_manifest_line(error) ->
    <<>>.

platform_manifest_section(IconPath) ->
    to_bin([
        "[platform]\n",
        "icon = \"", toml_string_escape(IconPath), "\"\n\n"
    ]).

manifest_escape_probe(Value) ->
    to_bin(render_manifest(#{
        app_id => Value,
        app_name => error,
        app_version => Value,
        target => Value,
        host_sdk_version => Value,
        plushie_rust_version => Value,
        protocol_version => 1,
        start_config => #{
            working_dir => ".",
            command => ["bin/connect"],
            forward_env => []
        },
        icon_path => Value,
        renderer_kind => Value,
        renderer_source => Value,
        archive => Value,
        payload_hash => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        payload_size => 1
    })).

default_forward_env() ->
    [
        <<"PATH">>,
        <<"HOME">>,
        <<"LANG">>,
        <<"LC_ALL">>,
        <<"XDG_RUNTIME_DIR">>,
        <<"WAYLAND_DISPLAY">>,
        <<"DISPLAY">>
    ].

toml_array(Values) ->
    to_bin([
        "[",
        lists:join(<<", ">>, [[<<"\"">>, toml_string_escape(Value), <<"\"">>] || Value <- Values]),
        "]"
    ]).

package_target() ->
    Os = case os:type() of
        {unix, linux} -> "linux";
        {unix, darwin} -> "darwin";
        {win32, _} -> "windows";
        Other -> fail(["Unsupported package OS: ", io_lib:format("~p", [Other])])
    end,
    Arch0 = erlang:system_info(system_architecture),
    Arch = case binary:match(to_bin(Arch0), <<"aarch64">>) of
        {_, _} -> "aarch64";
        nomatch ->
            case binary:match(to_bin(Arch0), <<"x86_64">>) of
                {_, _} -> "x86_64";
                nomatch -> fail(["Unsupported package architecture: ", Arch0])
            end
    end,
    to_bin([Os, "-", Arch]).

host_sdk_version() ->
    case manifest_package_version("plushie_gleam") of
        {ok, Version} -> Version;
        error -> "0.0.0"
    end.

manifest_package_version(Name) ->
    case file:read_file("manifest.toml") of
        {ok, Content} ->
            NameBin = to_bin(Name),
            Pattern = <<"name = \"", NameBin/binary, "\", version = \"([^\"]+)\"">>,
            case re:run(Content, Pattern, [{capture, [1], binary}]) of
                {match, [Version]} -> {ok, Version};
                nomatch -> error
            end;
        {error, _} -> error
    end.

plushie_rust_version() ->
    case getenv("PLUSHIE_RUST_VERSION") of
        {ok, Version} -> Version;
        error ->
            case getenv("PLUSHIE_RUST_SOURCE_PATH") of
                {ok, SourcePath} ->
                    case root_string_file(filename:join(SourcePath, "Cargo.toml"), "version") of
                        {ok, Version} -> Version;
                        error -> root_string("plushie_rust_version", "0.0.0")
                    end;
                error -> root_string("plushie_rust_version", "0.0.0")
            end
    end.

root_string(Key, Default) ->
    case root_string_file("gleam.toml", Key) of
        {ok, Value} -> Value;
        error -> Default
    end.

root_string_file(File, Key) ->
    case file:read_file(File) of
        {ok, Content} ->
            Pattern = <<"(?m)^", (to_bin(Key))/binary, " = \"([^\"]+)\"">>,
            case re:run(Content, Pattern, [{capture, [1], binary}]) of
                {match, [Value]} -> {ok, Value};
                nomatch -> error
            end;
        {error, _} -> error
    end.

default_renderer_source(<<"custom">>) -> "local-build";
default_renderer_source(<<"stock">>) -> "local-resolve";
default_renderer_source(_) -> "local-resolve".

copy_executable(Src, Dest) ->
    assert_executable(Src),
    copy_path(Src, Dest),
    make_executable(Dest).

copy_dir_contents(Src, Dest) ->
    case filelib:is_dir(Src) of
        true -> ok;
        false -> fail(["Missing directory: ", Src])
    end,
    ok = filelib:ensure_dir(filename:join(Dest, "dummy")),
    run_or_fail("sh", ["-c", "cp -R " ++ shell_quote(filename:join(Src, ".")) ++ " " ++ shell_quote(Dest)]).

copy_path(Src, Dest) ->
    ok = filelib:ensure_dir(Dest),
    run_or_fail("cp", ["-aL", Src, Dest]).

reset_dir(Path) ->
    _ = file:del_dir_r(Path),
    ok = filelib:ensure_dir(filename:join(Path, "dummy")).

sha256_file(Path) ->
    {ok, Data} = file:read_file(Path),
    Hex = [io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= crypto:hash(sha256, Data)],
    to_bin(Hex).

file_size(Path) ->
    {ok, Info} = file:read_file_info(Path),
    Info#file_info.size.

make_executable(Path) ->
    ok = file:change_mode(Path, 8#755).

assert_executable(Path) ->
    case is_executable(Path) of
        true -> ok;
        false -> fail(["Path is not executable: ", Path])
    end.

is_executable(Path) ->
    case file:read_file_info(Path) of
        {ok, #file_info{mode = Mode, type = regular}} -> Mode band 8#111 =/= 0;
        _ -> false
    end.

require_command(Name) ->
    case find_executable(Name) of
        {ok, _} -> ok;
        error -> fail(["Missing required command: ", Name])
    end.

find_executable(Name) ->
    case os:find_executable(Name) of
        false -> error;
        Path -> {ok, Path}
    end.

run_or_fail(Command, Args) ->
    case run_command(Command, Args, 1800000) of
        {ok, Output} -> Output;
        {error, Output} -> fail([Command, " failed:\n", Output])
    end.

run_command(Command, Args, Timeout) ->
    CommandString = to_list(Command),
    Exe = case filename:dirname(CommandString) of
        "." ->
            case os:find_executable(CommandString) of
                false -> throw({package_error, ["Missing required command: ", CommandString]});
                Found -> Found
            end;
        _ -> CommandString
    end,
    ArgStrings = [to_list(Arg) || Arg <- Args],
    Port = erlang:open_port({spawn_executable, Exe}, [
        {args, ArgStrings},
        stream, binary, exit_status, use_stdio, stderr_to_stdout
    ]),
    collect_port_output(Port, <<>>, Timeout).

collect_port_output(Port, Acc, Timeout) ->
    receive
        {Port, {data, Data}} ->
            collect_port_output(Port, <<Acc/binary, Data/binary>>, Timeout);
        {Port, {exit_status, 0}} ->
            {ok, Acc};
        {Port, {exit_status, _Status}} ->
            {error, Acc}
    after Timeout ->
        erlang:port_close(Port),
        {error, Acc}
    end.

required_flag(Name) ->
    case optional_flag(Name) of
        {ok, Value} -> Value;
        error -> fail(["Missing required flag: ", Name])
    end.

flag(Name, Default) ->
    case optional_flag(Name) of
        {ok, Value} -> Value;
        error -> to_bin(Default)
    end.

optional_flag(Name) ->
    case plushie_cli_args_ffi:get_flag_value(to_bin(Name), init:get_plain_arguments()) of
        {ok, Value} -> {ok, Value};
        {error, _} -> error
    end.

has_flag(Name) ->
    plushie_cli_args_ffi:has_flag(to_bin(Name), init:get_plain_arguments()).

getenv(Name) ->
    case os:getenv(Name) of
        false -> error;
        Value -> {ok, to_bin(Value)}
    end.

relative_to(Root, Path) ->
    RootBin = to_bin(filename:join(Root, "")),
    PathBin = to_bin(Path),
    case binary:match(PathBin, RootBin) of
        {0, Size} -> binary:part(PathBin, Size, byte_size(PathBin) - Size);
        _ -> PathBin
    end.

shell_quote(Value) ->
    "'" ++ string:replace(to_list(Value), "'", "'\"'\"'", all) ++ "'".

trim(Value) ->
    to_bin(string:trim(to_list(Value))).

toml_string_escape(Value) ->
    toml_string_escape(to_bin(Value), []).

toml_string_escape(<<>>, Acc) ->
    lists:reverse(Acc);
toml_string_escape(<<"\\", Rest/binary>>, Acc) ->
    toml_string_escape(Rest, ["\\\\" | Acc]);
toml_string_escape(<<"\"", Rest/binary>>, Acc) ->
    toml_string_escape(Rest, ["\\\"" | Acc]);
toml_string_escape(<<"\n", Rest/binary>>, Acc) ->
    toml_string_escape(Rest, ["\\n" | Acc]);
toml_string_escape(<<"\r", Rest/binary>>, Acc) ->
    toml_string_escape(Rest, ["\\r" | Acc]);
toml_string_escape(<<"\t", Rest/binary>>, Acc) ->
    toml_string_escape(Rest, ["\\t" | Acc]);
toml_string_escape(<<"\b", Rest/binary>>, Acc) ->
    toml_string_escape(Rest, ["\\b" | Acc]);
toml_string_escape(<<"\f", Rest/binary>>, Acc) ->
    toml_string_escape(Rest, ["\\f" | Acc]);
toml_string_escape(<<Char, Rest/binary>>, Acc) when Char < 16 ->
    toml_string_escape(Rest, [io_lib:format("\\u000~.16B", [Char]) | Acc]);
toml_string_escape(<<Char, Rest/binary>>, Acc) when Char < 32 ->
    toml_string_escape(Rest, [io_lib:format("\\u00~2.16.0B", [Char]) | Acc]);
toml_string_escape(<<Char/utf8, Rest/binary>>, Acc) ->
    toml_string_escape(Rest, [<<Char/utf8>> | Acc]).

to_bin(Value) when is_binary(Value) -> Value;
to_bin(Value) when is_list(Value) -> iolist_to_binary(Value);
to_bin(Value) when is_atom(Value) -> atom_to_binary(Value);
to_bin(Value) -> to_bin(io_lib:format("~p", [Value])).

to_list(Value) when is_binary(Value) -> binary_to_list(Value);
to_list(Value) when is_list(Value) -> Value.

fail(Message) ->
    throw({package_error, to_bin(Message)}).
