<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]



<!-- PROJECT TITLE -->
# json-explorer

Utilities to help explore complex json structures.



<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary><h2 style="display: inline-block">Table of Contents</h2></summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#prerequisites">Prerequisites</a></li>
    <li><a href="#installation">Installation</a></li>
    <li><a href="#usage">Usage</a></li>
    <ol>
      <li><a href="#the-json_explorer-function">The json_explorer function</a></li>
      <li><a href="#the-json_info-function">The json_info function</a></li>
    </ol>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

There are two main functions in here.
1.  The `json_explorer` function allows selection of paths of a json structure along with preview information paths.
    Selected paths are then retrieved and printed via stdout.

    ![json_explorer selection screenshot](/images/json-explorer-entry-selection.png?raw=true)

    ![json_explorer output screenshot](/images/json-explorer-output.png?raw=true)

    The preview functionality relies on the `json_info` function.
1.  The `json_info` function provides information about various paths in a json structure.

    ![json_info output screenshot](/images/json-info-output.png?raw=true)



<!-- PREREQUISITES -->
## Prerequisites
You must have the following utilities available:
1.  [jq](https://github.com/stedolan/jq) - jq is a lightweight and flexible command-line JSON processor.
1.  [fzf](https://github.com/junegunn/fzf) - fzf is a general-purpose command-line fuzzy finder.

See each project for installation instructions.



<!-- GETTING STARTED -->
## Installation

1.  Clone the repo
    ```sh
    git clone https://github.com/SpicyLemon/json-explorer.git
    ```
1.  Source the installer file.
    From the root of the repo:
    ```sh
    source je-install.sh
    ```
1.  Optional: Make `json_info` and `json_explorer` available in new terminals.
    There are a couple options for doing this.
    * Add the source command to your shell initialization script e.g. `.bash_profile` or `.zshrc`
        * Assuming you have navigated to the root of the repo.
        * Assuming your shell initialization script is `.bash_profile`.
        ```sh
        printf 'source "%s/je-install.sh"\n' "$( pwd )" >> ~/.bash_profile
        ```
    * Copy the `json_info.sh` and `json_explorer.sh` files into your own location and source them individually in your shell initialization script e.g. ` .bash_profile` or `.zshrc`.
        ```sh
        cp json_info.sh ~
        cp json_explorer.sh ~
        printf 'source "$HOME/json_info.sh"\n' >> ~/.bash_profile
        printf 'source "$HOME/json_explorer.sh"\n' >> ~/.bash_profile
        ```
    * Copy the `json_info.sh` and `json_explorer.sh` into a directory in your execution path variable e.g. `PATH` or `path`.
        ```sh
        cp json_info.sh /usr/local/bin/json_info
        cp json_explorer.sh /usr/local/bin/json_explorer
        ```



<!-- USAGE EXAMPLES -->
## Usage

These examples all assume you are in the root of this repository.

The `json_explorer` function is defined in the file `json_explorer.sh`, and the `json_info` function is defined in the file `json_info.sh`. These examples assume that you have sourced the files (or `je-install.sh`) to add the functions to your environment. The files can instead be executed directly if desired. To execute the file directly, replace "`json_explorer`" with "`./json_explorer.sh`" or replace "`json_info`" with "`./json_info.sh`" in these examples.

### The `json_explorer` function

This function uses `jq` to get a list of all possible json paths in a json file. It then uses `fzf` to let you preview and select desired paths. Selected entries are then combined into an output json array of objects. Each object has the keys `"path"` and `"value"`. The `"path"` is a path that was selected. The `"value"` is the value at the given path in the original json file.

#### Usage
```sh
> json_explorer --help
```
```
json_explorer - Select paths and output json with the selected entries.

Usage: json_explorer <filename>

    <filename> is the name of the json file to explore.
```

#### Example
Invoke json_explorer on the `tests/object-complex-1.json` file.
```sh
> json_explorer tests/object-complex-1.json
```

This will open fzf with the following options available for selection:
```
.
.a
.b
.c
.d
.e
.f
.f[0]
.f[1]
.f[2]
.g
.g[0]
.g[1]
.g[2]
.g[3]
.g[3].h
```

Using the up and down arrows, you can highlight different entries. The preview pane on the right will contain extra information about the highlighted entry. It will contain the highlighted path followed by information about it objected through the `json_info` command.

For example, if you highlight the `.g` line, the preview will show this:
```
.g
array: 4 entries: string number object
[
  "four",
  5,
  6,
  {
    "h": 7
  }
]
```

If you highlight the `.f[2]` line, you will see this:
```
.f[2]
string: "three"
```

And if you highlight the `.` line, you see this:
```
.
object: 7 keys: ["a","b","c","d","e","f","g"]
{
  "a": null,
  "b": true,
  "c": 8,
  "d": "thing",
  "e": "\"complex thing\"",
  "f": [
    "one",
    "two",
    "three"
  ],
  "g": [
    "four",
    5,
    6,
    {
      "h": 7
    }
  ]
}
```

Larger arrays and objects might not fully fit in the preview window, but hopefully there's enough info to start you on your way to finding what you're looking for.

You can filter the displayed list by typing part of the path you're looking for. For example, to view only the `.g` entries, just type a `g`. If you only wanted paths containing an 'h' in them somewhere, just type an `h`. If you wanted to find all paths with "url" in the name, type `url`.

Once you find an entry that you want to save for later, highlight it and press the `<tab>` button. A right-caret (aka "greater-than sign") will appear next to the line to indicate that you've selected it. You can select multiple paths this way. Pressing `<tab>` on a selected line will deselect it.

After you've selected your desired lines, press `enter` (or `return`). If no lines are selected, and you press the `enter` (or `return`) key, the highlighted line is selected and submitted. If one or more lines are selected when pressing `enter` (or `return`), only the selected lines are submitted; the highlighted line isn't automatically also selected. Lines that are selected, but no longer visible are still submitted. Pressing the `esc` key will exit out as if no lines are selected.

For each line selected, a json object will be created containing the keys `"path"` and `"value"`. The `"path"` key will contain the path (that was selected). The `"value"` will contain the value at that path in the originally supplied json file.

For example:
Initiate the explorer:
```sh
> json_explorer tests/object-complex-1.json
```
Select the `.g` and `.g[3].h` paths, press `enter`, and you will get this output:
```json
[
  {
    "path": ".g",
    "value": [
      "four",
      5,
      6,
      {
        "h": 7
      }
    ]
  },
  {
    "path": ".g[3].h",
    "value": 7
  }
]
```

### The `json_info` function

This function uses `jq` to provide information about different paths in a json structure.

#### Usage
```sh
> json_info --help
```
```
json_info - Outputs information about a json structure.

Usage: json_info [-p <path>] [-r] [-d] [--show-path|--hide-path|--just-paths] [--max-string <num>] {-f <filename>|-|-- <json>}

    -p <path> is the optional path to get information about.
        If provided multiple times, the information for each path provided will be used.
        If not provided, "." is used.

    -r is an optional flag indicating that the paths provided are starting points,
        and that all paths beyond that point should also be used.
        Supplying this once will apply it to all provided paths.
        Supplying this more than once has no affect.
        If no paths are provided, all paths in the json are used.

    -d is an optional flag indicating that for objects and arrays, the pretty json should be in the output.

    --show-path is an optional flag that causes the path to be part of the output.
        This is the default when there are more than one paths.
    --hide-path is an optional flag that causes the path to NOT be part of the output.
        This is the default when there is only one path.
    --just-paths is an optional flag that causes only the paths to be output (without the extra information).

    If multiple arguments are --show-path, --hide-path, or --just-paths, only the last one will be used.

    --max-string <num> is the optional maximum width for strings to trigger truncation.
        If set to 0, no truncation will happen.
        If not provided, and tput is available, then the default is to use tput to get the width of the window.
        If not provided, and tput is not available, the default is to not truncate strings.
        If the path is being shown, the length of the path is taken into consideration in order to try to
        truncate the string and keep it on a single line.

    Exactly one of the following must be provided to define the input json.
        -f <filename> will load the json from the provided filename
        - indicates that the json should be collected from stdin.
        -- <json> allows the json to be provided as part of the command.
            Everything after -- is treated as part of the json.
```

#### Getting superficial information
Get superficial information about a json file.
```sh
> json_info -f tests/object-complex-1.json
```
```
object: 7 keys: ["a","b","c","d","e","f","g"]
```

Get superficial information about a specific value.
```sh
> json_info -p '.f' -f tests/object-complex-1.json
```
```
array: 3 entries: string
```

#### Demonstrating the `-r` flag.
Get information about all paths in a json file
```sh
> json_info -r -f tests/object-complex-1.json
```
```
. = object: 7 keys: ["a","b","c","d","e","f","g"]
.a = null
.b = boolean: true
.c = number: 8
.d = string: "thing"
.e = string: "\"complex thing\""
.f = array: 3 entries: string
.f[0] = string: "one"
.f[1] = string: "two"
.f[2] = string: "three"
.g = array: 4 entries: string number object
.g[0] = string: "four"
.g[1] = number: 5
.g[2] = number: 6
.g[3] = object: 1 key: ["h"]
.g[3].h = number: 7
```

#### Demonstrating the `-` json input method and `-r` combined with `-p`.
Get information about all paths starting with the `"g"` value in a piped in json structure.
```sh
> cat tests/object-complex-1.json | json_info -r -p '.g' -
```
```
.g = array: 4 entries: string number object
.g[0] = string: "four"
.g[1] = number: 5
.g[2] = number: 6
.g[3] = object: 1 key: ["h"]
.g[3].h = number: 7
```

#### Demonstrating multiple `-p` arguments.
Get information about just the `"a"`, `"d"`, and `"f"` values:
```sh
> json_info -p '.a' -p '.d' -p '.f' -f tests/object-complex-1.json
```
```
.a = null
.d = string: "thing"
.f = array: 3 entries: string
```

Get information about all paths starting with the `"a"` `"f"` and `"g"` values:
```sh
> json_info -r -p '.a' -p '.f' -p '.g' -f tests/object-complex-1.json
```
```
.a = null
.f = array: 3 entries: string
.f[0] = string: "one"
.f[1] = string: "two"
.f[2] = string: "three"
.g = array: 4 entries: string number object
.g[0] = string: "four"
.g[1] = number: 5
.g[2] = number: 6
.g[3] = object: 1 key: ["h"]
.g[3].h = number: 7
```

#### Demonstrating the `--show-path` flag.
Without:
```sh
> json_info -p '.g[3]' -f tests/object-complex-1.json
```
```
object: 1 key: ["h"]
```
With:
```sh
> json_info -p '.g[3]' -f tests/object-complex-1.json --show-path
```
```
.g[3] = object: 1 key: ["h"]
```

#### Demonstrating the `--hide-path` flag.
Without:
```sh
> json_info -p '.f' -p '.g[3]' -f tests/object-complex-1.json
```
```
.f = array: 3 entries: string
.g[3] = object: 1 key: ["h"]
```
With:
```sh
> json_info -p '.f' -p '.g[3]' -f tests/object-complex-1.json --hide-path
```
```
array: 3 entries: string
object: 1 key: ["h"]
```

#### Demonstrating the `--just-paths` option.
You will probably want to use the `-r` option with `--just-paths`.
```sh
> json_info --just-paths -r -f tests/object-complex-1.json
```
```
.
.a
.b
.c
.d
.e
.f
.f[0]
.f[1]
.f[2]
.g
.g[0]
.g[1]
.g[2]
.g[3]
.g[3].h
```

#### Demonstrating the `--max-string` option.
Long strings are truncated so that the output line contains the provided number of characters:
```sh
> json_info -p '.a' -f tests/object-string-long-1.json --max-string 50
```
```
string: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...
```
A little longer:
```sh
> json_info -p '.a' -f tests/object-string-long-1.json --max-string 75
```
```
string: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...
```

Short strings are left alone:
```sh
> json_info -p '.a' -f tests/object-string-short.json --max-string 50
```
```
string: "simple string"
```

Providing 0 disables truncation:
```sh
> json_info -p '.a' -f tests/object-string-long-1.json --max-string 0
```
```
string: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

Providing a value greater than zero, but less than the line header truncates the entire string. In this case, the resulting line might still be longer than the provided character count.
```sh
> json_info -p '.a' -f tests/object-string-short.json --max-string 5
```
```
string: ...
```

If the path is included on the line, those characters are accounted for too:
```sh
> json_info -p '.a' -f tests/object-string-long-1.json --max-string 50 --show-path
```
```
.a = string: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx...
```
Or too short:
```sh
> json_info -p '.a' -f tests/object-string-long-1.json --max-string 15 --show-path
```
```
.a = string: ...
```
Same length, no path:
```sh
> json_info -p '.a' -f tests/object-string-long-1.json --max-string 15
```
```
string: "xxx...
```
Only string vaues are affected by `--max-string`:
```sh
> json_info -r --max-string 15 -f tests/array-of-each.json
```
```
. = array: 6 entries: null boolean number string array object
.[0] = null
.[1] = boolean: true
.[2] = number: 42
.[3] = string: ...
.[4] = array: 0 entries:
.[5] = object: 0 keys: []
```

#### Demonstrating the `--` argument and json input method.
```sh
> json_info -r -- '[null,true,42,"thing",[],{}]'
```
```
. = array: 6 entries: null boolean number string array object
.[0] = null
.[1] = boolean: true
.[2] = number: 42
.[3] = string: "thing"
.[4] = array: 0 entries:
.[5] = object: 0 keys: []
```

#### Array types are listed in the order they're first seen:
```sh
> json_info -f tests/array-of-each.json
```
```
array: 6 entries: null boolean number string array object
```
vs
```sh
> json_info -f tests/array-of-each-reversed.json
```
```
array: 6 entries: object array string number boolean null
```


<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

There are several test json files available in the `/tests` folder.



<!-- LICENSE -->
## License

Distributed under the MIT License. See [LICENSE](/LICENSE) for more information.



<!-- CONTACT -->
## Contact

Daniel Wedul - [@dannywedul](https://twitter.com/dannywedul) - jsonexplorer@wedul.com

Project Link: [https://github.com/SpicyLemon/json-explorer](https://github.com/SpicyLemon/json-explorer)



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/SpicyLemon/json-explorer.svg?style=for-the-badge
[contributors-url]: https://github.com/SpicyLemon/json-explorer/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/SpicyLemon/json-explorer.svg?style=for-the-badge
[forks-url]: https://github.com/SpicyLemon/json-explorer/network/members
[stars-shield]: https://img.shields.io/github/stars/SpicyLemon/json-explorer.svg?style=for-the-badge
[stars-url]: https://github.com/SpicyLemon/json-explorer/stargazers
[issues-shield]: https://img.shields.io/github/issues/SpicyLemon/json-explorer.svg?style=for-the-badge
[issues-url]: https://github.com/SpicyLemon/json-explorer/issues
[license-shield]: https://img.shields.io/github/license/SpicyLemon/json-explorer.svg?style=for-the-badge
[license-url]: https://github.com/SpicyLemon/json-explorer/blob/master/LICENSE
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://www.linkedin.com/in/danny-wedul/
