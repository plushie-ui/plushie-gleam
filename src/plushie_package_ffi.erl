-module(plushie_package_ffi).
-export([
    package/1,
    default_icon_path/0,
    default_icons_command/2,
    app_name_manifest_line/1,
    package_config_text/0,
    package_tools_check/3,
    portable_tools_check/2,
    package_target_supported/1,
    start_host_script/2,
    partial_manifest/8
]).
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
            package_payload(ProtocolVersion)
    end.

package_payload(ProtocolVersion) ->
    DistDir = flag("--dist-dir", "dist"),
    warn_if_not_gitignored(DistDir),
    PayloadDir = filename:join(DistDir, "payload"),
    RendererPath = filename:join([PayloadDir, "bin", "plushie-renderer"]),
    RendererKind = flag("--renderer-kind", "stock"),
    AppId = required_flag("--app-id"),
    AppName = optional_flag("--app-name"),
    AppVersion = flag("--app-version", root_string("version", "0.1.0")),
    ConnectModule = required_flag("--connect-module"),
    Target = package_target(),
    assert_package_target_supported(Target),
    HostSdkVersion = host_sdk_version(),
    PlushieRustVersion = plushie_rust_version(),
    PackageConfigArg = optional_flag("--package-config"),
    assert_renderer_kind_matches_project(RendererKind),

    reset_dir(DistDir),
    ok = filelib:ensure_dir(filename:join([PayloadDir, "bin", "dummy"])),
    ok = filelib:ensure_dir(filename:join([PayloadDir, "shipment", "dummy"])),

    install_renderer(RendererKind, RendererPath),
    build_shipment(PayloadDir),
    maybe_copy_erlang_runtime(PayloadDir),
    write_start_host_script(PayloadDir, ConnectModule),

    StartCommand = start_host_script_name(Target),
    Manifest = partial_manifest(#{
        app_id => AppId,
        app_name => AppName,
        app_version => AppVersion,
        target => Target,
        host_sdk_version => HostSdkVersion,
        plushie_rust_version => PlushieRustVersion,
        protocol_version => ProtocolVersion,
        renderer_kind => RendererKind,
        start_command => StartCommand
    }),
    ManifestPath = filename:join(DistDir, "plushie-package.toml"),
    ok = file:write_file(ManifestPath, Manifest),
    io:format("Wrote ~s~n", [ManifestPath]),

    assemble_package(ManifestPath, PayloadDir, PackageConfigArg).

assemble_package(ManifestPath, PayloadDir, PackageConfigArg) ->
    Tool = to_bin(filename:join(["bin", tool_name()])),
    BaseArgs = [
        <<"package">>,
        <<"assemble">>,
        <<"--manifest">>,
        to_bin(ManifestPath),
        <<"--payload-dir">>,
        to_bin(PayloadDir)
    ],
    Args = case PackageConfigArg of
        {ok, ConfigPath} -> BaseArgs ++ [<<"--package-config">>, to_bin(ConfigPath)];
        error ->
            case filelib:is_regular("plushie-package.config.toml") of
                true -> BaseArgs ++ [<<"--package-config">>, <<"plushie-package.config.toml">>];
                false -> BaseArgs
            end
    end,
    _ = run_or_fail(Tool, Args),
    ok.

start_host_script_name(Target) ->
    case binary:match(Target, <<"windows">>) of
        {_, _} -> <<"bin/start_host.cmd">>;
        nomatch -> <<"bin/start_host">>
    end.

%% Test-facing arity-8 form with positional arguments.
partial_manifest(AppId, AppName, AppVersion, Target, HostSdkVersion, PlushieRustVersion, ProtocolVersion, RendererKind) ->
    partial_manifest(#{
        app_id => AppId,
        app_name => AppName,
        app_version => AppVersion,
        target => Target,
        host_sdk_version => HostSdkVersion,
        plushie_rust_version => PlushieRustVersion,
        protocol_version => ProtocolVersion,
        renderer_kind => RendererKind,
        start_command => start_host_script_name(Target)
    }).

partial_manifest(Values) ->
    to_bin([
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
        "command = [\"", toml_string_escape(maps:get(start_command, Values)), "\"]\n",
        "\n[renderer]\n",
        "path = \"bin/plushie-renderer\"\n",
        "kind = \"", toml_string_escape(maps:get(renderer_kind, Values)), "\"\n"
    ]).

app_name_manifest_line({ok, AppName}) ->
    to_bin(["app_name = \"", toml_string_escape(AppName), "\"\n"]);
app_name_manifest_line({error, _}) ->
    <<>>;
app_name_manifest_line(error) ->
    <<>>.

