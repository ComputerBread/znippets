# README

state: proof of concept

Motivation: Zig is a great language with huge potential, however it is not
stable yet. Writing documentation, articles, or books about it, is doomed to
become out of date, keeping track of what needs to be updated can be challenging!

Introducing znippets, a collection of (hopefully useful) zig snippets that are
tested across multiple zig versions, so that anyone can quickly know if a snippet
works for a specific zig version.

goal:
- have a collection of useful code snippets
- each snippet is automatically tested for all versions of zig (starting at 0.13.0)
  including nightly (dev) builds
- identify breaking changes
- make it easy to see what needs to be upgraded between versions!
- have fun little making a lil zig project

⚠️ only the latest "master/nightly/dev" version is kept, results of previous
nightly versions are removed!

## Contribute

The best way to contribute is by adding useful snippets!
Open issue with the snippet you want me to add.
OR open a PR with the snippet ready.

### Snippet should:

- ⚠️ **WORK**!!!! for at least one version!
  unless it's to show a common mistake or whatever,
- ⚠️ **EXIT**!!!! (stops/terminates)
  No infinite loop please 🙏!
- be in a zig file inside the "snippets" directory
- inside a test
  (maybe this can be relaxed, need to think about it)
  (if not in a test, what happens? still compiles?)
- avoid side effects (like deleting the whole system 😭)

If you want to add an explanation or some extra data, just write a comment at
the top!!!


### snippets naming convention

**TODO: not clear, to figure out**
didn't even tested inside a subdirectory

- each snippet needs to be a zig file
- if std related: use the name of the thing: "std.ArrayList", "std.Io.Witer.Allocating"
- seperate words with `-` (std.ArrayList-Basic-usage.zig)
- if a new version of a snippet comes up, just put the zig version
  (std.ArrayList-Basic-usage--v0.15.2.zig)
  (TODO: then in the datafile, we put a "replacedBy <name_of_new_snippet>")




## requirements

(tested on linux only)

To works this project needs:

