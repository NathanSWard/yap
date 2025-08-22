from yap.error import ErrKind
from yap.combinator.multi import Range, Collectable
from yap.combinator.multi.separated import separated
from yap.token import tag, char
from yap._test_utils import *

from testing import *

alias AnyStr = StringSlice[ImmutableAnyOrigin]


struct StringCollecter(Copyable & Movable & Collectable):
    alias Element = AnyStr

    var list: List[String]

    fn __init__(out self):
        self.list = []

    fn __init__(out self, *, capacity: Int):
        self.list = List[String](capacity=capacity)

    fn append(mut self, item: Self.Element):
        self.list.append(String(item))


def test_separated_empty_input_with_min_0():
    @parameter
    def test[range: Range]():
        var parser = separated[range=range](tag("abc"), char[","])
        var result = parser.parse("")

        assert_true(result)
        var (output, input) = result.ok()
        assert_equal(output.list, [])
        assert_equal(input, "")

    with Case("min=0, max=None"):
        test[range = Range(min=0)]()

    with Case("min=0, max=5"):
        test[range = Range(min=0, max=5)]()


def test_separated_consumes_full_input():
    @parameter
    def test[range: Range]():
        var parser = separated[range, StringCollecter](tag("abc"), char[","])
        var result = parser.parse("abc,abc,abc")

        assert_true(result)
        var (output, input) = result.ok()
        assert_equal(output.list, ["abc", "abc", "abc"])
        assert_equal(input, "")

    with Case("min=0, max=None"):
        test[range = Range(min=0)]()

    with Case("min=1, max=None"):
        test[range = Range(min=1)]()

    with Case("min=3, max=None"):
        test[range = Range(min=3)]()

    with Case("min=3, max=3"):
        test[range = Range(exactly=3)]()

    with Case("min=2, max=5"):
        test[range = Range(min=2, max=5)]()


def test_separated_with_trailing_separator():
    @parameter
    def test[range: Range]():
        var parser = separated[range, StringCollecter](tag("abc"), char[","])
        var result = parser.parse("abc,abc,abc,")

        assert_true(result)
        var (output, input) = result.ok()
        assert_equal(output.list, ["abc", "abc", "abc"])
        assert_equal(input, ",")

    with Case("min=0, max=None"):
        test[range = Range(min=0)]()

    with Case("min=1, max=None"):
        test[range = Range(min=1)]()

    with Case("min=3, max=None"):
        test[range = Range(min=3)]()

    with Case("min=3, max=3"):
        test[range = Range(exactly=3)]()

    with Case("min=2, max=5"):
        test[range = Range(min=2, max=5)]()


def test_separated_errors_with_empty_input_if_min_is_greater_than_0():
    @parameter
    def test[range: Range]():
        var parser = separated[range=range](tag("abc"), char[","])
        var result = parser.parse("")

        assert_false(result)
        assert_true(result.err() is ErrKind.BACKTRACK)

    with Case("min=1, max=None"):
        test[range = Range(min=1)]()

    with Case("min=2, max=None"):
        test[range = Range(min=2)]()

    with Case("min=3, max=3"):
        test[range = Range(exactly=3)]()

    with Case("min=2, max=5"):
        test[range = Range(min=2, max=5)]()


def test_separated_errors_if_minimum_is_not_met():
    @parameter
    def test[range: Range]():
        var parser = separated[range](tag("abc"), char[","])
        var result = parser.parse("abc,abc")

        assert_false(result)
        assert_true(result.err() is ErrKind.BACKTRACK)

    with Case("min=3, max=None"):
        test[range = Range(min=3)]()

    with Case("min=3, max=3"):
        test[range = Range(exactly=3)]()

    with Case("min=3, max=5"):
        test[range = Range(min=3, max=5)]()


def test_separated_stops_at_max():
    @parameter
    def test[range: Range]():
        var parser = separated[range, StringCollecter](tag("abc"), char[","])
        var result = parser.parse("abc,abc,abc")

        assert_true(result)
        var (output, input) = result.ok()
        assert_equal(output.list, ["abc", "abc"])
        assert_equal(input, ",abc")

    with Case("min=0, max=2"):
        test[range = Range(min=0, max=2)]()

    with Case("min=2, max=2"):
        test[range = Range(exactly=2)]()

    with Case("min=1, max=2"):
        test[range = Range(min=1, max=2)]()
