# SPDX-FileCopyrightText: © 2017 The Bazel Authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

"""Skylib module containing file path manipulation functions.

NOTE: The functions in this module currently only support paths with Unix-style
path separators (forward slash, "/"); they do not handle Windows-style paths
with backslash separators or drive letters.
"""



def _basename(p: str) -> str:
    """Returns the basename (i.e., the file portion) of a path.

    Note that if `p` ends with a slash, this function returns an empty string.
    This matches the behavior of Python's `os.path.basename`, but differs from
    the Unix `basename` command (which would return the path segment preceding
    the final slash).

    Args:
      p: The path whose basename should be returned.
    Returns:
      The basename of the path, which includes the extension.
    """
    return p.rpartition("/")[-1]

def _depth(p: str) -> int:
    """Returns the number of path components in a normalized path.

    Args:
      p: A path.
    Returns:
      The number of components.
    """
    p = _normalize(p)
    if p == ".":
        return 0
    return len(p.split("/"))

def _is_absolute(path: str) -> bool:
    """Returns `True` if `path` is an absolute path.

    Args:
      path: A path (which is a string).
    Returns:
      `True` if `path` is an absolute path.
    """
    return path.startswith("/")

def _join(path: str, *others) -> str:
    """Joins one or more path components intelligently.

    This function mimics the behavior of Python's `os.path.join` function on POSIX
    platform. It returns the concatenation of `path` and any members of `others`,
    inserting directory separators before each component except the first. The
    separator is not inserted if the path up until that point is either empty or
    already ends in a separator.

    If any component is an absolute path, all previous components are discarded.

    Args:
      path: A path segment.
      *others: Additional path segments.
    Returns:
      A string containing the joined paths.
    """
    result = path

    for p in others:
        if _is_absolute(p):
            result = p
        elif not result or result.endswith("/"):
            result += p
        else:
            result += "/" + p

    return _normalize(result)

def _normalize(path: str) -> str:
    """Normalizes a path, eliminating double slashes and other redundant segments.

    This function mimics the behavior of Python's `os.path.normpath` function on
    POSIX platforms; specifically:

    - If the entire path is empty, "." is returned.
    - All "." segments are removed, unless the path consists solely of a single
      "." segment.
    - Trailing slashes are removed, unless the path consists solely of slashes.
    - ".." segments are removed as long as there are corresponding segments
      earlier in the path to remove; otherwise, they are retained as leading ".."
      segments.
    - Single and double leading slashes are preserved, but three or more leading
      slashes are collapsed into a single leading slash.
    - Multiple adjacent internal slashes are collapsed into a single slash.

    Args:
      path: A path.
    Returns:
      The normalized path.
    """
    if not path:
        return "."

    if path.startswith("//") and not path.startswith("///"):
        initial_slashes = 2
    elif path.startswith("/"):
        initial_slashes = 1
    else:
        initial_slashes = 0
    is_relative = initial_slashes == 0

    components = path.split("/")
    new_components = []

    for component in components:
        if component in ("", "."):
            continue
        if component == "..":
            if new_components and new_components[-1] != "..":
                # only pop the last segment if it isn't another ".."
                new_components.pop()
            elif is_relative:
                # preserve leading ".." segments for relative paths
                new_components.append(component)
        else:
            new_components.append(component)

    path = "/".join(new_components)
    if not is_relative:
        path = ("/" * initial_slashes) + path

    return path or "."

path = struct(
    basename = _basename,
    depth = _depth,
    is_absolute = _is_absolute,
    join = _join,
    normalize = _normalize,
)
