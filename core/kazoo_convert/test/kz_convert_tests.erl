%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc Test fax conversions.
%%% @author Sean Wysor
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_convert_tests).

-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("kazoo_convert/include/kz_convert.hrl").

all_test_() ->
    {setup, fun setup/0, fun cleanup/1, fun(_) ->
        [
            {"Testing tiff to pdf binary", test_tiff_to_pdf_binary()},
            {"Testing tiff to pdf tuple", test_tiff_to_pdf_tuple()},
            {"Testing tiff to tiff binary", test_tiff_to_tiff_binary()},
            {"Testing tiff to tiff tuple", test_tiff_to_tiff_tuple()},
            {"Testing pdf to tiff binary", test_pdf_to_tiff_binary()},
            {"Testing pdf to tiff tuple", test_pdf_to_tiff_tuple()},
            {"Testing openoffice to pdf binary", test_openoffice_to_pdf_binary()},
            {"Testing openoffice to pdf tuple", test_openoffice_to_pdf_tuple()},
            {"Testing openoffice to tiff binary", test_openoffice_to_tiff_binary()},
            {"Tesung openoffice to tiff tuple", test_openoffice_to_tiff_tuple()},
            {"Tesing tiff to pdf binary output binary", test_tiff_to_pdf_binary_output_binary()},
            {"Tesing tiff to pdf tuple output binary", test_tiff_to_pdf_tuple_output_binary()},
            {"Testing tiff to tiff binary output binary", test_tiff_to_tiff_binary_output_binary()},
            {"Testing tiff to tiff tuple output binary", test_tiff_to_tiff_tuple_output_binary()},
            {"Tesung pdf to tiff binary output binary", test_pdf_to_tiff_binary_output_binary()},
            {"Tesing pdf to tiff tuple output binary", test_pdf_to_tiff_tuple_output_binary()},
            {"Tesing openoffice to pdf binary output binary",
                test_openoffice_to_pdf_binary_output_binary()},
            {"Testing openoffice to pdf tuple output binary",
                test_openoffice_to_pdf_tuple_output_binary()},
            {"Testing openoffice to tiff binary output binary",
                test_openoffice_to_tiff_binary_output_binary()},
            {"Testing openoffice to tiff tupple output binary",
                test_openoffice_to_tiff_tuple_output_binary()},
            {"Testing tiff to pdf binary invalid", test_tiff_to_pdf_binary_invalid()},
            {"Testing tiff to pdf invalid", test_tiff_to_pdf_tuple_invalid()},
            {"Testing tiff to tiff binary invalid", test_tiff_to_tiff_binary_invalid()},
            {"Testing tiff to tiff tuple invalid", test_tiff_to_tiff_tuple_invalid()},
            {"Testing pdf to tiff binary invalid", test_pdf_to_tiff_binary_invalid()},
            {"Testing pdf to tiff tupple invalid", test_pdf_to_tiff_tuple_invalid()},
            {"Testing tiff to pdf nonexistent file", test_tiff_to_pdf_nonexistent_file()},
            {"Testing tiff to tiff nonexistnet file", test_tiff_to_tiff_nonexistent_file()},
            {"Testing pdf to tiff nonexistent file", test_pdf_to_tiff_nonexistent_file()},
            {"Testing invalid conversion", test_invalid_conversion()},
            {"Testing empty content", test_empty_content()},
            {"Testing empty filename", test_empty_filename()},
            {"Testing tiff to tiff to filename", test_tiff_to_tiff_to_filename()},
            {"Testing pdf to tiff to filename", test_pdf_to_tiff_to_filename()},
            {"Tesying openoffice to tiff to filename", test_openoffice_to_tiff_to_filename()},
            {"Testing tiff to tiff read metadata", test_tiff_to_tiff_read_metadata()},
            {"Testing tiff to tiff small file read meatadata",
                test_tiff_to_tiff_small_file_read_metadata()},
            {"Testing pdf to tiff read metadata", test_pdf_to_tiff_read_metadata()},
            {"Testing openoffice to tiff read metadata", test_openoffice_to_tiff_read_metadata()},
            {"Testing read metadata", test_read_metadata()}
        ]
    end}.