package_config_text() ->
    to_bin([
        "# Plushie standalone package config.\n",
        "# Commit this file and edit it when the packaged app needs a\n",
        "# different entry point, working directory, or forwarded environment.\n\n",
        "config_version = 1\n\n",
        "[start]\n",
        "# Relative to the extracted app package.\n",
        "working_dir = \".\"\n",
        "# Structured argv. The first item is the packaged host executable.\n",
        "# bin/start_host is the POSIX entry point.\n",
        "# On windows-* targets the SDK automatically uses bin/start_host.cmd.\n",
        "command = [\"bin/start_host\"]\n",
        "# Environment variable names copied from the parent process.\n",
        "forward_env = [\n",
        "  \"PATH\",\n",
        "  \"HOME\",\n",
        "  \"LANG\",\n",
        "  \"LC_ALL\",\n",
        "  \"XDG_RUNTIME_DIR\",\n",
        "  \"WAYLAND_DISPLAY\",\n",
        "  \"DISPLAY\",\n",
        "]\n\n",
        "# [assets]\n",
        "# # Project-relative directory copied verbatim into the payload root\n",
        "# # during package assembly. When this section is absent, a directory\n",
        "# # named `package_assets/` next to this config file is used by\n",
        "# # convention if it exists.\n",
        "# dir = \"package_assets\"\n\n",
        "# Optional platform metadata passed through to the launcher manifest.\n",
        "# Uncomment and fill in any fields you need.\n",
        "# [platform]\n",
        "# publisher = \"Example Corp\"\n",
        "# copyright = \"Copyright 2025 Example Corp\"\n",
        "# category = \"Utility\"\n",
        "# description = \"A short description of your app\"\n",
        "# bundle_id = \"dev.example.my_app\"  # macOS: defaults to app_id\n",
        "# icon = \"assets/icon.png\"          # set via --icon flag; listed here for reference\n\n",
        "# [platform.macos]\n",
        "# bundle_version = \"1\"  # CFBundleVersion; defaults to app_version\n\n",
        "# [platform.windows]\n",
        "# install_scope = \"perUser\"  # perUser or perMachine\n"
    ]).

package_tools_check(Tool, Renderer, Launcher) ->
    Missing = [Path || Path <- [Tool, Renderer, Launcher], not filelib:is_regular(Path)],
    case Missing of
        [] -> {ok, nil};
        _ -> {error, Missing}
    end.

portable_tools_check(Tool, Launcher) ->
    Missing = [Path || Path <- [Tool, Launcher], not filelib:is_regular(Path)],
    case Missing of
        [] -> {ok, nil};
        _ -> {error, Missing}
    end.

package_target_supported(Target) ->
    try
        assert_package_target_supported(Target),
        {ok, nil}
    catch
        throw:{package_error, Reason} -> {error, Reason}
    end.

assert_package_target_supported(_) ->
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

install_renderer(<<"custom">>, RendererPath) ->
    case optional_flag("--renderer-path") of
        {ok, Existing} ->
            copy_executable(Existing, RendererPath);
        error ->
            Args = ["run", "-m", "plushie/build", "--", "--bin-file", RendererPath, "--release"],
            io:format("Building custom renderer...~n", []),
            run_or_fail("gleam", Args)
    end,
    ensure_portable_tools_available(),
    make_executable(RendererPath);
install_renderer(<<"stock">>, RendererPath) ->
    Renderer = resolve_stock_renderer(),
    ensure_portable_tools_available(),
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
        true -> ShipmentRenderer;
        false -> sync_stock_renderer()
    end.

sync_stock_renderer() ->
    run_or_fail("gleam", ["run", "-m", "plushie/download"]),
    ensure_package_tools_available(),
    filename:join(["bin", "plushie-renderer"]).

ensure_package_tools_available() ->
    Tool = filename:join(["bin", tool_name()]),
    Renderer = filename:join(["bin", "plushie-renderer"]),
    Launcher = filename:join(["bin", launcher_name()]),
    case package_tools_check(Tool, Renderer, Launcher) of
        {ok, nil} -> ok;
        {error, Missing} ->
            fail(["Portable packaging requires the managed Plushie tool set. Missing: ", lists:join(", ", Missing), ". Run `gleam run -m plushie/download`."])
    end.

ensure_portable_tools_available() ->
    Tool = filename:join(["bin", tool_name()]),
    Launcher = filename:join(["bin", launcher_name()]),
    case portable_tools_check(Tool, Launcher) of
        {ok, nil} -> ok;
        {error, Missing} ->
            fail(["Portable packaging requires the managed Plushie tool set. Missing: ", lists:join(", ", Missing), ". Run `gleam run -m plushie/download`."])
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