- [zigup](https://github.com/marler8997/zigup)

## how does it work?

### vocab

- "master"/"nightly"/"dev" version, refers to the latest zig version available,
corresponding the latest build!
- "we": me and my multiple personalities, w is really just a flipped m

### flow

1. Verify that zigup is installed
2. Create an ArrayList of versions
    1. if a file named VERSIONS exists, the `zig_versions` is filled with its content
    2. A request is made to fetch [the latest zig versions](https://ziglang.org/download/index.json)
       Result is stored in an ArrayList.
       Both arrays are stored from oldest version (first) to newest.
    3. The new versions are added to the `zig_versions` array
       (An index is used to identify the position of the first new version)
3. Get the list of snippets
    1. read the file named SNIPPETS, to get the list of previously tested snippets along with their results,
       the snippets found in this file have been tested with all the versions found in the VERSIONS file!
       These snippets are referred to as "OLD SNIPPETS"
    2. list all snippets inside the snippets/ directory
    3. both of these lists are sorted by ascii alpha
    4. The 2 lists are compared, the new snippets found locally are stored at the end.
       These new snippets will be tested against "all" versions,
       while old snippets will only be tested with the new versions (if there is any).
       (An index is used to identify the position of the first new snippets)
4. snippets are tested for all versions
    - `zigup <version>` is used to change zig version
    - a snippet is a zig file containing (or not?) a test
    - each snippet is tested in a new process with `zig test <snippet-name.zig>`
        - if exit code is 0: success, code compile and test is working
        - else: code doesn't compile OR test failed (let's ignore the reason for now!)
    - the result is stored in a `u64` (should be enough? right, clueless).
      1 bit for each version, least significant bit = oldest version.
      bit 0 = failure, 1 = success
        - pros: small, fast, easy
        - cons: need to tests for all versions, can't really "skip versions",
          unless maybe if we override a version.
          Imagine: version 0.16.0 came out, is tested, next day, bug fix 0.16.1, let's override 0.16.0?
          or maybe not, idk
5. snippets are sorted by alpha order (results are stored as a consequence)
6. snippets path and results are stored in SNIPPETS file!
7. HTML files are generated
    - one html file per snippet with the working and failing versions
    - one html file per version with the working and failing snippets
    - index.html with links to snippets and versions html files
8. TODO: minify generated files

### saving data for faster execution

Testing all snippets for all versions is gonna be slow.
So let's not avoid doing the work twice!

We need to differentiate between OLD and NEW snippets:

- OLD: snippets that have already been tested
- NEW: snippets that have never been tested

New snippets are going to be tested for several versions.
Old snippets are going to be tested for 0, 1 or more versions:

- 0 if we just added new snippets before the release of a new zig version
- 1 if we added a new zig version
- more if more new versions of zig came out since the last run
  => all old snippets should have the EXACT same number of zig versions to be
  tested against!


We have 2 files:

- **VERSIONS**:
    - The first file contains all the zig versions we have tested so far
    - all existing snippets have been tested for all of these versions
    - one version per line
      OLDEST first, NEWEST last (MASTER on last line!)
    - it is expected that the last line is the "MASTER version"
    - if empty, it will be filled with all the versions since `OLDEST_ZIG_VERSION_INCL`
      (0.13.0) (this could become an argument to pass when running...)
    - if only one line, it is assumed that this line correspond to a version
        - 🤔 I should probably delete this and panic instead
        - this version will searched in the complete list of zig versions (fetched remotely)
        - if found, this version and any newer version will be used to test the snippets
            - this is the only case that make sense
              would be a nice way to initialize it
        - if not found, assume that it's an old master (or some garbage) and will be discarded,
          newest master and newest "stable" release is added to avoid a never
          ending cycle of replacing masters!
        - ⚠️ this is mostly a weird edge case, avoid it!
          MAKE SURE THE SNIPPETS FILE IS EMPTY, cause you're going to get garbage
          (damn this is kinda annoying to make robust)
          (I just want to publish ts really quick)
        - ⚠️ just don't modify this file, and you should be good to go
    - if last line (master version) isn't the latest master, then last line is
      discarded, we'll use/append any new version (including latest master),
      since the previous stable release in this file (the second last line)
    - otherwise: no new version
- **SNIPPETS**:
    - this file should contains one line for each (OLD) snippet containing:
        - snippet's path
        - result number
        - (not implemented)(future) extra info (replaced, deprecated, or whatever)
    - separated by comas
    - sorted by ascii alpha
    - this file can be manually modified (or maybe I could make a small CLI to edit it)
        - to delete a snippet, delete the snippet and the line associated with it
        in this file
        - some problems can arise if we start to delete some snippets without care


### testing snippets (thought process)

The current way to test snippets is to run `zig test <snippet-name>.zig` in a
new process and check the exit code. If it compiles and the test is successful
then the process exits with code `0`, otherwise, if it does NOT compile or if
the test fails, exit code is NOT `0`.

The reason why I choose this, is because I wanted an easy and "sustainable" way
to test snippets without having to modify the program for each new version.

So making a custom test runner would probably require to make one for each zig
version.

Doing a global "zig test" and parsing the output was also considered, but the
output format could be version-dependent. So unless we feed the output to a LLM,
and ask it to "parse" it, I don't see an easy and durable solution ; and let's
keep these clankers out of my deterministic application!

## file generation

Several html files are generated:

- one html file per snippet with the list of working and failing versions
- one html file per version with the list of working and failing snippets
- index.html with links to snippets and versions html files

To make my life a bit easier, I created a few templates:

- index-template.html - template for index.html
- template.html - template for snippets
- version-template.html - template for versions

these simple templates contains `{{TEMPLATE_STRINGS}}` that are replaced by
whatever... This is really, really, really basic. But it's easier to deal with.
(no whitespace allowed, just `{{` a name and two `}}`).
A function reads the template file in the generated file `std.Io.Writer` and
returns the `TEMPLATE_STRING`, we do a simple `std.mem.eql` and put whatever we
want in the `Writer`

Syntax highlighting done by prism.js