setup() ->
    ?LOG_DEBUG(":: Setting up Kazoo Convert test"),

    Pid =
        case kz_fixturedb_util:start_me() of
            {error, {already_started, P}} -> P;
            P when is_pid(P) -> P
        end,

    _ = kz_openoffice_server:start_link(),
    meck:new(kz_datamgr, [unstick, passthrough]),

    meck:new(kz_fixturedb_db, [unstick, passthrough]),

    Pid.

cleanup(Pid) ->
    kz_fixturedb_util:stop_me(Pid),
    meck:unload().

read_test_file(Filename) ->
    {'ok', Content} = file:read_file(get_path_to_fixture(Filename)),
    Content.

copy_fixture_to_tmp(Filename) ->
    JobId = kz_binary:rand_hex(16),
    SrcFile = get_path_to_fixture(Filename),
    DstFile = kz_term:to_binary(["/tmp/", JobId, filename:extension(Filename)]),
    {'ok', _} = file:copy(SrcFile, DstFile),
    DstFile.

get_path_to_fixture(Filename) ->
    case code:priv_dir('kazoo_fixturedb') of
        {'error', 'bad_name'} = Error -> Error;
        PrivPath -> kz_term:to_binary([PrivPath, "/media_files/", Filename])
    end.

test_tiff_to_pdf_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid-multipage.tiff"),
    Expected = <<"/tmp/", JobId/binary, ".pdf">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                From,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_pdf_tuple() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid-multipage.tiff"),
    Expected = <<"/tmp/", JobId/binary, ".pdf">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_tiff_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.tiff"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                From,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_tiff_tuple() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.tiff"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_pdf_to_tiff_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.pdf"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                From,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_pdf_to_tiff_tuple() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.pdf"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_openoffice_to_pdf_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.docx"),
    Expected = <<"/tmp/", JobId/binary, ".pdf">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"application/pdf">>,
                From,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_openoffice_to_pdf_tuple() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.docx"),
    Expected = <<"/tmp/", JobId/binary, ".pdf">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"application/pdf">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_openoffice_to_tiff_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.docx"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"image/tiff">>,
                From,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_openoffice_to_tiff_tuple() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.docx"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"image/tiff">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_pdf_binary_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid-multipage.tiff"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"output_type">>, 'binary'}
                ]
            )
        )
    ].

test_tiff_to_pdf_tuple_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid-multipage.tiff"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                {'file', Src},
                [{<<"job_id">>, JobId}, {<<"output_type">>, 'binary'}]
            )
        )
    ].

test_tiff_to_tiff_binary_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.tiff"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                From,
                [{<<"job_id">>, JobId}, {<<"output_type">>, 'binary'}]
            )
        )
    ].

test_tiff_to_tiff_tuple_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.tiff"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                {'file', Src},
                [{<<"job_id">>, JobId}, {<<"output_type">>, 'binary'}]
            )
        )
    ].

test_pdf_to_tiff_binary_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.pdf"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                From,
                [{<<"job_id">>, JobId}, {<<"output_type">>, 'binary'}]
            )
        )
    ].

test_pdf_to_tiff_tuple_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.pdf"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                {'file', Src},
                [{<<"job_id">>, JobId}, {<<"output_type">>, 'binary'}]
            )
        )
    ].

test_openoffice_to_pdf_binary_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.docx"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"application/pdf">>,
                From,
                [{<<"job_id">>, JobId}, {<<"output_type">>, 'binary'}]
            )
        )
    ].

test_openoffice_to_pdf_tuple_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.docx"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"application/pdf">>,
                {'file', Src},
                [
                    {<<"job_id">>, JobId},
                    {<<"output_type">>, 'binary'}
                ]
            )
        )
    ].

test_openoffice_to_tiff_binary_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.docx"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"image/tiff">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"output_type">>, 'binary'}
                ]
            )
        )
    ].

