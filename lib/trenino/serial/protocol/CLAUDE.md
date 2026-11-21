# Serial Protocol

- Keep protocol structs atom-based and convert to integers only on the wire. Each message module implements `encode` and `decode_body` with binary pattern matching; dispatch lives in `lib/trenino/serial/protocol/message.ex`.
