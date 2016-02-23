# buffer
[![Travis](https://img.shields.io/travis/adrienmo/buffer.svg?branch=master&style=flat-square)](https://travis-ci.org/adrienmo/buffer)
[![Coveralls](https://img.shields.io/coveralls/adrienmo/buffer.svg?branch=master&style=flat-square)](https://coveralls.io/github/adrienmo/buffer)
[![Hex.pm](https://img.shields.io/hexpm/v/buffer.svg?style=flat-square)](https://hex.pm/packages/buffer)

Provide read and write buffers for Elixir.
Use-case examples:
- Read buffer for a RDBMS.
- Write buffer for statsd counters.
- Write buffer to do batch API calls.

## Description

buffer is a library to create read or write buffer easily.

## Usage

### Write Buffer for KeyList

```elixir
## Declaration of the buffer
defmodule BufferKeyListLimit do
  use Buffer.Write.KeyList, interval: 1000, limit: 10
  def write(keylists) do
    ## Write here your flushing function
  end
end

## Usage
BufferKeyListLimit.add(:key1, "value1")
BufferKeyListLimit.add(:key1, "value2")
BufferKeyListLimit.add(:key2, "value3")

## The write function will receive this value
[{:key1, ["value1", "value2"]}, {:key2, ["value3"]}]

## API
BufferKeyListLimit.sync()
BufferKeyListLimit.sync(:key1)
```

### Write Buffer for Counters

```elixir
## Declaration of the buffer
defmodule BufferCount do
  use Buffer.Write.Count, interval: 1000
  def write(counters) do
    ## Write here your flushing function
  end
end

## Usage
BufferCount.incr(:key1)
BufferCount.incr(:key1)
BufferCount.incr(:key2, 10)
BufferCount.incr(:key2, 15)

## The write function will receive this value
[{:key1, 2}, {:key2, 25}]

## API
BufferCount.sync()
```

### Read Buffer

```elixir
## Declaration of the buffer
defmodule BufferRead do
  use Buffer.Read, interval: 1000
  def read() do
    ## Write here your reading function
    [{:key1, "value1"}, {:key2, "value2"}]
  end
end

## Usage
"value" = BufferRead.read(:key1)

## API
BufferRead.sync()

```
