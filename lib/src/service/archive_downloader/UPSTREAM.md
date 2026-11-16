Embedded from https://github.com/jiangtian616/JDownloader at
`8ac5fba3ba7caa71cd60e3ffc24c9755c31e76dd` (Apache-2.0; see LICENSE).

This is application source, maintained in this repository, not a pub package.
Local changes fix HTTP byte ranges, add single-connection restart fallback,
validate partial responses, and fix worker cleanup. The existing `.jdtemp`
metadata remains readable; new metadata also records whether ranges work.