write_start_host_script(PayloadDir, ConnectModule) ->
    case os:type() of
        {win32, _} -> write_start_host_script_windows(PayloadDir, ConnectModule);
        _          -> write_start_host_script_posix(PayloadDir, ConnectModule)
    end.

write_start_host_script_posix(PayloadDir, ConnectModule) ->
    Path = filename:join([PayloadDir, "bin", "start_host"]),
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
        "exec \"$ERL\" -pa \"$DIR\"/shipment/*/ebin -eval '", ConnectModule, ":main().' -noinput -extra \"$@\"\n"
    ],
    ok = file:write_file(Path, iolist_to_binary(Script)),
    make_executable(Path).

write_start_host_script_windows(PayloadDir, ConnectModule) ->
    Path = filename:join([PayloadDir, "bin", "start_host.cmd"]),
    Script = [
        "@echo off\r\n",
        "setlocal\r\n",
        "set \"DIR=%~dp0..\"\r\n",
        "if exist \"%DIR%\\runtime\\erlang\\bin\\erl.exe\" (\r\n",
        "  set \"ERL=%DIR%\\runtime\\erlang\\bin\\erl.exe\"\r\n",
        ") else (\r\n",
        "  set \"ERL=erl.exe\"\r\n",
        ")\r\n",
        "\"%ERL%\" -pa \"%DIR%\\shipment\\*/ebin\" -eval \"", ConnectModule, ":main().\" -noinput -extra %*\r\n"
    ],
    ok = file:write_file(Path, iolist_to_binary(Script)).

%% Returns {FileName, Content} for the start_host wrapper given an OS type string
%% and an Erlang module name. Used by tests to verify generated artifacts.
start_host_script(<<"windows">>, ConnectModule) ->
    {
        <<"bin/start_host.cmd">>,
        iolist_to_binary([
            "@echo off\r\n",
            "setlocal\r\n",
            "set \"DIR=%~dp0..\"\r\n",
            "if exist \"%DIR%\\runtime\\erlang\\bin\\erl.exe\" (\r\n",
            "  set \"ERL=%DIR%\\runtime\\erlang\\bin\\erl.exe\"\r\n",
            ") else (\r\n",
            "  set \"ERL=erl.exe\"\r\n",
            ")\r\n",
            "\"%ERL%\" -pa \"%DIR%\\shipment\\*/ebin\" -eval \"", ConnectModule, ":main().\" -noinput -extra %*\r\n"
        ])
    };
start_host_script(_, ConnectModule) ->
    {
        <<"bin/start_host">>,
        iolist_to_binary([
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
            "exec \"$ERL\" -pa \"$DIR\"/shipment/*/ebin -eval '", ConnectModule, ":main().' -noinput -extra \"$@\"\n"
        ])
    }.

default_icons_command({ok, SourcePath}, AssetsDir) ->
    {
        <<"cargo">>,
        [
            <<"run">>,
            <<"--manifest-path">>,
            to_bin(filename:join(SourcePath, "Cargo.toml")),
            <<"-p">>,
            <<"cargo-plushie">>,
            <<"--bin">>,
            <<"plushie">>,
            <<"--release">>,
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
        to_bin(filename:join(["bin", tool_name()])),
        [
            <<"default-icons">>,
            <<"--out">>,
            to_bin(AssetsDir)
        ]
    }.

default_icon_path() ->
    <<"assets/default-app-icon-512.png">>.

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
                        error ->
                            case root_string_file("gleam.toml", "plushie_rust_version") of
                                {ok, Version} -> Version;
                                error -> fail("plushie_rust_version not found: set PLUSHIE_RUST_VERSION, add plushie_rust_version to gleam.toml, or set PLUSHIE_RUST_SOURCE_PATH to a valid checkout")
                            end
                    end;
                error ->
                    case root_string_file("gleam.toml", "plushie_rust_version") of
                        {ok, Version} -> Version;
                        error -> fail("plushie_rust_version not found: set PLUSHIE_RUST_VERSION, add plushie_rust_version to gleam.toml, or set PLUSHIE_RUST_SOURCE_PATH to a valid checkout")
                    end
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

warn_if_not_gitignored(Path) ->
    case plushie_gitignore_ffi:status(to_bin(Path)) of
        not_ignored ->
            PathStr = to_list(Path),
            io:format(standard_error,
                "warning: ~s/ is not in .gitignore.~n"
                "  Recommended: add the following line so generated artifacts don't end~n"
                "  up committed:~n~n"
                "      /~s/~n",
                [PathStr, PathStr]);
        _ ->
            ok
    end.
