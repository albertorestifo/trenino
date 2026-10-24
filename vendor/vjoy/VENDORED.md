# Vendored vjoy crate

This is `vjoy` 0.7.1 from <https://github.com/ArrowMaxGithub/vjoy> at
commit `af2fe6665917e5b11fb453ee40bfe76510ef6baa` (crates.io archive SHA-256
`367A5962FCD9A9524709C185280D6736BFFEDCA679392787B6272F72C90F5724`). The
upstream manifest declares `MIT OR Apache-2.0`; the corresponding license texts
are retained in `LICENSE-MIT` and `LICENSE-APACHE`.

The local patch adds a no-acquire constructor and selected-device acquisition,
status/range/configuration APIs, avoids indexing a sparse one-device collection
as if it contained devices 1 through N, relinquishes quietly on drop, and
preserves the HID Slider/Dial report slots. The legacy constructor remains
available with its original all-free-devices behavior; the Trenino adapter uses
only the no-acquire constructor and acquires the explicit selected ID.
