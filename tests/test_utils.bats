#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../lib/utils.sh"
}

@test "_strip_ansi removes color codes" {
  result=$(echo -e '\033[31mhello\033[0m' | _strip_ansi)
  [ "$result" = "hello" ]
}

@test "_strip_ansi preserves plain text" {
  result=$(echo "plain text" | _strip_ansi)
  [ "$result" = "plain text" ]
}

@test "_visible_len counts plain text correctly" {
  result=$(_visible_len "hello")
  [ "$result" -eq 5 ]
}

@test "_wrap_text wraps long text" {
  local lines=()
  _wrap_text "one two three four five" 10 lines
  [ ${#lines[@]} -gt 1 ]
}

@test "_wrap_text keeps short text on one line" {
  local lines=()
  _wrap_text "short" 20 lines
  [ ${#lines[@]} -eq 1 ]
  [ "${lines[0]}" = "short" ]
}
