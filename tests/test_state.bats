#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../lib/state.sh"
}

@test "state_set and state_get" {
  state_set "test.key" "value"
  result=$(state_get "test.key")
  [ "$result" = "value" ]
}

@test "state_get returns default for missing key" {
  result=$(state_get "missing.key" "default_val")
  [ "$result" = "default_val" ]
}

@test "state_has returns true for existing key" {
  state_set "exists" "yes"
  state_has "exists"
}

@test "state_has returns false for missing key" {
  ! state_has "nonexistent_key_xyz"
}

@test "state_append builds csv" {
  state_clear
  state_append "list" "a"
  state_append "list" "b"
  state_append "list" "c"
  result=$(state_get "list")
  [ "$result" = "a,b,c" ]
}

@test "state_get_array_into splits csv" {
  state_clear
  state_set "items" "x,y,z"
  local arr=()
  state_get_array_into "items" arr
  [ ${#arr[@]} -eq 3 ]
  [ "${arr[0]}" = "x" ]
  [ "${arr[2]}" = "z" ]
}

@test "state_clear empties all state" {
  state_set "a" "1"
  state_set "b" "2"
  state_clear
  ! state_has "a"
  ! state_has "b"
}

@test "state_save and state_load roundtrip" {
  local tmpfile
  tmpfile=$(mktemp)
  state_clear
  state_set "saved.key" "saved_value"
  state_save "$tmpfile"
  state_clear
  state_load "$tmpfile"
  result=$(state_get "saved.key")
  [ "$result" = "saved_value" ]
  rm -f "$tmpfile"
}
