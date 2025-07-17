#!/bin/bash

rebar3 eunit &&
rebar3 ct --verbose && # It has to be `--verbose` to do `klsn:read_line` test.
rebar3 cover &&
rebar3 edoc &&
echo ALL_TEST_PASS