test_openoffice_to_tiff_tuple_output_binary() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.docx"),
    [
        ?_assertMatch(
            {'ok', _},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"image/tiff">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_pdf_binary_invalid() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("invalid.tiff"),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                From,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_pdf_tuple_invalid() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("invalid.tiff"),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_tiff_binary_invalid() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("invalid.tiff"),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                From,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_tiff_tuple_invalid() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("invalid.tiff"),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_pdf_to_tiff_binary_invalid() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("invalid.pdf"),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                From,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_pdf_to_tiff_tuple_invalid() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("invalid.pdf"),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_pdf_nonexistent_file() ->
    JobId = kz_binary:rand_hex(16),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                {'file', <<"/tmp/not_a_file.tiff">>},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_tiff_nonexistent_file() ->
    JobId = kz_binary:rand_hex(16),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                {'file', <<"/tmp/not_a_file.tiff">>},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_pdf_to_tiff_nonexistent_file() ->
    JobId = kz_binary:rand_hex(16),
    [
        ?_assertMatch(
            {'error', <<"convert command failed">>},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                {'file', <<"not_a_file.pdf">>},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_invalid_conversion() ->
    JobId = kz_binary:rand_hex(16),
    Src = copy_fixture_to_tmp("valid.pdf"),
    [
        ?_assertMatch(
            {'error', <<"invalid conversion requested:", _/binary>>},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                {'file', Src},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_empty_filename() ->
    JobId = kz_binary:rand_hex(16),
    [
        ?_assertMatch(
            {'error', <<"empty filename">>},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                {'file', <<>>},
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_empty_content() ->
    JobId = kz_binary:rand_hex(16),
    [
        ?_assertMatch(
            {'error', <<"empty content">>},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"application/pdf">>,
                <<>>,
                [{<<"job_id">>, JobId}]
            )
        )
    ].

test_tiff_to_tiff_to_filename() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.tiff"),
    Expected = <<"/tmp/", (kz_binary:rand_hex(16))/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"to_filename">>, Expected}
                ]
            )
        )
    ].

test_pdf_to_tiff_to_filename() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.pdf"),
    Expected = <<"/tmp/", (kz_binary:rand_hex(16))/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"to_filename">>, Expected}
                ]
            )
        )
    ].

test_openoffice_to_tiff_to_filename() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.docx"),
    Expected = <<"/tmp/", (kz_binary:rand_hex(16))/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"image/tiff">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"to_filename">>, Expected}
                ]
            )
        )
    ].

test_tiff_to_tiff_read_metadata() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.tiff"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected, [
                {<<"page_count">>, 1},
                {<<"size">>, _},
                {<<"mimetype">>, <<"image/tiff">>},
                {<<"filetype">>, <<"tiff">>}
            ]},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"read_metadata">>, true}
                ]
            )
        )
    ].

test_tiff_to_tiff_small_file_read_metadata() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("small.tiff"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected, [
                {<<"page_count">>, 1},
                {<<"size">>, _},
                {<<"mimetype">>, <<"image/tiff">>},
                {<<"filetype">>, <<"tiff">>}
            ]},
            kz_convert:fax(
                <<"image/tiff">>,
                <<"image/tiff">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"read_metadata">>, true}
                ]
            )
        )
    ].

test_pdf_to_tiff_read_metadata() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.pdf"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected, [
                {<<"page_count">>, 1},
                {<<"size">>, _},
                {<<"mimetype">>, <<"image/tiff">>},
                {<<"filetype">>, <<"tiff">>}
            ]},
            kz_convert:fax(
                <<"application/pdf">>,
                <<"image/tiff">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"read_metadata">>, true}
                ]
            )
        )
    ].

test_openoffice_to_tiff_read_metadata() ->
    JobId = kz_binary:rand_hex(16),
    From = read_test_file("valid.docx"),
    Expected = <<"/tmp/", JobId/binary, ".tiff">>,
    [
        ?_assertMatch(
            {'ok', Expected, [
                {<<"page_count">>, 1},
                {<<"size">>, _},
                {<<"mimetype">>, <<"image/tiff">>},
                {<<"filetype">>, <<"tiff">>}
            ]},
            kz_convert:fax(
                <<"application/vnd.openxmlformats-officedocument.wordprocessingml.document">>,
                <<"image/tiff">>,
                From,
                [
                    {<<"job_id">>, JobId},
                    {<<"read_metadata">>, true}
                ]
            )
        )
    ].

test_read_metadata() ->
    Src = copy_fixture_to_tmp("valid.tiff"),
    [
        ?_assertMatch(
            [
                {<<"page_count">>, 1},
                {<<"size">>, _},
                {<<"mimetype">>, <<"image/tiff">>},
                {<<"filetype">>, <<"tiff">>}
            ],
            kz_fax_converter:read_metadata(Src)
        )
    ].
