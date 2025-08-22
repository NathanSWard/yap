from testing import *
from yap.token import *
import yap.token
from yap.combinator import *
from yap._test_utils import *

# --- tag ---


def test_empty_tag_parser():
    var parser = tag("")

    with Case("empty input"):
        var result = parser.parse("")
        var (output, remaining) = result.ok()

        assert_equal(output, "")
        assert_equal(remaining, "")

    with Case("non empty input"):
        var result = parser.parse("yap")
        var (output, remaining) = result.ok()

        assert_equal(output, "")
        assert_equal(remaining, "yap")


def test_non_empty_tag_parser_succeeds():
    var parser = tag("yap")

    with Case("entire input matches"):
        var result = parser.parse("yap")
        var (output, input) = result.ok()

        assert_equal(output, "yap")
        assert_equal(input, "")

    with Case("partial input matches"):
        var result = parser.parse("yap123")
        var (output, input) = result.ok()

        assert_equal(output, "yap")
        assert_equal(input, "123")


def test_non_empty_tag_parser_fails():
    var parser = tag("yap")

    with Case("empty input"):
        var result = parser.parse("")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "")

    with Case("non empty input"):
        var result = parser.parse("mojo")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "mojo")

    with Case("input contains partial tag"):
        var result = parser.parse("ya")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "ya")

    with Case("input contains tag with different case"):
        var result = parser.parse("YAP")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "YAP")


# --- tag_no_case ---


def test_empty_tag_no_case_parser():
    var parser = tag_no_case("")

    with Case("empty input"):
        var result = parser.parse("")
        var (output, remaining) = result.ok()

        assert_equal(output, "")
        assert_equal(remaining, "")

    with Case("non empty input"):
        var result = parser.parse("yap")
        var (output, remaining) = result.ok()

        assert_equal(output, "")
        assert_equal(remaining, "yap")


def test_non_empty_tag_no_case_parser_succeeds():
    var parser = tag_no_case("yap123")

    with Case("entire input matches"):
        var result = parser.parse("yap123")
        var (output, input) = result.ok()

        assert_equal(output, "yap123")
        assert_equal(input, "")

    with Case("partial input matches"):
        var result = parser.parse("yap123456")
        var (output, input) = result.ok()

        assert_equal(output, "yap123")
        assert_equal(input, "456")

    with Case("case insenstive all upper"):
        var result = parser.parse("YAP123")
        var (output, input) = result.ok()

        assert_equal(output, "YAP123")
        assert_equal(input, "")

    with Case("case insenstive mixed upper and lower"):
        var result = parser.parse("yaP123")
        var (output, input) = result.ok()

        assert_equal(output, "yaP123")
        assert_equal(input, "")


def test_non_empty_tag_no_case_parser_fails():
    var parser = tag_no_case("yap")

    with Case("empty input"):
        var result = parser.parse("")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "")

    with Case("non empty input"):
        var result = parser.parse("mojo")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "mojo")

    with Case("input contains partial tag"):
        var result = parser.parse("ya")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "ya")


# --- any ---


def test_any_parser_succeeds():
    alias parser = token.any

    with Case("single size input"):
        var result = parser.parse("a")
        var (output, input) = result.ok()

        assert_equal(output, "a")
        assert_equal(input, "")

    with Case("larger input"):
        var result = parser.parse("xyz123")
        var (output, input) = result.ok()

        assert_equal(output, "x")
        assert_equal(input, "yz123")


def test_any_parser_fails():
    alias parser = token.any

    with Case("empty input"):
        var result = parser.parse("")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "")


# --- rest ---


def test_rest_parser_succeeds():
    alias parser = rest

    with Case("empty input"):
        var result = parser.parse("")
        var (output, input) = result.ok()

        assert_equal(output, "")
        assert_equal(input, "")

    with Case("single value input"):
        var result = parser.parse("a")
        var (output, input) = result.ok()

        assert_equal(output, "a")
        assert_equal(input, "")

    with Case("non empty input"):
        var result = parser.parse("abc123")
        var (output, input) = result.ok()

        assert_equal(output, "abc123")
        assert_equal(input, "")


def test_rest_parser_fails():
    # the rest parser cannot fail
    pass


# --- take_n ---


def test_take_n_0_parser():
    alias parser = take_n(0)

    with Case("empty input"):
        var result = parser.parse("")
        var (output, input) = result.ok()

        assert_equal(output, "")
        assert_equal(input, "")

    with Case("non empty input"):
        var result = parser.parse("qwerty")
        var (output, input) = result.ok()

        assert_equal(output, "")
        assert_equal(input, "qwerty")


def test_take_n_parser_succeeds():
    alias parser = take_n(3)

    with Case("input same size as N"):
        var result = parser.parse("123")
        var (output, input) = result.ok()

        assert_equal(output, "123")
        assert_equal(input, "")

    with Case("input longer than N"):
        var result = parser.parse("123456")
        var (output, input) = result.ok()

        assert_equal(output, "123")
        assert_equal(input, "456")


def test_take_n_parser_fails():
    alias parser = take_n(5)

    with Case("empty input"):
        var result = parser.parse("")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "")

    with Case("input smaller than N"):
        var result = parser.parse("123")
        var err = result.err()

        assert_equal(err.kind, ErrKind.BACKTRACK)
        assert_equal(err.input, "123")


# --- take_while ---


# def test_take_while_0_None():
#     alias parser = take_while[min=0](
#         TokenSet(
#             TokenRange[start="a", end="z"],
#             Tokens["1", "3"],
#         ),
#     )

#     var result = parser.parse("1ab3cz2Aa")
#     var (output, input) = result.ok()

#     assert_equal(output, "1ab3cz")
#     assert_equal(input, "2Aa")


# --- take_till ---


# def test_take_till_0_None():
#     with Case("Tokens Success"):
#         alias parser = take_till[min=0](TokenSet(Tokens["1", "2", "3"]))

#         with Case("empty input"):
#             var result = parser.parse("")
#             var (output, input) = result.ok()

#             assert_equal(output, "")
#             assert_equal(input, "")

#         with Case("input with no preceeding data"):
#             var result = parser.parse("2")
#             var (output, input) = result.ok()

#             assert_equal(output, "")
#             assert_equal(input, "2")

#         with Case("input with preceeding data"):
#             var result = parser.parse("abc1xyz")
#             var (output, input) = result.ok()

#             assert_equal(output, "abc")
#             assert_equal(input, "1xyz")

#         with Case("input with no matching tokens"):
#             var result = parser.parse("abc")
#             var (output, input) = result.ok()

#             assert_equal(output, "abc")
#             assert_equal(input, "")

#     with Case("Literal Success"):
#         var parser = take_till[min=0](Literal("yap"))

#         with Case("empty input"):
#             var result = parser.parse("")
#             var (output, input) = result.ok()

#             assert_equal(output, "")
#             assert_equal(input, "")

#         with Case("input with no preceeding data"):
#             var result = parser.parse("yap")
#             var (output, input) = result.ok()

#             assert_equal(output, "")
#             assert_equal(input, "yap")

#         with Case("input with preceeding data"):
#             var result = parser.parse("123yap456")
#             var (output, input) = result.ok()

#             assert_equal(output, "123")
#             assert_equal(input, "yap456")

#         with Case("input with no matching literal"):
#             var result = parser.parse("abc")
#             var (output, input) = result.ok()

#             assert_equal(output, "abc")
#             assert_equal(input, "")

#         with Case("input with partial matching literal"):
#             var result = parser.parse("123ya")
#             var (output, input) = result.ok()

#             assert_equal(output, "123ya")
#             assert_equal(input, "")
